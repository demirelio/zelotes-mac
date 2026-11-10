import Foundation
import IOKit.hid

/// What the Mac should do with the mouse's pointer.
public struct PointerTarget: Equatable, Sendable {
    public var settings: PointerSettings
    /// The DPI the mouse is set to, which turns its counts into hand speed.
    public var dpi: Int

    public init(settings: PointerSettings, dpi: Int) {
        self.settings = settings
        self.dpi = dpi
    }
}

public enum PointerTuningError: Error, Equatable, LocalizedError {
    case unavailable
    case refused(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable: "This version of macOS does not let the app set pointer acceleration."
        case .refused(let key): "macOS did not accept the pointer settings (\(key))."
        }
    }
}

/// Sets how macOS accelerates the mouse's pointer, on the HID event system's pointer filter. The filter keeps the
/// settings until the mouse is unplugged.
@MainActor
public final class PointerTuner {
    public enum Outcome: Equatable {
        case applied
        case mouseNotFound
    }

    /// Property names from IOKit's `hid/IOHIDEventServiceKeys.h` and `hidsystem/IOHIDParameter.h`.
    private enum Key {
        static let accelerationType = "HIDPointerAccelerationType"
        static let mouseAcceleration = "HIDMouseAcceleration"
        static let pointerAcceleration = "HIDPointerAcceleration"
        static let table = "HIDPointerAccelerationTable"
        static let algorithm = "HIDPointerAccelerationAlgorithm"
        static let reportRate = "HIDPointerReportRate"
        static let resolution = "HIDPointerResolution"
    }

    /// `IOHIDAccelerationAlgorithmType`.
    private enum Algorithm {
        static let table = 0
        static let standard = 2
    }

    /// The counts per inch the filter assumes when a service does not say.
    private static let defaultResolution = 400.0

    private var client: IOHIDEventSystemClient?
    private lazy var systemTable = PointerAccelerationTable.systemDefault()

    public init() {
        client = Self.makePassiveClient()
    }

    public func apply(_ target: PointerTarget) throws -> Outcome {
        do {
            return try apply(target, with: client)
        } catch PointerTuningError.refused {
            // Once the mouse has been unplugged and plugged in again, macOS refuses the table from a client made
            // before that, but takes it from a new one.
            client = Self.makePassiveClient()
            return try apply(target, with: client)
        }
    }

    private func apply(_ target: PointerTarget, with client: IOHIDEventSystemClient?) throws -> Outcome {
        guard let client else {
            // Without a client the app never changed the pointer, so macOS still has its own settings.
            if target.settings.curve == nil { return .applied }
            throw PointerTuningError.unavailable
        }
        let services = pointerServices(of: client)
        guard !services.isEmpty else { return .mouseNotFound }
        for service in services {
            if let curve = target.settings.curve {
                try install(curve, speed: target.settings.speed, dpi: target.dpi, on: service)
            } else {
                try restore(service)
            }
        }
        return .applied
    }

    private func install(_ curve: AccelerationCurve, speed: Double, dpi: Int, on service: IOHIDServiceClient) throws {
        let resolution = (property(Key.resolution, of: service) as? Int).map { Double($0) / 65536 }
        let table = PointerAccelerationTable.data(
            for: curve,
            speed: speed,
            dpi: dpi,
            resolution: resolution ?? Self.defaultResolution
        )
        // The filter reads the table when it rebuilds its accelerator, which each of the later properties makes it do.
        try set(table, Key.table, on: service)
        try set(PointerAccelerationTable.reportRate, Key.reportRate, on: service)
        try set(Algorithm.table, Key.algorithm, on: service)
        // With Pointer Acceleration off in System Settings the filter scales movement linearly and ignores any
        // table, but only when the acceleration type is the mouse one. The general one is never negative, so it
        // keeps acceleration on.
        try set(Key.pointerAcceleration, Key.accelerationType, on: service)
    }

    /// Hands the pointer back to macOS. A service this app has not changed keeps everything it has.
    private func restore(_ service: IOHIDServiceClient) throws {
        guard property(Key.accelerationType, of: service) as? String == Key.pointerAcceleration else { return }
        if let systemTable {
            try set(systemTable, Key.table, on: service)
        }
        try set(0, Key.reportRate, on: service)
        try set(Algorithm.standard, Key.algorithm, on: service)
        try set(Key.mouseAcceleration, Key.accelerationType, on: service)
    }

    private func pointerServices(of client: IOHIDEventSystemClient) -> [IOHIDServiceClient] {
        let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] ?? []
        return services.filter { service in
            property(kIOHIDVendorIDKey, of: service) as? Int == DeviceIdentity.vendorID
                && property(kIOHIDProductIDKey, of: service) as? Int == DeviceIdentity.productID
                && IOHIDServiceClientConformsTo(service, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Mouse)) != 0
        }
    }

    private func property(_ key: String, of service: IOHIDServiceClient) -> Any? {
        IOHIDServiceClientCopyProperty(service, key as CFString)
    }

    private func set(_ value: Any, _ key: String, on service: IOHIDServiceClient) throws {
        guard IOHIDServiceClientSetProperty(service, key as CFString, value as CFTypeRef) else {
            throw PointerTuningError.refused(key)
        }
    }

    /// The public simple client may not set an acceleration table. A passive client may, without an entitlement
    /// (`HIDEventSystemClient.h` in Apple's IOHIDFamily), but IOKit exports its constructor without declaring it.
    private static func makePassiveClient() -> IOHIDEventSystemClient? {
        typealias CreateWithType = @convention(c) (CFAllocator?, Int32, CFDictionary?) -> Unmanaged<IOHIDEventSystemClient>?
        let passiveType: Int32 = 2
        guard let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
              let symbol = dlsym(iokit, "IOHIDEventSystemClientCreateWithType") else { return nil }
        let create = unsafeBitCast(symbol, to: CreateWithType.self)
        return create(kCFAllocatorDefault, passiveType, nil)?.takeRetainedValue()
    }
}
