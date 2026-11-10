import Foundation
import ZelotesKit

/// Developer tool: runs one experiment against the mouse and prints every packet in both directions.
@main
@MainActor
struct Probe {
    enum Experiment: String, CaseIterable {
        /// Reads the mouse's status report twice. Sends no command.
        case status
        /// Makes the profile the active one without changing what it holds.
        case select
        /// Writes again the button table the app last wrote to the profile.
        case table
        /// Writes the factory DPI settings to the profile. The same table carries the lighting,
        /// so this also sends that profile's factory lighting.
        case dpi
        /// Prints how often the mouse reports and how far it moves in each stroke, until Ctrl-C. Sends no command.
        case measure
    }

    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let experiment = arguments.first.flatMap(Experiment.init(rawValue:)) else {
            let names = Experiment.allCases.map(\.rawValue).joined(separator: "|")
            print("usage: ZelotesProbe <\(names)> [profile 1|2]")
            exit(2)
        }
        let profile = arguments.dropFirst().first.flatMap(UInt8.init).flatMap(MouseProfile.init(rawValue:)) ?? .first

        do {
            let connection = MouseConnection()
            try connection.start()
            let trace = TracingChannel(try await channel(of: connection))
            try await run(experiment, on: profile, trace)
            try await Task.sleep(for: lingerForLateReplies)
        } catch {
            print("failed: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static let lingerForLateReplies = Duration.milliseconds(500)

    private static func run(_ experiment: Experiment, on profile: MouseProfile, _ trace: TracingChannel) async throws {
        trace.readStatus()
        let writer = ProfileWriter(transport: trace)
        switch experiment {
        case .status:
            try await Task.sleep(for: .milliseconds(100))
            trace.readStatus()
        case .select:
            try await writer.select(profile)
        case .table:
            let library = MappingStore(fileURL: MappingStore.standardFileURL).load()
            guard let written = library?.written(to: profile) else {
                print("The app has not written to profile \(profile.rawValue) yet; move a preset into it from the app first.")
                return
            }
            try await writer.write(ProfileUpdate(buttons: written.table), to: profile)
        case .dpi:
            try await writer.write(ProfileUpdate(dpi: .factoryDefault), to: profile)
        case .measure:
            try await MovementMeter().run()
        }
    }

    private static func channel(of connection: MouseConnection) async throws -> ConfigurationChannel {
        for _ in 0..<40 {
            if let channel = connection.configurationChannel {
                return channel
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw MouseAccessError.notConnected
    }
}

@MainActor
private final class TracingChannel: ReportTransport {
    private let channel: ConfigurationChannel
    private let start = ContinuousClock.now

    init(_ channel: ConfigurationChannel) {
        self.channel = channel
        channel.onInputReport = { [weak self] bytes in
            self?.log("<- input  ", bytes)
        }
    }

    func sendFeatureReport(_ bytes: [UInt8]) throws {
        log("-> feature", bytes)
        try channel.sendFeatureReport(bytes)
    }

    func sendOutputReport(_ bytes: [UInt8]) throws {
        log("-> output ", bytes)
        try channel.sendOutputReport(bytes)
    }

    func readFeatureReport() throws -> [UInt8] {
        let report = try channel.readFeatureReport()
        log("== status ", report)
        return report
    }

    func readStatus() {
        do {
            _ = try readFeatureReport()
        } catch {
            print("== status read failed: \(error.localizedDescription)")
        }
    }

    private func log(_ label: String, _ bytes: [UInt8]) {
        let elapsed = start.duration(to: .now).components
        let milliseconds = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
        let hex = bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        print(String(format: "%8.1f ms  %@  %@", milliseconds, label, hex))
    }
}
