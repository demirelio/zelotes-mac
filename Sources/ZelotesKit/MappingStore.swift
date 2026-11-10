import Foundation

public struct MappingStore: Sendable {
    public static var standardFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "ZelotesMac/mappings.json")
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Returns `nil` when nothing has been saved yet, and also when the saved file cannot be used,
    /// such as one written by a later version.
    public func load() -> PresetLibrary? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PresetLibrary.self, from: data)
    }

    /// Copies the saved file next to itself, under a name no earlier copy has, and returns where.
    /// For a file `load()` could not use: the next save would replace it. Returns `nil` when there is no file.
    @discardableResult
    public func keepCopyOfSavedFile() throws -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let copyURL = unusedCopyURL()
        try FileManager.default.copyItem(at: fileURL, to: copyURL)
        return copyURL
    }

    private func unusedCopyURL() -> URL {
        let folder = fileURL.deletingLastPathComponent()
        let name = fileURL.deletingPathExtension().lastPathComponent
        var copyURL = folder.appending(path: "\(name).unreadable.json")
        var number = 2
        while FileManager.default.fileExists(atPath: copyURL.path) {
            copyURL = folder.appending(path: "\(name).unreadable-\(number).json")
            number += 1
        }
        return copyURL
    }

    public func save(_ library: PresetLibrary) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(library).write(to: fileURL, options: .atomic)
    }
}
