import Testing
@testable import ClayFeature

@Test @MainActor func contentSpriteFramesResolve() {
    let engine = GameEngine(seed: 0, shouldStartTimers: false, loadPersistence: false)
    let catalog = PixelAssetCatalog.shared
    var failures: [String] = []

    for person in engine.content.pack.people {
        let spriteId = person.spriteId
        let frames = catalog.frames(for: spriteId, idle: false)
        if frames.isEmpty {
            failures.append("Person \(person.id) -> \(spriteId)")
        }
    }

    for metahuman in engine.content.pack.metahumans {
        let spriteId = engine.metahumanSpriteId(metahuman)
        let frames = catalog.frames(for: spriteId, idle: false)
        if frames.isEmpty {
            failures.append("Metahuman \(metahuman.id) -> \(spriteId)")
        }
    }

    if !failures.isEmpty {
        print("Missing sprite frames:\n" + failures.joined(separator: "\n"))
    }
    #expect(failures.isEmpty)
}
