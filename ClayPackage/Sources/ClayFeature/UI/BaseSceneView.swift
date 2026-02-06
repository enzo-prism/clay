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
            context.coordinator.updateHover(point: point, bounds: bounds)
        }
        view.onMouseExit = {
            context.coordinator.updateEdgePan(point: nil, bounds: .zero)
            context.coordinator.updateHover(point: nil, bounds: .zero)
        }
        
        return view
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        if nsView.scene !== context.coordinator.scene {
            nsView.scene = context.coordinator.scene
        }
        context.coordinator.update(engine: engine, selectedBuildId: selectedBuildId, selectedBuilding: selectedBuilding, overlayMode: overlayMode, centerTrigger: centerTrigger)
    }

    static func dismantleNSView(_ nsView: SCNView, coordinator: Coordinator) {
        Task { @MainActor in
            coordinator.stopEdgePanTimer()
        }
    }
    
    @MainActor
    final class Coordinator: NSObject {
        private struct BaseMapStyle {
            let terrainFill: NSColor
            let gridMinor: NSColor
            let gridMajor: NSColor
            let plateFill: NSColor
            let plateStroke: NSColor
            let hoverStroke: NSColor
            let buildOverlayStroke: NSColor
            let tilePixelSize: Int = 16

            init(eraId: String) {
                switch eraId {
                case "stone":
                    terrainFill = NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.09, alpha: 1.0)
                    gridMinor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
                    gridMajor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
                    plateFill = NSColor(calibratedRed: 0.17, green: 0.15, blue: 0.14, alpha: 1.0)
                    plateStroke = NSColor(calibratedRed: 0.82, green: 0.64, blue: 0.44, alpha: 0.7)
                    hoverStroke = NSColor(calibratedRed: 0.9, green: 0.72, blue: 0.48, alpha: 0.9)
                    buildOverlayStroke = NSColor(calibratedRed: 0.9, green: 0.72, blue: 0.48, alpha: 0.3)
                case "agrarian":
                    terrainFill = NSColor(calibratedRed: 0.08, green: 0.14, blue: 0.10, alpha: 1.0)
                    gridMinor = NSColor(calibratedWhite: 1.0, alpha: 0.07)
                    gridMajor = NSColor(calibratedWhite: 1.0, alpha: 0.14)
                    plateFill = NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.14, alpha: 1.0)
                    plateStroke = NSColor(calibratedRed: 0.55, green: 0.78, blue: 0.55, alpha: 0.7)
                    hoverStroke = NSColor(calibratedRed: 0.62, green: 0.88, blue: 0.62, alpha: 0.9)
                    buildOverlayStroke = NSColor(calibratedRed: 0.62, green: 0.88, blue: 0.62, alpha: 0.3)
                case "metallurgy":
                    terrainFill = NSColor(calibratedRed: 0.14, green: 0.10, blue: 0.08, alpha: 1.0)
                    gridMinor = NSColor(calibratedWhite: 1.0, alpha: 0.07)
                    gridMajor = NSColor(calibratedWhite: 1.0, alpha: 0.14)
                    plateFill = NSColor(calibratedRed: 0.17, green: 0.14, blue: 0.12, alpha: 1.0)
                    plateStroke = NSColor(calibratedRed: 0.92, green: 0.69, blue: 0.38, alpha: 0.75)
                    hoverStroke = NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.46, alpha: 0.9)
                    buildOverlayStroke = NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.46, alpha: 0.3)
                case "industrial":
                    terrainFill = NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.13, alpha: 1.0)
                    gridMinor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
                    gridMajor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
                    plateFill = NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.22, alpha: 1.0)
                    plateStroke = NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 0.65)
                    hoverStroke = NSColor(calibratedRed: 0.55, green: 0.82, blue: 1.0, alpha: 0.9)
                    buildOverlayStroke = NSColor(calibratedRed: 0.55, green: 0.82, blue: 1.0, alpha: 0.28)
                case "planetary":
                    terrainFill = NSColor(calibratedRed: 0.06, green: 0.11, blue: 0.15, alpha: 1.0)
                    gridMinor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
                    gridMajor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
                    plateFill = NSColor(calibratedRed: 0.11, green: 0.17, blue: 0.23, alpha: 1.0)
                    plateStroke = NSColor(calibratedRed: 0.45, green: 0.78, blue: 0.92, alpha: 0.7)
                    hoverStroke = NSColor(calibratedRed: 0.52, green: 0.88, blue: 1.0, alpha: 0.9)
                    buildOverlayStroke = NSColor(calibratedRed: 0.52, green: 0.88, blue: 1.0, alpha: 0.3)
                case "stellar":
                    terrainFill = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.16, alpha: 1.0)
                    gridMinor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
                    gridMajor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
                    plateFill = NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.26, alpha: 1.0)
                    plateStroke = NSColor(calibratedRed: 0.70, green: 0.62, blue: 0.95, alpha: 0.7)
                    hoverStroke = NSColor(calibratedRed: 0.76, green: 0.70, blue: 1.0, alpha: 0.9)
                    buildOverlayStroke = NSColor(calibratedRed: 0.76, green: 0.70, blue: 1.0, alpha: 0.3)
                case "galactic":
                    terrainFill = NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.14, alpha: 1.0)
                    gridMinor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
                    gridMajor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
                    plateFill = NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.22, alpha: 1.0)
                    plateStroke = NSColor(calibratedRed: 0.56, green: 0.95, blue: 0.82, alpha: 0.7)
                    hoverStroke = NSColor(calibratedRed: 0.62, green: 1.0, blue: 0.90, alpha: 0.9)
                    buildOverlayStroke = NSColor(calibratedRed: 0.62, green: 1.0, blue: 0.90, alpha: 0.3)
                default:
                    terrainFill = NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.13, alpha: 1.0)
                    gridMinor = NSColor(calibratedWhite: 1.0, alpha: 0.08)
                    gridMajor = NSColor(calibratedWhite: 1.0, alpha: 0.16)
                    plateFill = NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.22, alpha: 1.0)
                    plateStroke = NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 0.65)
                    hoverStroke = NSColor(calibratedRed: 0.55, green: 0.82, blue: 1.0, alpha: 0.9)
                    buildOverlayStroke = NSColor(calibratedRed: 0.55, green: 0.82, blue: 1.0, alpha: 0.28)
                }
            }
        }

        private var style = BaseMapStyle(eraId: "stone")
        private(set) var scene: SCNScene = SCNScene()
        private let cameraRig = SCNNode()
        private let cameraNode = SCNNode()
        private let terrainNode = SCNNode()
        private let selectionNode = SCNNode()
        private let buildOverlayNode = SCNNode()
        private let hoverNode = SCNNode()
        private var ambientLightNode = SCNNode()
        private var directionalLightNode = SCNNode()
        private var buildingNodes: [UUID: SCNNode] = [:]
        private var overlayNodes: [UUID: SCNNode] = [:]
        private var activityNodes: [UUID: SCNNode] = [:]
        private var placementHighlightNodes: [String: SCNNode] = [:]
        private var ambientNodes: [String: [SCNNode]] = [:]
        private var ambientActors: [UUID: AmbientActor] = [:]
        private var focusActors: [AmbientActor] = []
        private var buildingActors: [UUID: [AmbientActor]] = [:]
        private var tileAtlas: PixelTileAtlas?
        private var terrainPalette: PixelTerrainPalette?
        private var terrainImageCache: NSImage?
        private var terrainImageSize: Int = 0
        private var buildOverlayImageCache: NSImage?
        private var buildOverlayImageSize: Int = 0
        private var buildingPlateCache: NSImage?
        private var hoverRingCache: NSImage?
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
        private var currentEraId: String?
        private let backend: RenderBackend = SceneKitBackend()
        private weak var view: SCNView?
        private var targetPosition: SCNVector3 = SCNVector3(0, 0, 0)
        private var targetLookPoint: SCNVector3 = SCNVector3(0, 0, 0)
        private var targetScale: Double = 10
        private var lastFocusedBuildingId: UUID?
        private var cameraLookOffset: SCNVector3 = SCNVector3(0, 0, 0)
        private var edgePanVelocity: CGVector = .zero
        private var panVelocity: CGVector = .zero
        private var panTimer: Timer?
        private var recenterTimer: Timer?
        private var lastEdgeTick: TimeInterval = CACurrentMediaTime()
        private var lastPanTick: TimeInterval = CACurrentMediaTime()
        private var lastInputAt: TimeInterval = CACurrentMediaTime()
        private let panDecay: Double = 0.92
        private var lastAmbientTick: TimeInterval = CACurrentMediaTime()
        private let ambientUpdateInterval: TimeInterval = 1.0 / 12.0
        private var lastAmbientUpdate: TimeInterval = CACurrentMediaTime()
        private var defaultScale: Double = 10
        private var lastHoverGrid: (x: Int, y: Int)?
        
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

        func stopEdgePanTimer() {
            recenterTimer?.invalidate()
            recenterTimer = nil
            panTimer?.invalidate()
            panTimer = nil
        }

        func attach(view: SCNView) {
            self.view = view
            view.window?.acceptsMouseMovedEvents = true
            DispatchQueue.main.async { [weak self] in
                self?.updateLookOffset()
                self?.centerMap(animated: false)
            }
        }
        
        func update(engine: GameEngine, selectedBuildId: String?, selectedBuilding: BuildingInstance?, overlayMode: BaseOverlayMode, centerTrigger: Int) {
            PerfSignposts.sceneUpdate {
                self.engine = engine
                self.overlayMode = overlayMode

                // If selection/build mode is cleared, also clear any edge-pan velocity that might have been left
                // non-zero (mouse events may not fire in the same frame as selection changes).
                if selectedBuildId == nil && selectedBuilding == nil {
                    edgePanVelocity = .zero
                }

                if engine.state.eraId != currentEraId {
                    currentEraId = engine.state.eraId
                    applyEraStyle(eraId: engine.state.eraId)
                }
                if gridSize != engine.state.gridSize {
                    configureScene()
                }
                buildOverlayNode.isHidden = (selectedBuildId == nil)
                syncPlacementHighlights(selectedBuildId: selectedBuildId)

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

                let overlaySignature = overlaySignature(buildingSignature: buildingSignature, overlayMode: overlayMode, buildings: buildings)
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
                } else if lastFocusedBuildingId != nil {
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
            placementHighlightNodes = [:]
            ambientNodes = [:]
            ambientActors = [:]
            focusActors = []
            buildingActors = [:]
            tileAtlas = nil
            terrainPalette = nil
            terrainImageCache = nil
            terrainImageSize = 0
            buildOverlayImageCache = nil
            buildOverlayImageSize = 0
            buildingPlateCache = nil
            hoverRingCache = nil
            lastHoverGrid = nil
            gridSize = engine.state.gridSize
            lastBuildingSignature = Int.min
            lastBuildingActorSignature = Int.min
            lastOverlaySignature = Int.min
            lastActivitySignature = Int.min
            lastAmbientSignature = Int.min
            lastAmbientActorSignature = Int.min
            let now = CACurrentMediaTime()
            lastAmbientTick = now
            lastAmbientUpdate = now
            setupCamera()
            setupTerrain()
            setupBuildOverlay()
            setupLights()
            setupSelection()
            setupHover()
            centerMap(animated: false)
        }

        private func applyEraStyle(eraId: String) {
            style = BaseMapStyle(eraId: eraId)
            configureScene()
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

        private func setupBuildOverlay() {
            let plane = SCNPlane(width: CGFloat(gridSize), height: CGFloat(gridSize))
            let material = SCNMaterial()
            material.diffuse.contents = buildOverlayImage()
            material.isDoubleSided = true
            material.diffuse.magnificationFilter = .nearest
            material.diffuse.minificationFilter = .nearest
            material.lightingModel = .constant
            plane.materials = [material]
            buildOverlayNode.geometry = plane
            buildOverlayNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            buildOverlayNode.position = SCNVector3(Float(gridSize) / 2, 0.028, Float(gridSize) / 2)
            buildOverlayNode.isHidden = true
            buildOverlayNode.categoryBitMask = 16
            scene.rootNode.addChildNode(buildOverlayNode)
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
            selectionNode.position = SCNVector3(0, 0.04, 0)
            selectionNode.isHidden = true
            scene.rootNode.addChildNode(selectionNode)
        }

        private func setupHover() {
            let ring = SCNPlane(width: 0.95, height: 0.95)
            let material = SCNMaterial()
            material.diffuse.contents = hoverRingImage()
            material.isDoubleSided = true
            material.diffuse.magnificationFilter = .nearest
            material.diffuse.minificationFilter = .nearest
            material.lightingModel = .constant
            ring.materials = [material]
            hoverNode.geometry = ring
            hoverNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            hoverNode.position = SCNVector3(0, 0.05, 0)
            hoverNode.isHidden = true
            hoverNode.categoryBitMask = 32
            scene.rootNode.addChildNode(hoverNode)
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

        private func overlaySignature(buildingSignature: Int, overlayMode: BaseOverlayMode, buildings: [BuildingInstance]) -> Int {
            var hasher = Hasher()
            hasher.combine(buildingSignature)
            hasher.combine(overlayMode.rawValue)
            switch overlayMode {
            case .logisticsImpact:
                for building in buildings.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                    hasher.combine(building.id)
                    hasher.combine(logisticsImpact(for: building))
                }
            case .defense:
                for building in buildings.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                    hasher.combine(building.id)
                    hasher.combine(defenseValue(for: building))
                }
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
            let overlayContext = overlayContext(for: buildings)
            let existingIds = Set(overlayNodes.keys)
            let currentIds = Set(buildings.map { $0.id })
            for removedId in existingIds.subtracting(currentIds) {
                overlayNodes[removedId]?.removeFromParentNode()
                overlayNodes.removeValue(forKey: removedId)
            }
            for building in buildings {
                let color = overlayColor(for: building, values: overlayContext.values, normalization: overlayContext.maxValue)
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

        private func syncPlacementHighlights(selectedBuildId: String?) {
            guard let selectedBuildId,
                  let def = engine.content.buildingsById[selectedBuildId] else {
                for (_, node) in placementHighlightNodes {
                    node.removeFromParentNode()
                }
                placementHighlightNodes = [:]
                return
            }
            var desired: [String: NSColor] = [:]
            if let adjacency = def.adjacencyBonus {
                let requiredId = adjacency.requiresBuildingId
                for building in engine.state.buildings where building.buildingId == requiredId {
                    for (x, y) in neighborTiles(x: building.x, y: building.y) {
                        addPlacementTile(x: x, y: y, color: placementAccentColor(), desired: &desired)
                    }
                }
            }
            if let tag = def.districtTag {
                for building in engine.state.buildings {
                    guard let neighborDef = engine.content.buildingsById[building.buildingId],
                          neighborDef.districtTag == tag else { continue }
                    for (x, y) in neighborTiles(x: building.x, y: building.y) {
                        addPlacementTile(x: x, y: y, color: placementWarmColor(), desired: &desired)
                    }
                }
            }
            let existingKeys = Set(placementHighlightNodes.keys)
            let desiredKeys = Set(desired.keys)
            for removed in existingKeys.subtracting(desiredKeys) {
                placementHighlightNodes[removed]?.removeFromParentNode()
                placementHighlightNodes.removeValue(forKey: removed)
            }
            for (key, color) in desired {
                if let existing = placementHighlightNodes[key] {
                    existing.geometry?.materials.first?.diffuse.contents = color
                } else if let (x, y) = parseTileKey(key) {
                    let position = SCNVector3(Float(x) + 0.5, 0.035, Float(y) + 0.5)
                    let node = backend.makeOverlayNode(size: 0.9, color: color, position: position)
                    placementHighlightNodes[key] = node
                    scene.rootNode.addChildNode(node)
                }
            }
        }

        private func addPlacementTile(x: Int, y: Int, color: NSColor, desired: inout [String: NSColor]) {
            guard x >= 0, y >= 0, x < gridSize, y < gridSize else { return }
            if engine.buildingAt(x: x, y: y) != nil {
                return
            }
            let key = tileKey(x: x, y: y)
            if desired[key] == nil {
                desired[key] = color
            }
        }

        private func neighborTiles(x: Int, y: Int) -> [(Int, Int)] {
            [
                (x + 1, y),
                (x - 1, y),
                (x, y + 1),
                (x, y - 1)
            ]
        }

        private func tileKey(x: Int, y: Int) -> String {
            "\(x)-\(y)"
        }

        private func parseTileKey(_ key: String) -> (Int, Int)? {
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let x = Int(parts[0]),
                  let y = Int(parts[1]) else { return nil }
            return (x, y)
        }

        private func placementAccentColor() -> NSColor {
            NSColor(calibratedRed: 0.60, green: 0.78, blue: 0.70, alpha: 0.25)
        }

        private func placementWarmColor() -> NSColor {
            NSColor(calibratedRed: 0.86, green: 0.74, blue: 0.55, alpha: 0.25)
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
            material.diffuse.contents = NSColor(calibratedRed: 0.45, green: 0.58, blue: 0.78, alpha: 0.28)
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

        private func overlayColor(for building: BuildingInstance, values: [UUID: Double], normalization: Double) -> NSColor {
            switch overlayMode {
            case .logisticsImpact:
                let impact = values[building.id, default: 0]
                if abs(impact) < 0.0001 {
                    return NSColor(calibratedWhite: 0.65, alpha: 0.22)
                }
                let maxValue = max(0.0001, normalization)
                let t = CGFloat(min(1.0, abs(impact) / maxValue))
                if impact >= 0 {
                    return colorLerp(from: NSColor(calibratedRed: 0.32, green: 0.5, blue: 0.4, alpha: 0.22),
                                     to: NSColor(calibratedRed: 0.38, green: 0.7, blue: 0.52, alpha: 0.32),
                                     t: t)
                } else {
                    return colorLerp(from: NSColor(calibratedRed: 0.5, green: 0.3, blue: 0.3, alpha: 0.22),
                                     to: NSColor(calibratedRed: 0.78, green: 0.36, blue: 0.36, alpha: 0.32),
                                     t: t)
                }
            case .district:
                if let def = engine.content.buildingsById[building.buildingId],
                   let tag = def.districtTag {
                    switch tag {
                    case "food": return NSColor(calibratedRed: 0.46, green: 0.68, blue: 0.52, alpha: 0.25)
                    case "forge": return NSColor(calibratedRed: 0.72, green: 0.5, blue: 0.34, alpha: 0.25)
                    case "civic": return NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.74, alpha: 0.25)
                    case "economy": return NSColor(calibratedRed: 0.4, green: 0.58, blue: 0.76, alpha: 0.25)
                    case "energy": return NSColor(calibratedRed: 0.76, green: 0.68, blue: 0.38, alpha: 0.25)
                    case "production": return NSColor(calibratedRed: 0.46, green: 0.7, blue: 0.56, alpha: 0.25)
                    case "infrastructure": return NSColor(calibratedRed: 0.56, green: 0.6, blue: 0.78, alpha: 0.25)
                    case "industrial": return NSColor(calibratedRed: 0.56, green: 0.68, blue: 0.76, alpha: 0.25)
                    default: return NSColor(calibratedWhite: 0.8, alpha: 0.25)
                    }
                }
                return NSColor(calibratedWhite: 0.6, alpha: 0.2)
            case .defense:
                let defense = values[building.id, default: 0]
                if defense <= 0 {
                    return NSColor(calibratedWhite: 0.65, alpha: 0.22)
                }
                let maxValue = max(0.0001, normalization)
                let t = CGFloat(min(1.0, defense / maxValue))
                return colorLerp(from: NSColor(calibratedRed: 0.78, green: 0.62, blue: 0.36, alpha: 0.28),
                                 to: NSColor(calibratedRed: 0.38, green: 0.7, blue: 0.52, alpha: 0.34),
                                 t: t)
            case .none:
                return .clear
            }
        }

        private struct OverlayContext {
            let values: [UUID: Double]
            let maxValue: Double
        }

        private func overlayContext(for buildings: [BuildingInstance]) -> OverlayContext {
            switch overlayMode {
            case .logisticsImpact:
                var values: [UUID: Double] = [:]
                var maxValue = 0.0
                for building in buildings {
                    let impact = logisticsImpact(for: building)
                    values[building.id] = impact
                    maxValue = max(maxValue, abs(impact))
                }
                return OverlayContext(values: values, maxValue: maxValue)
            case .defense:
                var values: [UUID: Double] = [:]
                var maxValue = 0.0
                for building in buildings {
                    let defense = defenseValue(for: building)
                    values[building.id] = defense
                    maxValue = max(maxValue, defense)
                }
                return OverlayContext(values: values, maxValue: maxValue)
            case .district, .none:
                return OverlayContext(values: [:], maxValue: 1.0)
            }
        }

        private func logisticsImpact(for building: BuildingInstance) -> Double {
            guard let def = engine.content.buildingsById[building.buildingId] else { return 0 }
            let levelMultiplier = pow(1.1, Double(building.level - 1))
                * adjacencyMultiplier(for: building, definition: def)
                * districtMultiplier(for: building, definition: def)
            let capacityAdd = def.logisticsCapAdd * levelMultiplier
            let production = def.productionPerHour.values.reduce(0, +) * levelMultiplier
            let consumption = def.consumptionPerHour.values.reduce(0, +) * levelMultiplier
            let demandAdd = abs(production) + abs(consumption)
            return capacityAdd - demandAdd
        }

        private func defenseValue(for building: BuildingInstance) -> Double {
            guard let def = engine.content.buildingsById[building.buildingId] else { return 0 }
            return def.defenseScore
        }

        private func adjacencyMultiplier(for building: BuildingInstance, definition: BuildingDefinition) -> Double {
            guard let bonus = definition.adjacencyBonus else { return 1.0 }
            let neighbors = [
                (building.x + 1, building.y),
                (building.x - 1, building.y),
                (building.x, building.y + 1),
                (building.x, building.y - 1)
            ]
            for (x, y) in neighbors {
                if let neighbor = engine.buildingAt(x: x, y: y),
                   neighbor.buildingId == bonus.requiresBuildingId {
                    return bonus.multiplier
                }
            }
            return 1.0
        }

        private func districtMultiplier(for building: BuildingInstance, definition: BuildingDefinition) -> Double {
            guard let tag = definition.districtTag, !tag.isEmpty else { return 1.0 }
            let neighbors = [
                (building.x + 1, building.y),
                (building.x - 1, building.y),
                (building.x, building.y + 1),
                (building.x, building.y - 1)
            ]
            var matches = 0
            for (x, y) in neighbors {
                if let neighbor = engine.buildingAt(x: x, y: y),
                   let neighborDef = engine.content.buildingsById[neighbor.buildingId],
                   neighborDef.districtTag == tag {
                    matches += 1
                }
            }
            return matches >= 2 ? definition.districtBonus : 1.0
        }

        private func colorLerp(from: NSColor, to: NSColor, t: CGFloat) -> NSColor {
            let clamped = max(0, min(1, t))
            let fromRGB = from.usingColorSpace(.deviceRGB) ?? from
            let toRGB = to.usingColorSpace(.deviceRGB) ?? to
            let r = fromRGB.redComponent + (toRGB.redComponent - fromRGB.redComponent) * clamped
            let g = fromRGB.greenComponent + (toRGB.greenComponent - fromRGB.greenComponent) * clamped
            let b = fromRGB.blueComponent + (toRGB.blueComponent - fromRGB.blueComponent) * clamped
            let a = fromRGB.alphaComponent + (toRGB.alphaComponent - fromRGB.alphaComponent) * clamped
            return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
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
            let frames = PixelAssetCatalog.shared.frames(for: spriteId, idle: false)
            guard let firstFrame = frames.first else { return nil }
            let idleFrames = PixelAssetCatalog.shared.frames(for: spriteId, idle: true)
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

        private func randomActorPosition() -> SCNVector3 {
            let margin: Float = 0.8
            let maxValue = Float(max(1, gridSize - 1))
            let x = Float.random(in: margin...maxValue)
            let z = Float.random(in: margin...maxValue)
            return SCNVector3(x, 0.06, z)
        }

        @MainActor
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
            let actorId = actor.id
            let next = SCNAction.run { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.scheduleNextWalk(forActorId: actorId)
                }
            }
            actor.node.runAction(SCNAction.sequence([move, wait, next]), forKey: "walk")
        }

        @MainActor
        private func scheduleNextWalk(forActorId actorId: UUID) {
            guard let actor = ambientActors[actorId] else { return }
            scheduleNextWalk(for: actor)
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
                let container = SCNNode()
                container.position = SCNVector3(Float(building.x) + 0.5, 0.02, Float(building.y) + 0.5)
                container.name = "building:\(building.id.uuidString)"
                container.categoryBitMask = 2

                let platePlane = SCNPlane(width: 1.08, height: 1.08)
                let plateMaterial = SCNMaterial()
                plateMaterial.diffuse.contents = buildingPlateImage()
                plateMaterial.diffuse.magnificationFilter = .nearest
                plateMaterial.diffuse.minificationFilter = .nearest
                plateMaterial.isDoubleSided = true
                plateMaterial.lightingModel = .constant
                platePlane.materials = [plateMaterial]
                let plateNode = SCNNode(geometry: platePlane)
                plateNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
                plateNode.categoryBitMask = 2
                container.addChildNode(plateNode)

                let tilePlane = SCNPlane(width: 1.0, height: 1.0)
                let tileMaterial = SCNMaterial()
                tileMaterial.diffuse.contents = tile
                tileMaterial.diffuse.magnificationFilter = .nearest
                tileMaterial.diffuse.minificationFilter = .nearest
                tileMaterial.isDoubleSided = true
                tileMaterial.lightingModel = .constant
                tilePlane.materials = [tileMaterial]
                let tileNode = SCNNode(geometry: tilePlane)
                tileNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
                tileNode.position = SCNVector3(0, 0.022, 0)
                tileNode.categoryBitMask = 2
                container.addChildNode(tileNode)
                return container
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
            let image = minimalTerrainImage()
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

        private func minimalTerrainImage() -> NSImage {
            let tileSize = style.tilePixelSize
            let size = CGSize(width: gridSize * tileSize, height: gridSize * tileSize)
            let image = NSImage(size: size)
            image.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            style.terrainFill.setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            let majorStep = 4
            for y in 0...gridSize {
                let yPos = CGFloat(y * tileSize)
                let isMajor = y % majorStep == 0
                (isMajor ? style.gridMajor : style.gridMinor).setStroke()
                let path = NSBezierPath()
                path.lineWidth = 1
                path.move(to: CGPoint(x: 0, y: yPos))
                path.line(to: CGPoint(x: size.width, y: yPos))
                path.stroke()
            }
            for x in 0...gridSize {
                let xPos = CGFloat(x * tileSize)
                let isMajor = x % majorStep == 0
                (isMajor ? style.gridMajor : style.gridMinor).setStroke()
                let path = NSBezierPath()
                path.lineWidth = 1
                path.move(to: CGPoint(x: xPos, y: 0))
                path.line(to: CGPoint(x: xPos, y: size.height))
                path.stroke()
            }
            image.unlockFocus()
            return image
        }

        private func buildOverlayImage() -> NSImage {
            if let cached = buildOverlayImageCache, buildOverlayImageSize == gridSize {
                return cached
            }
            let tileSize = style.tilePixelSize
            let size = CGSize(width: gridSize * tileSize, height: gridSize * tileSize)
            let image = NSImage(size: size)
            image.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            NSColor.clear.setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            style.buildOverlayStroke.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1
            for y in 0...gridSize {
                let yPos = CGFloat(y * tileSize)
                path.move(to: CGPoint(x: 0, y: yPos))
                path.line(to: CGPoint(x: size.width, y: yPos))
            }
            for x in 0...gridSize {
                let xPos = CGFloat(x * tileSize)
                path.move(to: CGPoint(x: xPos, y: 0))
                path.line(to: CGPoint(x: xPos, y: size.height))
            }
            path.stroke()
            image.unlockFocus()
            buildOverlayImageCache = image
            buildOverlayImageSize = gridSize
            return image
        }

        private func buildingPlateImage() -> NSImage {
            if let cached = buildingPlateCache {
                return cached
            }
            let size = CGSize(width: style.tilePixelSize, height: style.tilePixelSize)
            let image = NSImage(size: size)
            image.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            style.plateFill.setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            style.plateStroke.setStroke()
            let border = NSBezierPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            border.lineWidth = 1
            border.stroke()
            image.unlockFocus()
            buildingPlateCache = image
            return image
        }

        private func hoverRingImage() -> NSImage {
            if let cached = hoverRingCache {
                return cached
            }
            let size = CGSize(width: style.tilePixelSize, height: style.tilePixelSize)
            let image = NSImage(size: size)
            image.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .none
            NSColor.clear.setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            style.hoverStroke.setStroke()
            let inset: CGFloat = 1
            let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1
            path.stroke()
            image.unlockFocus()
            hoverRingCache = image
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
            let era = currentEraId ?? "stone"
            let preferred: [String]
            switch era {
            case "stone", "agrarian":
                preferred = [
                    "Pixel/Generated/BaseMap/base_map_tileset_256.png",
                    "Pixel/PunyWorld/punyworld-overworld-tileset.png",
                    "Pixel/Winter-Pixel-Pack/World/Winter-Tileset.png"
                ]
            case "metallurgy", "industrial":
                preferred = [
                    "Pixel/PunyWorld/punyworld-overworld-tileset.png",
                    "Pixel/Generated/BaseMap/base_map_tileset_256.png",
                    "Pixel/Winter-Pixel-Pack/World/Winter-Tileset.png"
                ]
            default:
                preferred = [
                    "Pixel/Winter-Pixel-Pack/World/Winter-Tileset.png",
                    "Pixel/PunyWorld/punyworld-overworld-tileset.png",
                    "Pixel/Generated/BaseMap/base_map_tileset_256.png"
                ]
            }
            for path in preferred {
                if let atlas = PixelTileAtlas(path: path, tileSize: 16) {
                    tileAtlas = atlas
                    terrainPalette = atlas.palette()
                    return atlas
                }
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

        func updateHover(point: CGPoint?, bounds: CGRect) {
            guard let view, let point, bounds.width > 0, bounds.height > 0 else {
                hoverNode.isHidden = true
                lastHoverGrid = nil
                NSCursor.arrow.set()
                return
            }
            let buildingHits = view.hitTest(point, options: [SCNHitTestOption.categoryBitMask: 2])
            if let hit = buildingHits.first, let node = findBuildingNode(from: hit.node),
               let idString = node.name?.replacingOccurrences(of: "building:", with: ""),
               let uuid = UUID(uuidString: idString),
               let match = engine.state.buildings.first(where: { $0.id == uuid }) {
                hoverNode.isHidden = false
                hoverNode.position = SCNVector3(Float(match.x) + 0.5, 0.05, Float(match.y) + 0.5)
                lastHoverGrid = (match.x, match.y)
                NSCursor.pointingHand.set()
                return
            }
            let groundHits = view.hitTest(point, options: [SCNHitTestOption.categoryBitMask: 1])
            guard let ground = groundHits.first else {
                hoverNode.isHidden = true
                lastHoverGrid = nil
                NSCursor.arrow.set()
                return
            }
            let position = ground.worldCoordinates
            let gridX = Int(floor(position.x))
            let gridY = Int(floor(position.z))
            guard gridX >= 0, gridY >= 0, gridX < gridSize, gridY < gridSize else {
                hoverNode.isHidden = true
                lastHoverGrid = nil
                NSCursor.arrow.set()
                return
            }
            if lastHoverGrid?.x != gridX || lastHoverGrid?.y != gridY {
                hoverNode.isHidden = false
                hoverNode.position = SCNVector3(Float(gridX) + 0.5, 0.05, Float(gridY) + 0.5)
                lastHoverGrid = (gridX, gridY)
            }
            if selectedBuildId.wrappedValue != nil {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
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
            let worldDx = deltaX * worldPerPoint
            let worldDz = -deltaY * worldPerPoint
            targetLookPoint.x += worldDx
            targetLookPoint.z += worldDz
            registerInput()
            let now = CACurrentMediaTime()
            let dt = max(1.0 / 120.0, now - lastPanTick)
            lastPanTick = now
            let velocityX = Double(worldDx) / dt
            let velocityZ = Double(worldDz) / dt
            panVelocity = CGVector(dx: velocityX, dy: velocityZ)
            applyCameraConstraints(animated: false)
            if gesture.state == .ended || gesture.state == .cancelled {
                if abs(panVelocity.dx) < 0.02 && abs(panVelocity.dy) < 0.02 {
                    panVelocity = .zero
                }
                if panVelocity.dx != 0 || panVelocity.dy != 0 {
                    ensurePanTimerRunning()
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
            guard deltaX != 0 || deltaY != 0 else { return }
            let worldPerPoint = worldUnitsPerPoint()
            let lineMultiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1.0 : 12.0
            let momentumFactor: CGFloat = event.momentumPhase.isEmpty ? 1.0 : 0.7
            let scale = worldPerPoint * lineMultiplier * momentumFactor
            let worldDx = -SCNFloat(deltaX) * scale
            let worldDz = -SCNFloat(deltaY) * scale
            targetLookPoint.x += worldDx
            targetLookPoint.z += worldDz
            registerInput()
            applyCameraConstraints(animated: false)
            if event.hasPreciseScrollingDeltas {
                panVelocity = .zero
                return
            }
            let now = CACurrentMediaTime()
            let dt = max(1.0 / 120.0, now - lastPanTick)
            lastPanTick = now
            let velocityX = Double(worldDx) / dt
            let velocityZ = Double(worldDz) / dt
            let velocityFactor: Double = event.momentumPhase.isEmpty ? 0.6 : 0.3
            panVelocity = CGVector(dx: velocityX * velocityFactor, dy: velocityZ * velocityFactor)
            if panVelocity.dx != 0 || panVelocity.dy != 0 {
                ensurePanTimerRunning()
            }
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
            if vx != 0 || vy != 0 {
                ensurePanTimerRunning()
            }
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
                SCNTransaction.begin()
                SCNTransaction.disableActions = true
                cameraRig.position = targetPosition
                if animateScale {
                    camera.orthographicScale = targetScale
                }
                SCNTransaction.commit()
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

        private func ensurePanTimerRunning() {
            guard panTimer == nil else { return }
            lastEdgeTick = CACurrentMediaTime()
            panTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                guard let self else { return }
                // Scheduled on the main run loop; avoid spawning a Task every frame.
                MainActor.assumeIsolated {
                    self.stepEdgePan()
                }
            }
        }

        private func stopPanTimer() {
            panTimer?.invalidate()
            panTimer = nil
        }

        private func worldUnitsPerPoint() -> SCNFloat {
            guard let view = view, view.bounds.height > 0 else {
                return SCNFloat(cameraNode.camera?.orthographicScale ?? 1) * 0.002
            }
            let scale = SCNFloat(cameraNode.camera?.orthographicScale ?? 1)
            return scale / SCNFloat(view.bounds.height)
        }

        @MainActor
        private func stepEdgePan() {
            PerfSignposts.sceneStep {
                let now = CACurrentMediaTime()
                let dt = max(0, now - lastEdgeTick)
                lastEdgeTick = now

                if now - lastAmbientUpdate >= ambientUpdateInterval {
                    updateAmbientActors(now: now)
                    updateAmbientLighting(now: now)
                    lastAmbientUpdate = now
                }

                // Avoid fighting with direct gesture updates; resume motion shortly after input settles.
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

                let recenterEligible = (now - lastInputAt > 2.0)
                    && (selectedBuilding.wrappedValue == nil)
                    && (selectedBuildId.wrappedValue == nil)

                if !didMove, recenterEligible {
                    let center = SCNVector3(SCNFloat(gridSize) * 0.5, targetLookPoint.y, SCNFloat(gridSize) * 0.5)
                    let dx = center.x - targetLookPoint.x
                    let dz = center.z - targetLookPoint.z
                    let epsilon: SCNFloat = 0.01
                    let dist2 = dx * dx + dz * dz
                    if dist2 > epsilon * epsilon {
                        let pull = min(1.0, dt * 0.6)
                        targetLookPoint.x += dx * SCNFloat(pull)
                        targetLookPoint.z += dz * SCNFloat(pull)
                        didMove = true
                    } else if dist2 > 0 {
                        // Snap and apply once so we can stop the timer cleanly.
                        targetLookPoint.x = center.x
                        targetLookPoint.z = center.z
                        didMove = true
                    }
                }

                if didMove {
                    applyCameraConstraints(animated: false)
                }

                let stillRecentering: Bool = {
                    guard recenterEligible else { return false }
                    let center = SCNVector3(SCNFloat(gridSize) * 0.5, targetLookPoint.y, SCNFloat(gridSize) * 0.5)
                    let dx = center.x - targetLookPoint.x
                    let dz = center.z - targetLookPoint.z
                    return (dx * dx + dz * dz) > 0.0001
                }()

                if edgePanVelocity == .zero, panVelocity == .zero, !stillRecentering {
                    stopPanTimer()
                }
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
            recenterTimer?.invalidate()
            recenterTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.beginRecenterIfNeeded()
                }
            }
        }

        private func beginRecenterIfNeeded() {
            guard selectedBuilding.wrappedValue == nil,
                  selectedBuildId.wrappedValue == nil else {
                return
            }
            guard edgePanVelocity == .zero, panVelocity == .zero else { return }
            let center = SCNVector3(SCNFloat(gridSize) * 0.5, targetLookPoint.y, SCNFloat(gridSize) * 0.5)
            let dx = center.x - targetLookPoint.x
            let dz = center.z - targetLookPoint.z
            // Match the snap threshold in `stepEdgePan()`.
            guard (dx * dx + dz * dz) > 0.0001 else { return }
            ensurePanTimerRunning()
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
