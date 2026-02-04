import SceneKit
import AppKit

@MainActor
protocol RenderBackend {
    func makeBuildingNode(asset: KenneyBuildingAsset, id: UUID, position: SCNVector3) -> SCNNode
    func makeOverlayNode(size: CGFloat, color: NSColor, position: SCNVector3) -> SCNNode
    func makeAmbientNode(asset: KenneyBuildingAsset, id: String, position: SCNVector3) -> SCNNode
}

@MainActor
struct SceneKitBackend: RenderBackend {
    func makeBuildingNode(asset: KenneyBuildingAsset, id: UUID, position: SCNVector3) -> SCNNode {
        guard let template = KenneyModelCache.modelNode(for: asset) else { return SCNNode() }
        let node = template.clone()
        node.position = position
        node.name = "building:\(id.uuidString)"
        node.categoryBitMask = 2
        node.enumerateChildNodes { child, _ in
            child.categoryBitMask = 2
        }
        return node
    }
    
    func makeOverlayNode(size: CGFloat, color: NSColor, position: SCNVector3) -> SCNNode {
        let plane = SCNPlane(width: size, height: size)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.isDoubleSided = true
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.position = position
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.categoryBitMask = 4
        return node
    }
    
    func makeAmbientNode(asset: KenneyBuildingAsset, id: String, position: SCNVector3) -> SCNNode {
        guard let template = KenneyModelCache.modelNode(for: asset) else { return SCNNode() }
        let node = template.clone()
        node.position = position
        node.name = "ambient:\(id)"
        node.categoryBitMask = 8
        return node
    }
}
