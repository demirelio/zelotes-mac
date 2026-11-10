import Foundation
import OSLog
import XPC
import ZelotesKit

// launchd starts this when the mouse is plugged in and at login (`Support/local.zelotes-mac.pointer.plist`).
// It gives macOS the pointer settings of the profile in use, then quits.

let log = Logger(subsystem: "local.zelotes-mac", category: "pointer-agent")
/// Long enough for launchd to hand over the plug-in event; an event left untaken makes launchd start the agent again.
let shortestRun = Duration.seconds(1)

xpc_set_event_stream_handler("com.apple.iokit.matching", DispatchQueue.main) { _ in }

Task { @MainActor in
    let started = ContinuousClock.now
    let library = MappingStore(fileURL: MappingStore.standardFileURL).load() ?? PresetLibrary()
    let tuner = PointerTuner()
    // The pointer joins the HID event system a little after the mouse connects.
    for delay in [0, 250, 500, 1000, 2000, 4000] {
        try? await Task.sleep(for: .milliseconds(delay))
        do {
            if try tuner.apply(library.pointerTarget) == .applied {
                log.info("Pointer set")
                break
            }
        } catch {
            log.error("Pointer: \(error.localizedDescription, privacy: .public)")
            break
        }
    }
    try? await Task.sleep(until: started + shortestRun)
    exit(0)
}

dispatchMain()
