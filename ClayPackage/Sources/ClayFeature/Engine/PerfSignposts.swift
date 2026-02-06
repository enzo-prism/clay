import Foundation

#if DEBUG
import os.signpost

enum PerfSignposts {
    // Keep this stable so Instruments can group signposts across runs.
    private static let log = OSLog(subsystem: "com.clay.game", category: "PointsOfInterest")

    static func tick<T>(_ body: () throws -> T) rethrows -> T {
        try interval("Tick", body)
    }

    static func advance<T>(_ body: () throws -> T) rethrows -> T {
        try interval("Advance", body)
    }

    static func sceneUpdate<T>(_ body: () throws -> T) rethrows -> T {
        try interval("SceneUpdate", body)
    }

    static func sceneStep<T>(_ body: () throws -> T) rethrows -> T {
        try interval("SceneStep", body)
    }

    static func saveEncode<T>(_ body: () throws -> T) rethrows -> T {
        try interval("SaveEncode", body)
    }

    static func saveWrite<T>(_ body: () throws -> T) rethrows -> T {
        try interval("SaveWrite", body)
    }

    private static func interval<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        defer { os_signpost(.end, log: log, name: name, signpostID: id) }
        return try body()
    }
}

#else

// Release build: keep the API but compile to no-ops.
enum PerfSignposts {
    static func tick<T>(_ body: () throws -> T) rethrows -> T { try body() }
    static func advance<T>(_ body: () throws -> T) rethrows -> T { try body() }
    static func sceneUpdate<T>(_ body: () throws -> T) rethrows -> T { try body() }
    static func sceneStep<T>(_ body: () throws -> T) rethrows -> T { try body() }
    static func saveEncode<T>(_ body: () throws -> T) rethrows -> T { try body() }
    static func saveWrite<T>(_ body: () throws -> T) rethrows -> T { try body() }
}

#endif

