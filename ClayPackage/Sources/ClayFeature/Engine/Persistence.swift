import Foundation

public enum Persistence {
    private static let fileName = "save.json"
    private static let backupCount = 3

    private static let queueKey = DispatchSpecificKey<UInt8>()
    private static let ioQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.clay.game.persistence", qos: .utility)
        queue.setSpecific(key: queueKey, value: 1)
        return queue
    }()
    
    public static func saveURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Clay", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }
    
    public static func backupURLs() -> [URL] {
        backupURLs(for: saveURL())
    }

    public static func save(state: GameState, rotateBackups: Bool = true) {
        enqueueSave(state: state, rotateBackups: rotateBackups, synchronous: false)
    }

    public static func saveSync(state: GameState, rotateBackups: Bool = true) {
        enqueueSave(state: state, rotateBackups: rotateBackups, synchronous: true)
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

    private static func enqueueSave(state: GameState, rotateBackups: Bool, synchronous: Bool) {
        let snapshot = state
        let work = {
            let url = saveURL()
            if rotateBackups {
                rotateBackupFiles(mainURL: url)
            }
            do {
                let data = try PerfSignposts.saveEncode {
                    try encode(state: snapshot)
                }
                try PerfSignposts.saveWrite {
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                print("Failed to save game state: \(error)")
            }
        }
        if synchronous {
            if DispatchQueue.getSpecific(key: queueKey) != nil {
                work()
            } else {
                ioQueue.sync(execute: work)
            }
        } else {
            ioQueue.async(execute: work)
        }
    }

    private static func encode(state: GameState) throws -> Data {
        let encoder = JSONEncoder()
#if DEBUG
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
#else
        encoder.outputFormatting = []
#endif
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(state)
    }

    private static func backupURLs(for mainURL: URL) -> [URL] {
        let base = mainURL.deletingLastPathComponent()
        return (1...backupCount).map { base.appendingPathComponent("save-\($0).json") }
    }

    private static func rotateBackupFiles(mainURL url: URL) {
        let backups = backupURLs(for: url)
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
