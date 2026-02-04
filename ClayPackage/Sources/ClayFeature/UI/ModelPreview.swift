import SwiftUI
import SceneKit
import AppKit

struct ModelPreview: View {
    let asset: KenneyBuildingAsset
    
    var body: some View {
        SceneView(
            scene: KenneyModelCache.scene(for: asset),
            pointOfView: KenneyModelCache.camera(for: asset),
            options: [.autoenablesDefaultLighting]
        )
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 180)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
}

@MainActor
final class KenneyModelCache {
    private static var sceneCache: [KenneyBuildingAsset: SCNScene] = [:]
    private static var cameraCache: [KenneyBuildingAsset: SCNNode] = [:]
    private static var nodeCache: [KenneyBuildingAsset: SCNNode] = [:]
    private static var extentCache: [KenneyBuildingAsset: Float] = [:]
    
    static func modelNode(for asset: KenneyBuildingAsset) -> SCNNode? {
        if let cached = nodeCache[asset] {
            return cached
        }
        guard let url = KenneyAssetCatalog.shared.url(for: asset.model3d),
              let modelScene = try? SCNScene(url: url, options: nil) else {
            return nil
        }
        let container = SCNNode()
        modelScene.rootNode.childNodes.forEach { container.addChildNode($0) }
        let (minVec, maxVec) = container.boundingBox
        let rawExtent = max(maxVec.x - minVec.x, max(maxVec.y - minVec.y, maxVec.z - minVec.z))
        let scaledExtent = max(0.1, Float(rawExtent) * asset.scale)
        extentCache[asset] = scaledExtent
        let bottomCenter = SCNVector3((minVec.x + maxVec.x) / 2, minVec.y, (minVec.z + maxVec.z) / 2)
        container.pivot = SCNMatrix4MakeTranslation(bottomCenter.x, bottomCenter.y, bottomCenter.z)
        container.scale = SCNVector3(asset.scale, asset.scale, asset.scale)
        let rotationRadians = asset.rotation * (.pi / 180)
        container.eulerAngles = SCNVector3(0, rotationRadians, 0)
        nodeCache[asset] = container
        return container
    }

    static func extent(for asset: KenneyBuildingAsset) -> Float {
        if let cached = extentCache[asset] {
            return cached
        }
        _ = modelNode(for: asset)
        return extentCache[asset] ?? 1.0
    }
    
    static func scene(for asset: KenneyBuildingAsset) -> SCNScene {
        if let cached = sceneCache[asset] {
            return cached
        }
        let scene = SCNScene()
        scene.background.contents = NSColor(calibratedWhite: 0.08, alpha: 1.0)
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.08, alpha: 1.0)
        floor.firstMaterial?.isDoubleSided = true
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.5, 0)
        scene.rootNode.addChildNode(floorNode)
        if let modelNode = modelNode(for: asset) {
            let copy = modelNode.clone()
            copy.position = SCNVector3(0, asset.yOffset, 0)
            scene.rootNode.addChildNode(copy)
        }
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 350
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)
        let omni = SCNLight()
        omni.type = .omni
        omni.intensity = 800
        let omniNode = SCNNode()
        omniNode.light = omni
        omniNode.position = SCNVector3(2, 6, 4)
        scene.rootNode.addChildNode(omniNode)
        let camera = camera(for: asset, attachTo: scene)
        cameraCache[asset] = camera
        sceneCache[asset] = scene
        return scene
    }
    
    static func camera(for asset: KenneyBuildingAsset) -> SCNNode {
        if let cached = cameraCache[asset] {
            return cached
        }
        let node = buildCamera(for: asset)
        cameraCache[asset] = node
        return node
    }
    
    private static func camera(for asset: KenneyBuildingAsset, attachTo scene: SCNScene) -> SCNNode {
        let node = buildCamera(for: asset)
        scene.rootNode.addChildNode(node)
        return node
    }
    
    private static func buildCamera(for asset: KenneyBuildingAsset) -> SCNNode {
        let extentValue = max(0.4, extent(for: asset))
        let distance = max(2.5, extentValue * 2.2)
        let height = max(0.9, extentValue * 1.0)
        let targetY = asset.yOffset + max(0.4, extentValue * 0.45)
        let camera = SCNCamera()
        camera.fieldOfView = 38
        let node = SCNNode()
        node.camera = camera
        node.position = SCNVector3(0, height, distance)
        node.look(at: SCNVector3(0, targetY, 0))
        return node
    }
}
