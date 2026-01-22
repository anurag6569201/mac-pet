import SwiftUI
import SceneKit

struct CharacterView: NSViewRepresentable {
    let size: CGSize

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear

        // Load .dae correctly in SceneKit
        let scene = SCNScene(named: PetConfig.characterModel) ?? SCNScene()

        // Create a root node for the character to make positioning easier
        let characterNode = SCNNode()
        
        // Force texture binding and add to characterNode
        scene.rootNode.enumerateChildNodes { node, _ in
            if let material = node.geometry?.firstMaterial {
                if let image = NSImage(named: PetConfig.diffuseTexture) ?? NSImage(contentsOfFile: Bundle.main.path(forResource: PetConfig.diffuseTexture.replacingOccurrences(of: ".png", with: ""), ofType: "png", inDirectory: PetConfig.assetsDirectory) ?? "") {
                    material.diffuse.contents = image
                }
                material.isDoubleSided = true
                material.lightingModel = .physicallyBased
            }
            // Scale
            node.scale = PetConfig.characterScale
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

        // Initialize Animations
        let walkingAnimation = WalkingAnimation.setup(for: characterNode)
        let landingAnimation = LandingAnimation.setup(for: characterNode, walkingAnimation: walkingAnimation)
        let doorAnimation = DoorAnimation.setup(for: characterNode)

        // Starting values from Config
        let startPos = PetConfig.startPos(for: size)
        let groundPos = PetConfig.groundPos(for: size)
        let finalPos = PetConfig.finalPos(for: size)
        let speed = PetConfig.walkSpeed

        // Run Landing -> Walking sequence
        landingAnimation.run(startPos: startPos, groundPos: groundPos, finalPos: finalPos, walkSpeed: speed) {
            // Patrol/Explore: After landing and walking to finalPos, walk back to a middle point
            let patrolPos = SCNVector3(size.width / 2, 50, 0)
            walkingAnimation.run(from: finalPos, to: patrolPos, speed: speed) {
                print("Patrol complete!")
                doorAnimation.run {
                    print("Door animation complete!")
                }
            }
        }

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
