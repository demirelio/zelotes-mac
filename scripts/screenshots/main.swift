import AppKit
import ImageIO
import SwiftUI
import ZelotesKit

// Draws the app window off-screen with demo presets and saves one PNG per page. Run through
// scripts/make-screenshots.sh. Arguments: output directory, scratch store path, "dark" or "light".

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
let storeURL = URL(fileURLWithPath: CommandLine.arguments[2])
let appearanceName: NSAppearance.Name = CommandLine.arguments[3] == "light" ? .aqua : .darkAqua

func demoLibrary() -> PresetLibrary {
    var library = PresetLibrary()
    let everyday = library.presets[0].id
    library.updatePreset(everyday) { preset in
        preset.name = "Everyday"
        preset.symbol = "keyboard.fill"
        preset.table[.joystickUp] = .windowNavigation(WindowNavigation(system: .macOS, command: .allWindows))
        preset.table[.joystickDown] = .windowNavigation(WindowNavigation(system: .macOS, command: .showDesktop))
        preset.table[.joystickLeft] = .windowNavigation(WindowNavigation(system: .macOS, command: .previousDesktop))
        preset.table[.joystickRight] = .windowNavigation(WindowNavigation(system: .macOS, command: .nextDesktop))
        preset.table[.joystickPress] = .media(.playPause)
        preset.table[.dpiButton] = .dpi(.cycle)
        preset.dpi.activeStage = 2
        preset.stageNames[1] = "Precise"
        preset.stageNames[2] = "Everyday"
        preset.stageNames[3] = "Quick"
        preset.lighting = Lighting(effect: .steady, color: .cyan, brightness: .high, speed: .medium)
        preset.pointer.acceleration = .windows
    }
    let games = library.addPreset()
    library.updatePreset(games) { preset in
        preset.name = "Games"
        preset.symbol = "gamecontroller.fill"
        preset.table[.joystickUp] = .key(KeyStroke(key: .w))
        preset.table[.joystickLeft] = .key(KeyStroke(key: .a))
        preset.table[.joystickDown] = .key(KeyStroke(key: .s))
        preset.table[.joystickRight] = .key(KeyStroke(key: .d))
        preset.table[.joystickPress] = .key(KeyStroke(key: .space))
        preset.dpi.pollingRate = .hz1000
        preset.lighting = Lighting(effect: .wave, color: .red, brightness: .high, speed: .fast)
        preset.pointer.acceleration = .none
    }
    let design = library.addPreset()
    library.updatePreset(design) { preset in
        preset.name = "Design"
        preset.symbol = "paintpalette.fill"
    }
    library.recordWrite(of: library.preset(everyday)!, to: .first)
    library.recordWrite(of: library.preset(games)!, to: .second)
    library.recordActivation(of: .first)
    return library
}

try? FileManager.default.removeItem(at: storeURL)
let store = MappingStore(fileURL: storeURL)
try store.save(demoLibrary())

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: appearanceName)

let model = MainActor.assumeIsolated { MappingModel(store: store, isPreview: true) }
let size = NSSize(width: 1105, height: 726)
let window = NSWindow(
    contentRect: NSRect(origin: NSPoint(x: -6000, y: -6000), size: size),
    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
window.contentViewController = NSHostingController(rootView: ContentView(model: model))
window.setContentSize(size)
window.setFrameOrigin(NSPoint(x: -6000, y: -6000))
window.orderFrontRegardless()

// A process may capture its own windows without Screen Recording permission. The SDK hides this function.
typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
let createImage = unsafeBitCast(dlsym(dlopen(nil, RTLD_NOW), "CGWindowListCreateImage"), to: CreateImage.self)
let includingWindow: UInt32 = 1 << 3
let bestResolution: UInt32 = 1 << 3

/// A capture carries the display's colour profile, which names the display model. Redrawn in sRGB and written
/// without metadata, the PNG says nothing about the machine.
func writeWithoutMetadata(_ image: CGImage, to url: URL) {
    let context = CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

for (page, name) in [(PresetPage.buttons, "buttons"), (.dpi, "dpi"), (.lighting, "lighting"), (.pointer, "pointer")] {
    MainActor.assumeIsolated { model.presetPage = page }
    RunLoop.main.run(until: Date().addingTimeInterval(1.5))
    let image = createImage(.null, includingWindow, UInt32(window.windowNumber), bestResolution)!.takeRetainedValue()
    let url = outputDirectory.appendingPathComponent("\(name).png")
    writeWithoutMetadata(image, to: url)
    print("Wrote \(url.path)")
}
