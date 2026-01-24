import SceneKit
import SwiftUI

class PetController {
    static let shared = PetController()
    
    let scene: SCNScene
    let characterNode: SCNNode
    // cameraNode is removed as we now create per-view cameras
    
    // Animations
    private var walkingAnimation: WalkingAnimation?
    private var landingAnimation: LandingAnimation?
    private var doorAnimation: DoorAnimation?
    
    private var isConfigured = false
    
    private init() {
        // Initialize Scene and Nodes
        scene = SCNScene(named: PetConfig.characterModel) ?? SCNScene()
        characterNode = SCNNode()
        
        setupSceneContent()
    }
    
    func configure(with size: CGSize) {
        guard !isConfigured else { return }
        isConfigured = true
        
        // Setup shared logic (animations, etc)
        // Note: Camera is now set up per-view
        setupAnimations()
        startSequence(size: size)
    }
    
    private func setupSceneContent() {
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
            // Cast shadows
            node.castsShadow = true
        }
        
        // Move all children to characterNode
        let children = scene.rootNode.childNodes
        for child in children {
            characterNode.addChildNode(child)
        }
        scene.rootNode.addChildNode(characterNode)

        // --- Custom Lighting Setup ---
        
        // 1. Ambient Light (Soft fill)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 300
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // 2. Spotlight (Key light + Shadows)
        let spotLight = SCNLight()
        spotLight.type = .spot
        spotLight.intensity = 1000
        spotLight.castsShadow = true
        spotLight.shadowColor = NSColor.black.withAlphaComponent(0.5)
        spotLight.shadowRadius = 10.0
        spotLight.spotInnerAngle = 0
        spotLight.spotOuterAngle = 60
        
        let spotLightNode = SCNNode()
        spotLightNode.light = spotLight
        // Position high up and to the side/front
        spotLightNode.position = SCNVector3(1000, 2000, 500) // Generic high position
        spotLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(spotLightNode)
        
        // --- Floor Setup ---
        // --- Floor Setup ---
        // Replaced SCNFloor with SCNPlane to avoid "Pass FloorPass is not linked to the rendering graph" error
        // Using SCNPlane + Lambert material is much lighter than SCNFloor
        let floorGeometry = SCNPlane(width: 50000, height: 50000)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = NSColor.white.withAlphaComponent(0.2)
        floorMaterial.isDoubleSided = true
        floorMaterial.lightingModel = .lambert
        floorMaterial.specular.contents = NSColor.black // No specular reflection
        floorGeometry.materials = [floorMaterial]
        
        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.eulerAngles.x = -.pi / 2
        floorNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(floorNode)
    }

    // Factory method for per-desktop cameras
    func makeCameraNode(for desktopIndex: Int, screenSize: CGSize) -> SCNNode {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(screenSize.height / 2)
        camera.zNear = 1
        camera.zFar = 1000

        let node = SCNNode()
        node.camera = camera
        
        // Calculate position based on desktop index
        // The shared world starts at x=0 (Desktop 1 left edge) and extends right.
        // Desktop 1 (Index 0): Center is width/2
        // Desktop 2 (Index 1): Center is width * 1.5
        // ...
        // Formula: (screenSize.width * index) + (screenSize.width / 2)
        
        let screenWidth = screenSize.width
        let centerX = (screenWidth * CGFloat(desktopIndex)) + (screenWidth / 2)
        
        node.position = SCNVector3(centerX, screenSize.height / 2, 100)
        
        // We do NOT add this node to the shared scene rootNode generally, 
        // because we might get clutter if windows are recreated.
        // However, a node MUST be in the scene graph to be used as pointOfView effectively?
        // Actually, it doesn't strictly have to be if we handle it carefully, but standard practice is yes.
        // Let's add it to the scene but keep a reference managed by the caller, or just add it here.
        // Since `makeCameraNode` implies creating a new one, let's just return it. 
        // The caller (CharacterView) will add it to the scene (or its own root, but pointOfView needs to be in scene).
        // Wait, if we add it to `scene.rootNode`, all other views will "see" the camera object floating there (invisible but exists).
        // That's fine.
        scene.rootNode.addChildNode(node)
        
        return node
    }
    
    private func setupAnimations() {
        walkingAnimation = WalkingAnimation.setup(for: characterNode)
        if let walking = walkingAnimation {
            landingAnimation = LandingAnimation.setup(for: characterNode, walkingAnimation: walking)
        }
        doorAnimation = DoorAnimation.setup(for: characterNode)
    }
    
    private func startSequence(size: CGSize) {
        guard let landingAnimation = landingAnimation,
              let walkingAnimation = walkingAnimation,
              let doorAnimation = doorAnimation else { return }

        // Starting values from Config
        // Starting values from Config
        // Force visible start position for testing (Screen 1)
        let startPos = SCNVector3(300, 200, 0) // Start above screen 1
        let groundPos = SCNVector3(300, 0, 0)  // Land on screen 1 is better for testing
        let finalPos = PetConfig.finalPos(for: size)
        let speed = PetConfig.walkSpeed


        // Run Landing -> Walking sequence
        landingAnimation.run(startPos: startPos, groundPos: groundPos, finalPos: finalPos, walkSpeed: speed) {
            // Patrol/Explore: After landing and walking to finalPos, walk back to a middle point
            let patrolPos = SCNVector3(size.width / 2, 0, 0)
            walkingAnimation.run(from: finalPos, to: patrolPos, speed: speed) {
                print("Patrol complete!")
                doorAnimation.run {
                    print("Door animation complete!")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func updateSpotlightPosition(width: CGFloat, height: CGFloat) {
        // Optional: Update spotlight to center of the total view if needed
        if let spotNode = scene.rootNode.childNodes.first(where: { $0.light?.type == .spot }) {
             spotNode.position = SCNVector3(width / 2, height + 200, 200)
             spotNode.look(at: SCNVector3(width / 2, 0, 0))
        }
    }
}
