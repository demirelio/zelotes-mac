import Foundation
import Security
import ServiceManagement

/// The launch agent that sets the pointer each time the mouse is plugged in and then quits, so the app does not
/// have to keep running. Its launchd job is `Support/local.zelotes-mac.pointer.plist`.
enum PointerAgent {
    enum State: Equatable {
        /// Not registered, because no profile has pointer settings of its own.
        case off
        case on
        /// Turned off in System Settings › General › Login Items; only the user can turn it back on.
        case turnedOffByUser
        /// The job is not in the app bundle, as when the app runs outside `build/ZelotesMac.app`.
        case missing

        /// Pointer settings that macOS would drop at the next unplugging are not offered at all.
        var allowsPointerSettings: Bool {
            switch self {
            case .off, .on: true
            case .turnedOffByUser, .missing: false
            }
        }
    }

    private static var service: SMAppService {
        .agent(plistName: "local.zelotes-mac.pointer.plist")
    }

    /// launchd keeps the agent's code signature from when it was registered and will not start other code, so
    /// a new build of the agent has to be registered again.
    private static let registeredCodeKey = "pointerAgentRegisteredCode"

    /// Keeps the agent registered exactly while `isNeeded`. A user's choice in Login Items stays as it is.
    static func update(isNeeded: Bool) async throws -> State {
        switch (isNeeded, service.status) {
        case (true, .enabled):
            if let code = agentCode, code != UserDefaults.standard.string(forKey: registeredCodeKey) {
                // Registering again before the old item is gone revives it with the old code requirement.
                try await service.unregister()
                try register()
            }
            return state
        case (true, .requiresApproval):
            return state
        case (true, _):
            try register()
            return state
        case (false, .enabled), (false, .requiresApproval):
            try await service.unregister()
            UserDefaults.standard.removeObject(forKey: registeredCodeKey)
            return .off
        case (false, _):
            return .off
        }
    }

    static var state: State {
        switch service.status {
        case .enabled: .on
        case .requiresApproval: .turnedOffByUser
        case .notFound: .missing
        default: .off
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func register() throws {
        try service.register()
        UserDefaults.standard.set(agentCode, forKey: registeredCodeKey)
    }

    /// The code directory hash of the agent in this app bundle, which changes with every build.
    private static var agentCode: String? {
        guard let url = Bundle.main.url(forAuxiliaryExecutable: "ZelotesPointerAgent") else { return nil }
        var code: SecStaticCode?
        var information: CFDictionary?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, [], &information) == errSecSuccess,
              let hash = (information as? [String: Any])?[kSecCodeInfoUnique as String] as? Data else { return nil }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
