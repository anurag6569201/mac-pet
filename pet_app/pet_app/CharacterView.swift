import SwiftUI
import SceneKit

struct CharacterView: NSViewRepresentable {
    let size: CGSize

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear

        // Load .dae correctly in SceneKit
        let scene = SCNScene(named: "Assets.scnassets/character.dae") ?? SCNScene()

        // Create a root node for the character to make positioning easier
        let characterNode = SCNNode()
        
        // Force texture binding and add to characterNode
        scene.rootNode.enumerateChildNodes { node, _ in
            if let material = node.geometry?.firstMaterial {
                if let image = NSImage(named: "diffuse.png") ?? NSImage(contentsOfFile: Bundle.main.path(forResource: "diffuse", ofType: "png", inDirectory: "Assets.scnassets") ?? "") {
                    material.diffuse.contents = image
                }
                material.isDoubleSided = true
                material.lightingModel = .physicallyBased
            }
            // Scale
            node.scale = SCNVector3(0.8, 0.8, 0.8)
        }
        
        // Move all children to characterNode
        let children = scene.rootNode.childNodes
        for child in children {
            characterNode.addChildNode(child)
        }
        scene.rootNode.addChildNode(characterNode)

        // Setup Camera for Screen Mapping
        // We want (0,0) at bottom-left and (width, height) at top-right
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(size.height / 2)
        camera.zNear = 1
        camera.zFar = 1000

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        // Position camera in the center of the screen area, looking at Z=0
        cameraNode.position = SCNVector3(size.width / 2, size.height / 2, 100)
        scene.rootNode.addChildNode(cameraNode)
        
        view.pointOfView = cameraNode

        // Position character: example - starting from right
        characterNode.position = SCNVector3(size.width, 50, 0)
        
        // Rotate character to face left (sideway walk)
        // Since the character likely faces forward by default (Z+), rotating -90 degrees (or 270) around Y makes it face X- (left)
        characterNode.eulerAngles.y = -.pi / 2

        // Load and Apply Animation from normal-walking.dae - Node Matching
        if let animationScene = SCNScene(named: "Assets.scnassets/normal-walking.dae") {
            // Function to recursively add animations matching node names
            func addAnimations(from sourceNode: SCNNode, to targetRoot: SCNNode) {
                for key in sourceNode.animationKeys {
                    if let player = sourceNode.animationPlayer(forKey: key) {
                        // Find corresponding node in character hierarchy
                        let targetNode = targetRoot.childNode(withName: sourceNode.name ?? "", recursively: true) ?? targetRoot
                        
                        // Create a new player to avoid referencing the old scene
                        let newPlayer = SCNAnimationPlayer(animation: player.animation)
                        newPlayer.animation.repeatCount = .infinity
                        newPlayer.animation.isRemovedOnCompletion = false
                        newPlayer.play()
                        
                        targetNode.addAnimationPlayer(newPlayer, forKey: key)
                    }
                }
                
                for child in sourceNode.childNodes {
                    addAnimations(from: child, to: targetRoot)
                }
            }
            
            addAnimations(from: animationScene.rootNode, to: characterNode)
        }
        
        // Add movement logic: walk from right to left
        let moveLeft = SCNAction.move(to: SCNVector3(-100, 50, 0), duration: 8.63)
        let resetPos = SCNAction.move(to: SCNVector3(size.width + 100, 50, 0), duration: 0)
        let sequence = SCNAction.sequence([moveLeft, resetPos])
        characterNode.runAction(SCNAction.repeatForever(sequence))

        view.scene = scene
        view.autoenablesDefaultLighting = true
        view.isPlaying = true
        
        // Connect Delegate
        view.delegate = context.coordinator
        
        return view
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
            // Find the Hips/Root node and lock it to prevent root motion
            if let scene = renderer.scene {
                let root = scene.rootNode
                
                // Search for common root identifiers
                let keywords = ["mixamorig:Hips", "Hips", "Root", "Pelvis", "Armature"]
                
                func lockNode(_ node: SCNNode) {
                    if let name = node.name, keywords.contains(where: { name.contains($0) }) {
                        node.position.x = 0
                        node.position.z = 0
                    }
                    for child in node.childNodes {
                        lockNode(child)
                    }
                }
                
                // Only traverse the first few levels to avoid performance hit
                // or just hit the main skeleton
                for child in root.childNodes {
                    lockNode(child)
                }
            }
        }
    }

    func updateNSView(_ nsView: SCNView, context: Context) {}
}
