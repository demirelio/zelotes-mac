import Foundation
import IOKit.hid

public enum DeviceIdentity {
    public static let vendorID = 0x12C9
    public static let productID = 0x2003
    /// Usage page of the mouse's third HID interface, which takes the configuration commands.
    public static let configurationUsagePage = 0xFF00
}

public enum MouseAccessError: Error, Equatable, LocalizedError {
    case notConnected
    case accessRefused(IOReturn)
    case reportRejected(IOReturn)
    case writeNotConfirmed(status: [UInt8])

    public var errorDescription: String? {
        switch self {
        case .writeNotConfirmed(let status):
            "The mouse did not confirm the write (status \(Self.hex(status))). "
                + "If the pointer is frozen, unplug the mouse and plug it back in."
        case .notConnected:
            "The mouse is not connected."
        case .accessRefused(let status):
            "macOS refused access to the mouse (\(Self.hex(status)))."
        case .reportRejected(let status):
            "The mouse did not accept the data (\(Self.hex(status)))."
        }
    }

    private static func hex(_ status: IOReturn) -> String {
        "0x" + String(UInt32(bitPattern: status), radix: 16)
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}

/// Tracks whether the mouse is plugged in and hands out its configuration channel.
@MainActor
public final class MouseConnection {
    public private(set) var configurationChannel: ConfigurationChannel?
    public var onChange: (@MainActor () -> Void)?

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    public init() {}

    public func start() throws {
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: DeviceIdentity.vendorID,
            kIOHIDProductIDKey: DeviceIdentity.productID,
            kIOHIDPrimaryUsagePageKey: DeviceIdentity.configurationUsagePage,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, mouseAttached, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, mouseDetached, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            throw MouseAccessError.accessRefused(status)
        }
    }

    fileprivate func attach(_ device: IOHIDDevice) {
        configurationChannel?.close()
        configurationChannel = ConfigurationChannel(device: device)
        onChange?()
    }

    fileprivate func detach() {
        configurationChannel?.close()
        configurationChannel = nil
        onChange?()
    }
}

@MainActor
public final class ConfigurationChannel: ReportTransport {
    private static let unnumberedReportID: CFIndex = 0
    private static let featureReportLength = 8
    private static let inputReportLength = 64

    /// Called with each input report the mouse sends on this configuration interface.
    public var onInputReport: (@MainActor ([UInt8]) -> Void)?

    private let device: IOHIDDevice
    private let inputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: inputReportLength)

    fileprivate init(device: IOHIDDevice) {
        self.device = device
        IOHIDDeviceRegisterInputReportCallback(
            device,
            inputBuffer,
            Self.inputReportLength,
            inputReportArrived,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    fileprivate func close() {
        IOHIDDeviceRegisterInputReportCallback(device, inputBuffer, Self.inputReportLength, nil, nil)
        inputBuffer.deallocate()
    }

    public func sendFeatureReport(_ bytes: [UInt8]) throws {
        try send(bytes, as: kIOHIDReportTypeFeature)
    }

    public func sendOutputReport(_ bytes: [UInt8]) throws {
        try send(bytes, as: kIOHIDReportTypeOutput)
    }

    public func readFeatureReport() throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Self.featureReportLength)
        var length = bytes.count
        let status = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, Self.unnumberedReportID, &bytes, &length)
        guard status == kIOReturnSuccess else {
            throw MouseAccessError.reportRejected(status)
        }
        return Array(bytes.prefix(length))
    }

    private func send(_ bytes: [UInt8], as type: IOHIDReportType) throws {
        let status = IOHIDDeviceSetReport(device, type, Self.unnumberedReportID, bytes, bytes.count)
        guard status == kIOReturnSuccess else {
            throw MouseAccessError.reportRejected(status)
        }
    }
}

private func inputReportArrived(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    length: CFIndex
) {
    guard let context else { return }
    let bytes = Array(UnsafeBufferPointer(start: report, count: length))
    let channel = Unmanaged<ConfigurationChannel>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { channel.onInputReport?(bytes) }
}

private func mouseAttached(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    nonisolated(unsafe) let device = device
    onMainRunLoop(context) { $0.attach(device) }
}

private func mouseDetached(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    onMainRunLoop(context) { $0.detach() }
}

// IOKit delivers these callbacks on the run loop the manager is scheduled on, which is the main one.
private func onMainRunLoop(_ context: UnsafeMutableRawPointer?, _ body: @MainActor (MouseConnection) -> Void) {
    guard let context else { return }
    let connection = Unmanaged<MouseConnection>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { body(connection) }
}
