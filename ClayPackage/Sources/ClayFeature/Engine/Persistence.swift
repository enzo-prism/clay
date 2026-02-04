import Foundation

public enum Persistence {
    private static let fileName = "save.json"
    private static let backupCount = 3
    
    public static func saveURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Clay", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }
    
    public static func backupURLs() -> [URL] {
        let base = saveURL().deletingLastPathComponent()
        return (1...backupCount).map { base.appendingPathComponent("save-\($0).json") }
    }
    
    public static func save(state: GameState) {
        let url = saveURL()
        rotateBackups()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save game state: \(error)")
        }
    }
    
    public static func load() -> GameState? {
        let url = saveURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(GameState.self, from: data)
        } catch {
            print("Failed to load game state: \(error)")
            return nil
        }
    }
    
    private static func rotateBackups() {
        let url = saveURL()
        let backups = backupURLs()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        for index in stride(from: backups.count - 1, through: 0, by: -1) {
            let target = backups[index]
            let source: URL = (index == 0) ? url : backups[index - 1]
            if FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.removeItem(at: target)
                try? FileManager.default.copyItem(at: source, to: target)
            }
        }
    }
}
