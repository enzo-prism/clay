import SwiftUI
import SceneKit
import AppKit

struct BaseSceneView: NSViewRepresentable {
    @EnvironmentObject private var engine: GameEngine
    @EnvironmentObject private var toastCenter: ToastCenter
    @Binding var selectedBuildId: String?
    @Binding var selectedBuilding: BuildingInstance?
    @Binding var overlayMode: BaseOverlayMode
    @Binding var centerTrigger: Int
    
    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine, toastCenter: toastCenter, selectedBuildId: $selectedBuildId, selectedBuilding: $selectedBuilding, overlayMode: overlayMode, centerTrigger: centerTrigger)
    }
    
    func makeNSView(context: Context) -> SCNView {
        let view = BaseSceneSCNView()
        context.coordinator.attach(view: view)
        view.scene = context.coordinator.scene
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.rendersContinuously = false
        
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        view.addGestureRecognizer(click)
        let pan = NSPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.buttonMask = 1
        view.addGestureRecognizer(pan)
        let magnify = NSMagnificationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMagnify(_:)))
        view.addGestureRecognizer(magnify)
        
        view.onScrollEvent = { event in
            context.coordinator.handleScroll(event: event)
        }
        view.onMouseMove = { point, bounds in
            context.coordinator.updateEdgePan(point: point, bounds: bounds)
        }
        view.onMouseExit = {
            context.coordinator.updateEdgePan(point: nil, bounds: .zero)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        if nsView.scene !== context.coordinator.scene {
            nsView.scene = context.coordinator.scene
        }
        context.coordinator.update(engine: engine, selectedBuildId: selectedBuildId, selectedBuilding: selectedBuilding, overlayMode: overlayMode, centerTrigger: centerTrigger)
    }
    
    @MainActor
    final class Coordinator: NSObject {
        private(set) var scene: SCNScene = SCNScene()
        private let cameraRig = SCNNode()
        private let cameraNode = SCNNode()
        private let terrainNode = SCNNode()
        private let selectionNode = SCNNode()
        private var ambientLightNode = SCNNode()
        private var directionalLightNode = SCNNode()
        private var buildingNodes: [UUID: SCNNode] = [:]
        private var overlayNodes: [UUID: SCNNode] = [:]
        private var activityNodes: [UUID: SCNNode] = [:]
        private var ambientNodes: [String: [SCNNode]] = [:]
        private var ambientActors: [UUID: AmbientActor] = [:]
        private var focusActors: [AmbientActor] = []
        private var buildingActors: [UUID: [AmbientActor]] = [:]
        private var tileAtlas: PixelTileAtlas?
        private var terrainPalette: PixelTerrainPalette?
        private var terrainImageCache: NSImage?
        private var terrainImageSize: Int = 0
        private var gridSize: Int = 0
        private var panStart: CGPoint = .zero
        private var overlayMode: BaseOverlayMode = .none
        private var lastCenterTrigger: Int = 0
        private var lastBuildingSignature: Int = Int.min
        private var lastBuildingActorSignature: Int = Int.min
        private var lastOverlaySignature: Int = Int.min
        private var lastActivitySignature: Int = Int.min
        private var lastAmbientSignature: Int = Int.min
        private var lastAmbientActorSignature: Int = Int.min
        private let backend: RenderBackend = SceneKitBackend()
        private weak var view: SCNView?
        private var targetPosition: SCNVector3 = SCNVector3(0, 0, 0)
        private var targetLookPoint: SCNVector3 = SCNVector3(0, 0, 0)
        private var targetScale: Double = 10
        private var lastFocusedBuildingId: UUID?
        private var cameraLookOffset: SCNVector3 = SCNVector3(0, 0, 0)
        private var edgePanVelocity: CGVector = .zero
        private var panVelocity: CGVector = .zero
        private var edgePanTimer: Timer?
        private var lastEdgeTick: TimeInterval = CACurrentMediaTime()
        private var lastPanTick: TimeInterval = CACurrentMediaTime()
        private var lastInputAt: TimeInterval = CACurrentMediaTime()
        private let panDecay: Double = 0.92
        private var lastAmbientTick: TimeInterval = CACurrentMediaTime()
        private var defaultScale: Double = 10
        
        private var engine: GameEngine
        private let toastCenter: ToastCenter
        private var selectedBuildId: Binding<String?>
        private var selectedBuilding: Binding<BuildingInstance?>
        
        init(engine: GameEngine, toastCenter: ToastCenter, selectedBuildId: Binding<String?>, selectedBuilding: Binding<BuildingInstance?>, overlayMode: BaseOverlayMode, centerTrigger: Int) {
            self.engine = engine
            self.toastCenter = toastCenter
            self.selectedBuildId = selectedBuildId
            self.selectedBuilding = selectedBuilding
            self.overlayMode = overlayMode
            self.lastCenterTrigger = centerTrigger
            super.init()
            configureScene()
        }

        func attach(view: SCNView) {
            self.view = view
            view.window?.acceptsMouseMovedEvents = true
            startEdgePanTimer()
            DispatchQueue.main.async { [weak self] in
                self?.updateLookOffset()
                self?.centerMap(animated: false)
            }
        }
        
        func update(engine: GameEngine, selectedBuildId: String?, selectedBuilding: BuildingInstance?, overlayMode: BaseOverlayMode, centerTrigger: Int) {
            self.engine = engine
            self.overlayMode = overlayMode
            if gridSize != engine.state.gridSize {
                configureScene()
            }
            let now = Date()
            let buildings = engine.state.buildings
            let activeBuildingIds = Set(engine.state.activeProjects.compactMap { $0.associatedBuildingId })
            var buildingHasher = Hasher()
            var buildingActorHasher = Hasher()
            var buildingById: [UUID: BuildingInstance] = [:]
            buildingById.reserveCapacity(buildings.count)
            var buildingCounts: [String: Int] = [:]
            var constructingBuildingIds: Set<UUID> = []
            constructingBuildingIds.reserveCapacity(buildings.count)
            for building in buildings {
                buildingHasher.combine(building.id)
                buildingHasher.combine(building.buildingId)
                buildingHasher.combine(building.level)
                buildingHasher.combine(building.x)
                buildingHasher.combine(building.y)
                buildingById[building.id] = building
                buildingCounts[building.buildingId, default: 0] += 1
                let isConstructing = (building.disabledUntil ?? .distantPast) > now
                if isConstructing {
                    constructingBuildingIds.insert(building.id)
                }
                let desiredActors = (isConstructing || activeBuildingIds.contains(building.id)) ? 2 : 1
                buildingActorHasher.combine(building.id)
                buildingActorHasher.combine(desiredActors)
            }
            let buildingSignature = buildingHasher.finalize()
            if buildingSignature != lastBuildingSignature {
                syncBuildings(buildings)
                lastBuildingSignature = buildingSignature
            }
            let buildingActorSignature = buildingActorHasher.finalize()
            if buildingActorSignature != lastBuildingActorSignature {
                syncBuildingActors(buildings: buildings, activeBuildingIds: activeBuildingIds, constructingBuildingIds: constructingBuildingIds)
                lastBuildingActorSignature = buildingActorSignature
            }
            updateSelection()
            let overlaySignature = overlaySignature(buildingSignature: buildingSignature, overlayMode: overlayMode)
            if overlaySignature != lastOverlaySignature {
                syncOverlays(buildings: buildings)
                lastOverlaySignature = overlaySignature
            }
            let activitySignature = activitySignature(active: activeBuildingIds, constructing: constructingBuildingIds)
            if activitySignature != lastActivitySignature {
                syncActivityNodes(activeBuildingIds: activeBuildingIds, constructingBuildingIds: constructingBuildingIds, buildingsById: buildingById)
                lastActivitySignature = activitySignature
            }
            let ambientCounts = desiredAmbientCounts(buildingCounts: buildingCounts)
            let ambientSignature = ambientSignature(desiredCounts: ambientCounts)
            if ambientSignature != lastAmbientSignature {
                syncAmbientEntities(desiredCounts: ambientCounts)
                lastAmbientSignature = ambientSignature
            }
            let desiredAmbientActors = desiredAmbientActorCount(buildingCount: buildings.count, peopleCount: engine.state.people.recruitedIds.count)
            if desiredAmbientActors != lastAmbientActorSignature {
                syncAmbientActors(desiredCount: desiredAmbientActors)
                lastAmbientActorSignature = desiredAmbientActors
            }
            if centerTrigger != lastCenterTrigger {
                lastCenterTrigger = centerTrigger
                centerMap(animated: true)
            }
            if let selected = selectedBuilding {
                if selected.id != lastFocusedBuildingId {
                    lastFocusedBuildingId = selected.id
                    focus(on: selected)
                }
            } else {
                if lastFocusedBuildingId != nil {
                    lastFocusedBuildingId = nil
                    resetFocus(animated: true)
                }
            }
        }
        
        private func configureScene() {
            scene = SCNScene()
            buildingNodes = [:]
            overlayNodes = [:]
            activityNodes = [:]
            ambientNodes = [:]
            ambientActors = [:]
            focusActors = []
            buildingActors = [:]
            tileAtlas = nil
            terrainPalette = nil
            terrainImageCache = nil
            terrainImageSize = 0
            gridSize = engine.state.gridSize
            lastBuildingSignature = Int.min
            lastBuildingActorSignature = Int.min
            lastOverlaySignature = Int.min
            lastActivitySignature = Int.min
            lastAmbientSignature = Int.min
            lastAmbientActorSignature = Int.min
            setupCamera()
            setupTerrain()
            setupLights()
            setupSelection()
            centerMap(animated: false)
        }
        
        private func setupCamera() {
            let camera = SCNCamera()
            camera.usesOrthographicProjection = true
            let initialScale = Double(max(6, gridSize)) * 0.85
            camera.orthographicScale = initialScale
            defaultScale = initialScale
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, Float(gridSize) * 1.2, 0)
            cameraNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            
            cameraRig.position = SCNVector3(Float(gridSize) / 2, 0, Float(gridSize) / 2)
            cameraRig.addChildNode(cameraNode)
            scene.rootNode.addChildNode(cameraRig)
            targetPosition = cameraRig.position
            targetScale = initialScale
            updateLookOffset()
            targetLookPoint = SCNVector3(Float(gridSize) / 2, 0, Float(gridSize) / 2)
        }
        
        private func setupTerrain() {
            let plane = SCNPlane(width: CGFloat(gridSize), height: CGFloat(gridSize))
            let material = SCNMaterial()
            material.diffuse.contents = terrainImage()
            material.isDoubleSided = true
            material.diffuse.magnificationFilter = .nearest
            material.diffuse.minificationFilter = .nearest
            material.lightingModel = .constant
            plane.materials = [material]
            terrainNode.geometry = plane
            terrainNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            terrainNode.position = SCNVector3(Float(gridSize) / 2, 0, Float(gridSize) / 2)
            terrainNode.categoryBitMask = 1
            scene.rootNode.addChildNode(terrainNode)
        }
        
        private func setupLights() {
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 600
            ambientLightNode = SCNNode()
            ambientLightNode.light = ambient
            scene.rootNode.addChildNode(ambientLightNode)
            
            let directional = SCNLight()
            directional.type = .directional
            directional.intensity = 1200
            directionalLightNode = SCNNode()
            directionalLightNode.light = directional
            directionalLightNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
            scene.rootNode.addChildNode(directionalLightNode)
        }
        
        private func setupSelection() {
            let ring = SCNPlane(width: 0.9, height: 0.9)
            let material = SCNMaterial()
            material.diffuse.contents = NSColor(calibratedRed: 0.2, green: 0.7, blue: 1.0, alpha: 0.35)
            material.isDoubleSided = true
            ring.materials = [material]
            selectionNode.geometry = ring
            selectionNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            selectionNode.position = SCNVector3(0, 0.02, 0)
            selectionNode.isHidden = true
            scene.rootNode.addChildNode(selectionNode)
        }
        
        private func syncBuildings(_ buildings: [BuildingInstance]) {
            let existingIds = Set(buildingNodes.keys)
            let currentIds = Set(buildings.map { $0.id })
            for removedId in existingIds.subtracting(currentIds) {
                buildingNodes[removedId]?.removeFromParentNode()
                buildingNodes.removeValue(forKey: removedId)
            }
            for building in buildings {
                if buildingNodes[building.id] == nil {
                    if let node = buildNode(for: building) {
                        scene.rootNode.addChildNode(node)
                        buildingNodes[building.id] = node
                    }
                }
            }
        }

        private func syncBuildingActors(buildings: [BuildingInstance], activeBuildingIds: Set<UUID>, constructingBuildingIds: Set<UUID>) {
            let currentIds = Set(buildings.map { $0.id })
            for (id, actors) in buildingActors where !currentIds.contains(id) {
                actors.forEach { $0.node.removeFromParentNode() }
                buildingActors.removeValue(forKey: id)
            }
            for building in buildings {
                let desired = desiredBuildingActorCount(for: building, activeBuildingIds: activeBuildingIds, constructingBuildingIds: constructingBuildingIds)
                var actors = buildingActors[building.id] ?? []
                if actors.count > desired {
                    let removeCount = actors.count - desired
                    for _ in 0..<removeCount {
                        if let actor = actors.popLast() {
                            actor.node.removeFromParentNode()
                        }
                    }
                } else if actors.count < desired {
                    let addCount = desired - actors.count
                    for _ in 0..<addCount {
                        if let actor = buildAmbientActor(at: buildingActorSpawn(for: building), speedRange: 0.35...0.7) {
                            actors.append(actor)
                            scene.rootNode.addChildNode(actor.node)
                            scheduleBuildingLoop(for: actor, building: building)
                        }
                    }
                } else {
                    for actor in actors where actor.node.action(forKey: "work") == nil {
                        scheduleBuildingLoop(for: actor, building: building)
                    }
                }
                buildingActors[building.id] = actors
            }
        }

        private func desiredBuildingActorCount(for building: BuildingInstance, activeBuildingIds: Set<UUID>, constructingBuildingIds: Set<UUID>) -> Int {
            if constructingBuildingIds.contains(building.id) || activeBuildingIds.contains(building.id) {
                return 2
            }
            return 1
        }

        private func overlaySignature(buildingSignature: Int, overlayMode: BaseOverlayMode) -> Int {
            var hasher = Hasher()
            hasher.combine(buildingSignature)
            hasher.combine(overlayMode.rawValue)
            switch overlayMode {
            case .logistics:
                hasher.combine(engine.state.logistics.logisticsFactor)
            case .risk:
                hasher.combine(engine.state.risk.raidChancePerHour)
            case .district, .none:
                break
            }
            return hasher.finalize()
        }

        private func activitySignature(active: Set<UUID>, constructing: Set<UUID>) -> Int {
            var hasher = Hasher()
            hasher.combine(active.count)
            for id in active.sorted(by: { $0.uuidString < $1.uuidString }) {
                hasher.combine(id)
            }
            hasher.combine(constructing.count)
            for id in constructing.sorted(by: { $0.uuidString < $1.uuidString }) {
                hasher.combine(id)
            }
            return hasher.finalize()
        }

        private func desiredAmbientCounts(buildingCounts: [String: Int]) -> [String: Int] {
            guard !engine.content.pack.ambientEntities.isEmpty else { return [:] }
            var counts: [String: Int] = [:]
            counts.reserveCapacity(engine.content.pack.ambientEntities.count)
            for entity in engine.content.pack.ambientEntities {
                counts[entity.id] = desiredAmbientCount(for: entity, buildingCounts: buildingCounts)
            }
            return counts
        }

        private func ambientSignature(desiredCounts: [String: Int]) -> Int {
            var hasher = Hasher()
            hasher.combine(engine.state.eraId)
            for entity in engine.content.pack.ambientEntities {
                hasher.combine(entity.id)
                hasher.combine(desiredCounts[entity.id, default: 0])
            }
            return hasher.finalize()
        }

        private func buildingActorSpawn(for building: BuildingInstance) -> SCNVector3 {
            let positions = buildingActorPositions(for: building, spread: 0.6)
            return positions.randomElement() ?? SCNVector3(Float(building.x) + 0.5, 0.06, Float(building.y) + 0.5)
        }

        private func buildingActorPositions(for building: BuildingInstance, spread: Float) -> [SCNVector3] {
            let centerX = Float(building.x) + 0.5
            let centerZ = Float(building.y) + 0.5
            let offsets: [(Float, Float)] = [
                (spread, 0), (-spread, 0), (0, spread), (0, -spread),
                (spread * 0.6, spread * 0.6), (-spread * 0.6, spread * 0.6)
            ]
            let maxCoord = Float(max(1, gridSize)) - 0.5
            return offsets.map { dx, dz in
                let x = min(max(0.5, centerX + dx), maxCoord)
                let z = min(max(0.5, centerZ + dz), maxCoord)
                return SCNVector3(x, 0.06, z)
            }
        }

        private func scheduleBuildingLoop(for actor: AmbientActor, building: BuildingInstance) {
            actor.node.removeAction(forKey: "walk")
            actor.node.removeAction(forKey: "work")
            let center = SCNVector3(Float(building.x) + 0.5, 0.06, Float(building.y) + 0.5)
            var points = buildingActorPositions(for: building, spread: 0.6).shuffled()
            points.append(center)
            let moves = points.map { point -> SCNAction in
                let current = actor.node.presentation.position
                let dx = point.x - current.x
                let dz = point.z - current.z
                let distance = sqrt(dx * dx + dz * dz)
                let duration = max(0.4, Double(distance) / actor.speed)
                let move = SCNAction.move(to: point, duration: duration)
                move.timingMode = .easeInEaseOut
                return move
            }
            let waits = points.map { _ in SCNAction.wait(duration: Double.random(in: 0.3...0.8)) }
            let sequence = SCNAction.sequence(zip(moves, waits).flatMap { [$0.0, $0.1] })
            let loop = SCNAction.repeatForever(sequence)
            actor.node.runAction(loop, forKey: "work")
        }

        private func syncOverlays(buildings: [BuildingInstance]) {
            guard overlayMode != .none else {
                for (_, node) in overlayNodes {
                    node.removeFromParentNode()
                }
                overlayNodes = [:]
                return
            }
            let existingIds = Set(overlayNodes.keys)
            let currentIds = Set(buildings.map { $0.id })
            for removedId in existingIds.subtracting(currentIds) {
                overlayNodes[removedId]?.removeFromParentNode()
                overlayNodes.removeValue(forKey: removedId)
            }
            for building in buildings {
                let color = overlayColor(for: building)
                let position = SCNVector3(Float(building.x) + 0.5, 0.03, Float(building.y) + 0.5)
                if let existing = overlayNodes[building.id] {
                    existing.geometry?.materials.first?.diffuse.contents = color
                    existing.position = position
                } else {
                    let node = backend.makeOverlayNode(size: 0.95, color: color, position: position)
                    scene.rootNode.addChildNode(node)
                    overlayNodes[building.id] = node
                }
            }
        }

        private func syncActivityNodes(activeBuildingIds: Set<UUID>, constructingBuildingIds: Set<UUID>, buildingsById: [UUID: BuildingInstance]) {
            let desired = activeBuildingIds.union(constructingBuildingIds)
            for removedId in activityNodes.keys.filter({ !desired.contains($0) }) {
                activityNodes[removedId]?.removeFromParentNode()
                activityNodes.removeValue(forKey: removedId)
            }
            for id in desired {
                if activityNodes[id] != nil { continue }
                guard let building = buildingsById[id] else { continue }
                let node = makeActivityNode(for: building)
                activityNodes[id] = node
                scene.rootNode.addChildNode(node)
            }
        }

        private func makeActivityNode(for building: BuildingInstance) -> SCNNode {
            let ring = SCNPlane(width: 0.85, height: 0.85)
            let material = SCNMaterial()
            material.diffuse.contents = NSColor(calibratedRed: 0.35, green: 0.75, blue: 1.0, alpha: 0.45)
            material.isDoubleSided = true
            ring.materials = [material]
            let node = SCNNode(geometry: ring)
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            node.position = SCNVector3(Float(building.x) + 0.5, 0.08, Float(building.y) + 0.5)
            let pulse = SCNAction.sequence([
                SCNAction.fadeOpacity(to: 0.2, duration: 0.7),
                SCNAction.fadeOpacity(to: 0.65, duration: 0.7)
            ])
            node.runAction(SCNAction.repeatForever(pulse))
            return node
        }

        private func overlayColor(for building: BuildingInstance) -> NSColor {
            switch overlayMode {
            case .logistics:
                let factor = engine.state.logistics.logisticsFactor
                return NSColor(calibratedRed: CGFloat(1.0 - factor), green: CGFloat(factor), blue: 0.2, alpha: 0.35)
            case .district:
                if let def = engine.content.buildingsById[building.buildingId],
                   let tag = def.districtTag {
                    switch tag {
                    case "economy": return NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.35)
                    case "energy": return NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.2, alpha: 0.35)
                    case "production": return NSColor(calibratedRed: 0.4, green: 0.9, blue: 0.6, alpha: 0.35)
                    case "infrastructure": return NSColor(calibratedRed: 0.6, green: 0.6, blue: 1.0, alpha: 0.35)
                    case "industrial": return NSColor(calibratedRed: 0.6, green: 0.8, blue: 0.9, alpha: 0.35)
                    default: return NSColor(calibratedWhite: 0.8, alpha: 0.35)
                    }
                }
                return NSColor(calibratedWhite: 0.6, alpha: 0.2)
            case .risk:
                let risk = engine.state.risk.raidChancePerHour
                let clamped = min(1.0, max(0.0, risk * 2))
                return NSColor(calibratedRed: CGFloat(clamped), green: CGFloat(1.0 - clamped), blue: 0.2, alpha: 0.35)
            case .none:
                return .clear
            }
        }

        private func syncAmbientEntities(desiredCounts: [String: Int]) {
            guard !engine.content.pack.ambientEntities.isEmpty else { return }
            for entity in engine.content.pack.ambientEntities {
                let desired = desiredCounts[entity.id, default: 0]
                var nodes = ambientNodes[entity.id] ?? []
                if nodes.count > desired {
                    let removeCount = nodes.count - desired
                    for _ in 0..<removeCount {
                        if let node = nodes.popLast() {
                            node.removeFromParentNode()
                        }
                    }
                } else if nodes.count < desired {
                    let addCount = desired - nodes.count
                    for _ in 0..<addCount {
                        if let node = buildAmbientNode(for: entity) {
                            nodes.append(node)
                            scene.rootNode.addChildNode(node)
                            applyAmbientMotion(node: node, profile: entity.movementProfile)
                        }
                    }
                }
                ambientNodes[entity.id] = nodes
            }
        }

        private func desiredAmbientCount(for entity: AmbientEntityDefinition, buildingCounts: [String: Int]) -> Int {
            if let minEraId = entity.spawnRules.minEraId,
               let requiredEra = engine.content.erasById[minEraId],
               let currentEra = engine.content.erasById[engine.state.eraId],
               currentEra.sortOrder < requiredEra.sortOrder {
                return 0
            }
            var count = entity.spawnRules.baseCount ?? 0
            if let perBuildingId = entity.spawnRules.perBuildingId {
                count += buildingCounts[perBuildingId, default: 0]
            }
            if let maxCount = entity.spawnRules.maxCount {
                count = min(count, maxCount)
            }
            return count
        }

        private func buildAmbientNode(for entity: AmbientEntityDefinition) -> SCNNode? {
            let asset = KenneyBuildingAsset(
                id: entity.id,
                model3d: entity.model3d,
                scale: Float(entity.scale),
                rotation: 0,
                yOffset: 0,
                cameraDistance: 6,
                tile2d: nil
            )
            let position = randomAmbientPosition()
            let node = backend.makeAmbientNode(asset: asset, id: entity.id, position: position)
            return node
        }

        private func randomAmbientPosition() -> SCNVector3 {
            let x = Float.random(in: 0.5...Float(max(1, gridSize - 1)))
            let z = Float.random(in: 0.5...Float(max(1, gridSize - 1)))
            return SCNVector3(x, 0.05, z)
        }

        private func applyAmbientMotion(node: SCNNode, profile: AmbientMovementProfileDefinition) {
            let radius = CGFloat(profile.radius)
            let duration = max(1.0, radius / CGFloat(profile.speed))
            let moveRight = SCNAction.moveBy(x: radius, y: 0, z: 0, duration: duration)
            let moveLeft = SCNAction.moveBy(x: -radius, y: 0, z: 0, duration: duration)
            let moveUp = SCNAction.moveBy(x: 0, y: 0, z: radius, duration: duration)
            let moveDown = SCNAction.moveBy(x: 0, y: 0, z: -radius, duration: duration)
            let pause = SCNAction.wait(duration: profile.pauseSeconds)
            let sequence = SCNAction.sequence([moveRight, pause, moveUp, pause, moveLeft, pause, moveDown, pause])
            node.runAction(SCNAction.repeatForever(sequence))
        }

        private func syncAmbientActors(desiredCount: Int) {
            let current = ambientActors.count
            if current > desiredCount {
                let removeCount = current - desiredCount
                for id in ambientActors.keys.prefix(removeCount) {
                    ambientActors[id]?.node.removeFromParentNode()
                    ambientActors.removeValue(forKey: id)
                }
            } else if current < desiredCount {
                let addCount = desiredCount - current
                for _ in 0..<addCount {
                    if let actor = buildAmbientActor() {
                        ambientActors[actor.id] = actor
                        scene.rootNode.addChildNode(actor.node)
                        scheduleNextWalk(for: actor)
                    }
                }
            }
        }

        private func desiredAmbientActorCount(buildingCount: Int, peopleCount: Int) -> Int {
            let base = 4
            let eraBoost = (engine.content.erasById[engine.state.eraId]?.sortOrder ?? 0)
            let fromBuildings = max(0, buildingCount / 3)
            let fromPeople = max(0, peopleCount / 2)
            return min(30, max(4, base + eraBoost + fromBuildings + fromPeople))
        }

        private func buildAmbientActor() -> AmbientActor? {
            return buildAmbientActor(at: randomActorPosition(), speedRange: 0.25...0.6)
        }

        private func buildAmbientActor(at position: SCNVector3, speedRange: ClosedRange<Double>) -> AmbientActor? {
            let spriteIds = engine.peopleSpritePool()
            let spriteId = spriteIds.randomElement() ?? "worker"
            guard let sprite = PixelAssetCatalog.shared.sprite(for: spriteId) else { return nil }
            let frames = spriteFrames(for: sprite)
            guard let firstFrame = frames.first else { return nil }
            let idleFrames = spriteFrames(for: sprite, idle: true)
            let idleFallback = idleFrames.isEmpty ? frames : idleFrames
            let scale = sprite.scale ?? 1.0
            let plane = SCNPlane(width: CGFloat(0.65 * scale), height: CGFloat(0.65 * scale))
            let material = SCNMaterial()
            material.diffuse.contents = firstFrame
            material.diffuse.magnificationFilter = .nearest
            material.diffuse.minificationFilter = .nearest
            material.isDoubleSided = true
            material.lightingModel = .constant
            plane.materials = [material]
            let spriteNode = SCNNode(geometry: plane)
            let node = SCNNode()
            node.position = position
            node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            node.categoryBitMask = 1
            node.addChildNode(spriteNode)
            let pulse = SCNAction.sequence([
                SCNAction.scale(to: 1.03, duration: 0.6),
                SCNAction.scale(to: 0.98, duration: 0.6)
            ])
            node.runAction(SCNAction.repeatForever(pulse))
            return AmbientActor(
                node: node,
                spriteNode: spriteNode,
                frames: frames,
                fps: sprite.fps,
                idleFrames: idleFallback,
                idleFps: max(1.0, sprite.fps * 0.6),
                speed: Double.random(in: speedRange)
            )
        }

        private func spriteFrames(for sprite: PixelSpriteDefinition, idle: Bool = false) -> [NSImage] {
            var frames: [NSImage] = []
            let sheet = idle ? sprite.idleSheet : sprite.sheet
            if let sheet {
                let count = PixelAssetCatalog.shared.frameCount(for: sheet)
                for index in 0..<count {
                    if let image = PixelAssetCatalog.shared.frameImage(from: sheet, frameIndex: index) {
                        frames.append(image)
                    }
                }
            } else {
                for path in sprite.frames {
                    if let image = PixelAssetCatalog.shared.image(for: path) {
                        frames.append(image)
                    }
                }
            }
            return frames
        }

        private func randomActorPosition() -> SCNVector3 {
            let margin: Float = 0.8
            let maxValue = Float(max(1, gridSize - 1))
            let x = Float.random(in: margin...maxValue)
            let z = Float.random(in: margin...maxValue)
            return SCNVector3(x, 0.06, z)
        }

        private func scheduleNextWalk(for actor: AmbientActor) {
            let destination = randomActorPosition()
            let current = actor.node.position
            let dx = destination.x - current.x
            let dz = destination.z - current.z
            let distance = sqrt(dx * dx + dz * dz)
            let duration = max(0.6, Double(distance) / actor.speed)
            let move = SCNAction.move(to: destination, duration: duration)
            move.timingMode = .easeInEaseOut
            let wait = SCNAction.wait(duration: Double.random(in: 0.4...1.2))
            let next = SCNAction.run { [weak self, weak actor] _ in
                guard let self, let actor else { return }
                self.scheduleNextWalk(for: actor)
            }
            actor.node.runAction(SCNAction.sequence([move, wait, next]), forKey: "walk")
        }
        
        private func updateSelection() {
            guard let selected = selectedBuilding.wrappedValue else {
                selectionNode.isHidden = true
                return
            }
            selectionNode.isHidden = false
            selectionNode.position = SCNVector3(Float(selected.x) + 0.5, 0.02, Float(selected.y) + 0.5)
        }
        
        private func buildNode(for building: BuildingInstance) -> SCNNode? {
            if let atlas = loadTileAtlas(),
               let palette = terrainPalette,
               !palette.structure.isEmpty,
               let tile = pixelBuildingTile(for: building.buildingId, palette: palette, atlas: atlas) {
                let plane = SCNPlane(width: 1.0, height: 1.0)
                let material = SCNMaterial()
                material.diffuse.contents = tile
                material.diffuse.magnificationFilter = .nearest
                material.diffuse.minificationFilter = .nearest
                material.isDoubleSided = true
                material.lightingModel = .constant
                plane.materials = [material]
                let node = SCNNode(geometry: plane)
                node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
                node.position = SCNVector3(Float(building.x) + 0.5, 0.02, Float(building.y) + 0.5)
                node.name = "building:\(building.id.uuidString)"
                node.categoryBitMask = 2
                return node
            }
            let asset = KenneyAssetCatalog.shared.buildingAsset(for: building.buildingId)
            guard let asset else { return nil }
            let position = SCNVector3(Float(building.x) + 0.5, asset.yOffset, Float(building.y) + 0.5)
            return backend.makeBuildingNode(asset: asset, id: building.id, position: position)
        }
        
        private func terrainImage() -> NSImage {
            if let cached = terrainImageCache, terrainImageSize == gridSize {
                return cached
            }
            guard let atlas = loadTileAtlas(),
                  let palette = terrainPalette else {
                let image = fallbackGridImage()
                terrainImageCache = image
                terrainImageSize = gridSize
                return image
            }
            let tileSize = atlas.tileSize
            let size = CGSize(width: gridSize * tileSize, height: gridSize * tileSize)
            let image = NSImage(size: size)
            image.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            for y in 0..<gridSize {
                for x in 0..<gridSize {
                    let index = terrainTileIndex(x: x, y: y, palette: palette)
                    if let tile = atlas.tileImage(index: index) {
                        let rect = CGRect(x: x * tileSize, y: (gridSize - 1 - y) * tileSize, width: tileSize, height: tileSize)
                        tile.draw(in: rect)
                    }
                }
            }
            image.unlockFocus()
            terrainImageCache = image
            terrainImageSize = gridSize
            return image
        }

        private func fallbackGridImage() -> NSImage {
            let size = CGSize(width: 256, height: 256)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor(calibratedWhite: 0.07, alpha: 1.0).setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            let gridPath = NSBezierPath()
            gridPath.lineWidth = 1
            let step: CGFloat = 32
            for x in stride(from: 0, through: size.width, by: step) {
                gridPath.move(to: CGPoint(x: x, y: 0))
                gridPath.line(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: step) {
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.line(to: CGPoint(x: size.width, y: y))
            }
            NSColor(calibratedWhite: 0.16, alpha: 1.0).setStroke()
            gridPath.stroke()
            image.unlockFocus()
            return image
        }

        private func pixelBuildingTile(for buildingId: String, palette: PixelTerrainPalette, atlas: PixelTileAtlas) -> NSImage? {
            let options = palette.structure
            guard !options.isEmpty else { return nil }
            let index = abs(buildingId.hashValue) % options.count
            return atlas.tileImage(index: options[index])
        }

        private func loadTileAtlas() -> PixelTileAtlas? {
            if let atlas = tileAtlas {
                return atlas
            }
            if let atlas = PixelTileAtlas(path: "Pixel/Generated/BaseMap/base_map_tileset_256.png", tileSize: 16) {
                tileAtlas = atlas
                terrainPalette = atlas.palette()
                return atlas
            }
            if let atlas = PixelTileAtlas(path: "Pixel/PunyWorld/punyworld-overworld-tileset.png", tileSize: 16) {
                tileAtlas = atlas
                terrainPalette = atlas.palette()
                return atlas
            }
            if let atlas = PixelTileAtlas(path: "Pixel/Winter-Pixel-Pack/World/Winter-Tileset.png", tileSize: 16) {
                tileAtlas = atlas
                terrainPalette = atlas.palette()
                return atlas
            }
            return nil
        }

        private func terrainTileIndex(x: Int, y: Int, palette: PixelTerrainPalette) -> Int {
            let center = gridSize / 2
            let hash = abs((x * 73856093) ^ (y * 19349663) ^ (gridSize * 83492791))
            let roll = hash % 100
            if abs(x - center) <= 1 || abs(y - center) <= 1 {
                if !palette.dirt.isEmpty {
                    return palette.dirt[hash % palette.dirt.count]
                }
            }
            if roll < 8, !palette.water.isEmpty {
                return palette.water[hash % palette.water.count]
            }
            if roll < 20, !palette.dirt.isEmpty {
                return palette.dirt[hash % palette.dirt.count]
            }
            if !palette.grass.isEmpty {
                return palette.grass[hash % palette.grass.count]
            }
            return palette.dirt.first ?? 0
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            
            let buildingHits = view.hitTest(point, options: [SCNHitTestOption.categoryBitMask: 2])
            if let hit = buildingHits.first, let node = findBuildingNode(from: hit.node) {
                if let idString = node.name?.replacingOccurrences(of: "building:", with: ""),
                   let uuid = UUID(uuidString: idString),
                   let match = engine.state.buildings.first(where: { $0.id == uuid }) {
                    selectedBuilding.wrappedValue = match
                }
                return
            }
            
            let groundHits = view.hitTest(point, options: [SCNHitTestOption.categoryBitMask: 1])
            guard let ground = groundHits.first else { return }
            let position = ground.worldCoordinates
            let gridX = Int(floor(position.x))
            let gridY = Int(floor(position.z))
            guard gridX >= 0, gridY >= 0, gridX < gridSize, gridY < gridSize else { return }
            
            if let buildId = selectedBuildId.wrappedValue {
                if engine.gridOccupied(x: gridX, y: gridY) {
                    toastCenter.push(message: "Tile occupied", style: .warning)
                    return
                }
                if let reason = engine.buildBlockReason(buildingId: buildId) {
                    toastCenter.push(message: reason, style: .warning)
                    return
                }
                engine.startBuilding(buildingId: buildId, at: (gridX, gridY))
                selectedBuildId.wrappedValue = nil
            } else {
                selectedBuilding.wrappedValue = engine.buildingAt(x: gridX, y: gridY)
            }
        }
        
        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            if gesture.state == .began {
                panStart = translation
                lastPanTick = CACurrentMediaTime()
            }
            let deltaX = SCNFloat(translation.x - panStart.x)
            let deltaY = SCNFloat(translation.y - panStart.y)
            panStart = translation
            let worldPerPoint = worldUnitsPerPoint()
            targetLookPoint.x -= deltaX * worldPerPoint
            targetLookPoint.z += deltaY * worldPerPoint
            registerInput()
            let now = CACurrentMediaTime()
            let dt = max(1.0 / 120.0, now - lastPanTick)
            lastPanTick = now
            let velocityX = Double(-deltaX * worldPerPoint) / dt
            let velocityZ = Double(deltaY * worldPerPoint) / dt
            panVelocity = CGVector(dx: velocityX, dy: velocityZ)
            applyCameraConstraints(animated: true)
            if gesture.state == .ended || gesture.state == .cancelled {
                if abs(panVelocity.dx) < 0.02 && abs(panVelocity.dy) < 0.02 {
                    panVelocity = .zero
                }
            }
        }
        
        @objc func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
            guard let camera = cameraNode.camera,
                  let view = gesture.view as? SCNView else { return }
            let location = gesture.location(in: view)
            let preHit = view.hitTest(location, options: [SCNHitTestOption.categoryBitMask: 1]).first
            let oldScale = camera.orthographicScale
            let zoomFactor = 1 - Double(gesture.magnification)
            let next = clampedScale(oldScale * zoomFactor)
            gesture.magnification = 0
            guard next != oldScale else { return }
            camera.orthographicScale = next
            let postHit = view.hitTest(location, options: [SCNHitTestOption.categoryBitMask: 1]).first
            camera.orthographicScale = oldScale
            targetScale = next
            if let pre = preHit?.worldCoordinates, let post = postHit?.worldCoordinates {
                targetLookPoint.x += (pre.x - post.x)
                targetLookPoint.z += (pre.z - post.z)
            }
            registerInput()
            applyCameraConstraints(animated: true, animateScale: true)
        }
        
        func handleScroll(event: NSEvent) {
            let deltaX = event.scrollingDeltaX
            let deltaY = event.scrollingDeltaY
            let worldPerPoint = worldUnitsPerPoint()
            let lineMultiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1.0 : 12.0
            let momentumFactor: CGFloat = event.momentumPhase.isEmpty ? 1.0 : 0.7
            let scale = worldPerPoint * lineMultiplier * momentumFactor
            targetLookPoint.x -= SCNFloat(deltaX) * scale
            targetLookPoint.z += SCNFloat(deltaY) * scale
            registerInput()
            let now = event.timestamp
            let dt = max(1.0 / 120.0, now - lastPanTick)
            lastPanTick = now
            let velocityX = Double(-SCNFloat(deltaX) * scale) / dt
            let velocityZ = Double(SCNFloat(deltaY) * scale) / dt
            let velocityFactor: Double = event.momentumPhase.isEmpty ? 0.6 : 0.3
            panVelocity = CGVector(dx: velocityX * velocityFactor, dy: velocityZ * velocityFactor)
            applyCameraConstraints(animated: true)
        }

        func updateEdgePan(point: CGPoint?, bounds: CGRect) {
            if selectedBuildId.wrappedValue == nil && selectedBuilding.wrappedValue == nil {
                edgePanVelocity = .zero
                return
            }
            guard let point, bounds.width > 0, bounds.height > 0 else {
                edgePanVelocity = .zero
                return
            }
            let inset: CGFloat = 28
            var vx: CGFloat = 0
            var vy: CGFloat = 0
            if point.x < inset {
                vx = -max(0, (inset - point.x) / inset)
            } else if point.x > bounds.width - inset {
                vx = max(0, (point.x - (bounds.width - inset)) / inset)
            }
            if point.y < inset {
                vy = max(0, (inset - point.y) / inset)
            } else if point.y > bounds.height - inset {
                vy = -max(0, (point.y - (bounds.height - inset)) / inset)
            }
            edgePanVelocity = CGVector(dx: vx, dy: vy)
        }

        private func applyCameraConstraints(animated: Bool, animateScale: Bool = false) {
            guard let camera = cameraNode.camera else { return }
            targetScale = clampedScale(targetScale)
            targetLookPoint = clampedLookPoint(targetLookPoint, scale: targetScale)
            let center = screenCenterIntersectionY0(usingScale: targetScale)
            let dx = targetLookPoint.x - center.x
            let dz = targetLookPoint.z - center.z
            targetPosition = SCNVector3(cameraRig.position.x + dx, targetPosition.y, cameraRig.position.z + dz)
            if animated {
                SCNTransaction.begin()
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                SCNTransaction.animationDuration = 0.08
                cameraRig.position = targetPosition
                if animateScale {
                    camera.orthographicScale = targetScale
                }
                SCNTransaction.commit()
            } else {
                cameraRig.position = targetPosition
                if animateScale {
                    camera.orthographicScale = targetScale
                }
            }
        }

        private func clampedScale(_ scale: Double) -> Double {
            let focusMin = max(3.0, Double(gridSize) * 0.12)
            let normalMin = max(4.0, Double(gridSize) * 0.35)
            let minScale = lastFocusedBuildingId == nil ? normalMin : focusMin
            let maxScale = max(minScale + 2.0, Double(gridSize) * 1.3)
            return max(minScale, min(maxScale, scale))
        }

        private func clampedLookPoint(_ point: SCNVector3, scale: Double) -> SCNVector3 {
            let size = SCNFloat(gridSize)
            guard let view = view, view.bounds.height > 0 else {
                let x = max(SCNFloat(0), min(size, point.x))
                let z = max(SCNFloat(0), min(size, point.z))
                return SCNVector3(x, point.y, z)
            }
            let aspect = SCNFloat(view.bounds.width / view.bounds.height)
            let worldHeight: SCNFloat = SCNFloat(scale)
            let halfHeight: SCNFloat = worldHeight * 0.5
            let halfWidth: SCNFloat = halfHeight * max(SCNFloat(0.6), aspect)
            let focusPadding: SCNFloat = lastFocusedBuildingId == nil ? 0 : max(halfWidth, halfHeight)
            let minX = 0 - focusPadding
            let maxX = size + focusPadding
            let minZ = 0 - focusPadding
            let maxZ = size + focusPadding
            let clampedX: SCNFloat
            let clampedZ: SCNFloat
            if minX > maxX {
                clampedX = size * 0.5
            } else {
                clampedX = max(minX, min(maxX, point.x))
            }
            if minZ > maxZ {
                clampedZ = size * 0.5
            } else {
                clampedZ = max(minZ, min(maxZ, point.z))
            }
            return SCNVector3(clampedX, point.y, clampedZ)
        }

        private func focus(on building: BuildingInstance) {
            targetScale = max(3.6, Double(gridSize) * 0.18)
            let desired = SCNVector3(SCNFloat(building.x) + 0.5, 0, SCNFloat(building.y) + 0.5)
            targetLookPoint = desired
            applyCameraConstraints(animated: true, animateScale: true)
            spawnFocusActors(around: building)
        }

        private func resetFocus(animated: Bool) {
            targetScale = defaultScale
            applyCameraConstraints(animated: animated, animateScale: true)
            clearFocusActors()
        }

        private func centerMap(animated: Bool) {
            let desired = SCNVector3(SCNFloat(gridSize) * 0.5, 0, SCNFloat(gridSize) * 0.5)
            targetLookPoint = desired
            registerInput()
            applyCameraConstraints(animated: animated)
        }

        private func spawnFocusActors(around building: BuildingInstance) {
            clearFocusActors()
            let center = SCNVector3(Float(building.x) + 0.5, 0.06, Float(building.y) + 0.5)
            let offsets: [SCNVector3] = [
                SCNVector3(0.5, 0, 0),
                SCNVector3(-0.5, 0, 0),
                SCNVector3(0, 0, 0.5),
                SCNVector3(0, 0, -0.5)
            ]
            let positions = offsets.shuffled().prefix(3).map { SCNVector3(center.x + $0.x, center.y, center.z + $0.z) }
            for position in positions {
                if let actor = buildAmbientActor(at: position, speedRange: 0.35...0.7) {
                    focusActors.append(actor)
                    scene.rootNode.addChildNode(actor.node)
                    scheduleFocusOrbit(for: actor, center: center)
                }
            }
        }

        private func clearFocusActors() {
            for actor in focusActors {
                actor.node.removeFromParentNode()
            }
            focusActors.removeAll()
        }

        private func scheduleFocusOrbit(for actor: AmbientActor, center: SCNVector3) {
            let radius: CGFloat = 0.45
            let points = [
                SCNVector3(center.x + radius, center.y, center.z),
                SCNVector3(center.x, center.y, center.z + radius),
                SCNVector3(center.x - radius, center.y, center.z),
                SCNVector3(center.x, center.y, center.z - radius)
            ]
            let moves = points.map { point in
                SCNAction.move(to: point, duration: Double.random(in: 0.7...1.1))
            }
            let wait = SCNAction.wait(duration: Double.random(in: 0.2...0.5))
            let sequence = SCNAction.sequence(moves.flatMap { [$0, wait] })
            actor.node.runAction(SCNAction.repeatForever(sequence), forKey: "orbit")
        }

        private func screenCenterIntersectionY0() -> SCNVector3 {
            guard let view = view, view.bounds.width > 0, view.bounds.height > 0 else {
                return cameraPlaneIntersectionY0()
            }
            let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            let near = view.unprojectPoint(SCNVector3(Float(center.x), Float(center.y), 0))
            let far = view.unprojectPoint(SCNVector3(Float(center.x), Float(center.y), 1))
            let dir = SCNVector3(far.x - near.x, far.y - near.y, far.z - near.z)
            if abs(dir.y) < 0.0001 {
                return SCNVector3(near.x, 0, near.z)
            }
            let t = (0 - near.y) / dir.y
            return SCNVector3(near.x + dir.x * t, 0, near.z + dir.z * t)
        }

        private func screenCenterIntersectionY0(usingScale scale: Double) -> SCNVector3 {
            guard let camera = cameraNode.camera else {
                return screenCenterIntersectionY0()
            }
            let previous = camera.orthographicScale
            camera.orthographicScale = scale
            let point = screenCenterIntersectionY0()
            camera.orthographicScale = previous
            return point
        }

        private func cameraPlaneIntersectionY0() -> SCNVector3 {
            let worldPosition = cameraNode.worldPosition
            let forward = cameraNode.worldFront
            let denom = forward.y
            if abs(denom) < 0.0001 {
                return SCNVector3(worldPosition.x, 0, worldPosition.z)
            }
            let t = (0 - worldPosition.y) / denom
            return SCNVector3(worldPosition.x + forward.x * t, 0, worldPosition.z + forward.z * t)
        }

        private func updateLookOffset() {
            let intersection = cameraPlaneIntersectionY0()
            cameraLookOffset = SCNVector3(intersection.x - cameraRig.position.x, 0, intersection.z - cameraRig.position.z)
        }

        private func startEdgePanTimer() {
            edgePanTimer?.invalidate()
            edgePanTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.stepEdgePan()
            }
        }

        private func worldUnitsPerPoint() -> SCNFloat {
            guard let view = view, view.bounds.height > 0 else {
                return SCNFloat(cameraNode.camera?.orthographicScale ?? 1) * 0.002
            }
            let scale = SCNFloat(cameraNode.camera?.orthographicScale ?? 1)
            return scale / SCNFloat(view.bounds.height)
        }

        private func stepEdgePan() {
            let now = CACurrentMediaTime()
            let dt = now - lastEdgeTick
            lastEdgeTick = now
            updateAmbientActors(now: now)
            updateAmbientLighting(now: now)
            if now - lastInputAt < 0.25 {
                return
            }
            let baseScale = SCNFloat(cameraNode.camera?.orthographicScale ?? 1)
            var didMove = false
            if edgePanVelocity.dx != 0 || edgePanVelocity.dy != 0 {
                let speed = baseScale * 0.45
                targetLookPoint.x += SCNFloat(edgePanVelocity.dx) * speed * SCNFloat(dt)
                targetLookPoint.z += SCNFloat(edgePanVelocity.dy) * speed * SCNFloat(dt)
                didMove = true
            }
            if panVelocity.dx != 0 || panVelocity.dy != 0 {
                targetLookPoint.x += SCNFloat(panVelocity.dx) * SCNFloat(dt)
                targetLookPoint.z += SCNFloat(panVelocity.dy) * SCNFloat(dt)
                let decay = pow(panDecay, dt * 60.0)
                panVelocity = CGVector(dx: panVelocity.dx * decay, dy: panVelocity.dy * decay)
                if abs(panVelocity.dx) < 0.01 && abs(panVelocity.dy) < 0.01 {
                    panVelocity = .zero
                }
                didMove = true
            }
            if !didMove,
               now - lastInputAt > 2.0,
               selectedBuilding.wrappedValue == nil,
               selectedBuildId.wrappedValue == nil {
                let center = SCNVector3(SCNFloat(gridSize) * 0.5, targetLookPoint.y, SCNFloat(gridSize) * 0.5)
                let pull = min(1.0, dt * 0.6)
                targetLookPoint.x += (center.x - targetLookPoint.x) * SCNFloat(pull)
                targetLookPoint.z += (center.z - targetLookPoint.z) * SCNFloat(pull)
                didMove = true
            }
            if didMove {
                applyCameraConstraints(animated: true)
            }
        }
        
        private func findBuildingNode(from node: SCNNode) -> SCNNode? {
            var current: SCNNode? = node
            while let cursor = current {
                if let name = cursor.name, name.hasPrefix("building:") {
                    return cursor
                }
                current = cursor.parent
            }
            return nil
        }

        private func registerInput() {
            lastInputAt = CACurrentMediaTime()
        }

        private func updateAmbientActors(now: TimeInterval) {
            let dt = now - lastAmbientTick
            if dt <= 0 { return }
            lastAmbientTick = now
            for actor in ambientActors.values {
                updateActor(actor, now: now)
            }
            for actor in focusActors {
                updateActor(actor, now: now)
            }
            for actors in buildingActors.values {
                for actor in actors {
                    updateActor(actor, now: now)
                }
            }
        }

        private func updateActor(_ actor: AmbientActor, now: TimeInterval) {
            let current = actor.node.position
            let dx = current.x - actor.lastPosition.x
            let dz = current.z - actor.lastPosition.z
            let moved = (dx * dx + dz * dz) > 0.000004
            if abs(dx) > 0.0005 {
                let baseScale = abs(actor.spriteNode.scale.x)
                actor.spriteNode.scale.x = dx >= 0 ? baseScale : -baseScale
            }
            actor.lastPosition = current
            let frames = moved ? actor.frames : actor.idleFrames
            let fps = moved ? actor.fps : actor.idleFps
            guard frames.count > 1 else { return }
            let frameDuration = 1.0 / max(1.0, fps)
            if now - actor.lastFrameTime >= frameDuration {
                actor.frameIndex = (actor.frameIndex + 1) % frames.count
                actor.spriteNode.geometry?.materials.first?.diffuse.contents = frames[actor.frameIndex]
                actor.lastFrameTime = now
            }
        }

        private func updateAmbientLighting(now: TimeInterval) {
            guard let ambient = ambientLightNode.light,
                  let directional = directionalLightNode.light else { return }
            let pulse = (sin(now * 0.2) + 1) * 0.5
            ambient.intensity = 560 + pulse * 80
            directional.intensity = 1100 + pulse * 140
        }
    }
}

final class BaseSceneSCNView: SCNView {
    var onScrollEvent: ((NSEvent) -> Void)?
    var onMouseMove: ((CGPoint, CGRect) -> Void)?
    var onMouseExit: (() -> Void)?
    private var tracking: NSTrackingArea?
    
    override func scrollWheel(with event: NSEvent) {
        onScrollEvent?(event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking {
            removeTrackingArea(tracking)
        }
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        onMouseMove?(point, bounds)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExit?()
    }
}

private final class AmbientActor {
    let id = UUID()
    let node: SCNNode
    let spriteNode: SCNNode
    let frames: [NSImage]
    let fps: Double
    let idleFrames: [NSImage]
    let idleFps: Double
    var frameIndex: Int = 0
    var lastFrameTime: TimeInterval = CACurrentMediaTime()
    let speed: Double
    var lastPosition: SCNVector3

    init(node: SCNNode, spriteNode: SCNNode, frames: [NSImage], fps: Double, idleFrames: [NSImage], idleFps: Double, speed: Double) {
        self.node = node
        self.spriteNode = spriteNode
        self.frames = frames
        self.fps = fps
        self.idleFrames = idleFrames
        self.idleFps = idleFps
        self.speed = speed
        self.lastPosition = node.position
    }
}
