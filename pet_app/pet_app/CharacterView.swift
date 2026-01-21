import SwiftUI
import SceneKit

struct CharacterView: NSViewRepresentable {

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear

        // Load .dae correctly in SceneKit
        // ✅ Always include Assets.scnassets/
        let scene = SCNScene(named: "Assets.scnassets/character.dae")

        // Force texture binding (fixes black / white model)
        scene?.rootNode.enumerateChildNodes { node, _ in
            if let material = node.geometry?.firstMaterial {
                // Try loading from Assets.scnassets/ if normal named loading fails
                if let image = NSImage(named: "diffuse.png") ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "diffuse", ofType: "png", inDirectory: "Assets.scnassets") ?? "") {
                    material.diffuse.contents = image
                }
                material.isDoubleSided = true
                material.lightingModel = .physicallyBased
            }
            // Scale and adjustment
            // node.scale = SCNVector3(0.6, 0.6, 0.6)
        }

        view.scene = scene
        view.autoenablesDefaultLighting = true
        view.isPlaying = true
        view.allowsCameraControl = true // Temporarily enable for debugging visibility
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {}
}
