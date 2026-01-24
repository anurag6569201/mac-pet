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
    
    private var startSequenceHasRun = false
    private var lastUpdateTime: TimeInterval = 0
    private var isWalking = false
    
    private var isConfigured = false
    
    // Centralized Active Desktop State
    var activeDesktopIndex: Int = 0
    
    // Cache of visible spaces per display: [DisplayID (1-based) : SpaceIndex (0-based)]
    var visibleSpacesByDisplay: [Int: Int] = [:]
    
    private init() {
        // Initialize Scene and Nodes
        scene = SCNScene(named: PetConfig.characterModel) ?? SCNScene()
        characterNode = SCNNode()
        
        setupSceneContent()
        
        // Start periodic refresh of space data
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshVisibleSpaces()
        }
        
        // Initial fetch
        refreshVisibleSpaces()
    }
    
    func refreshVisibleSpaces() {
        DispatchQueue.global(qos: .background).async {
            let map = YabaiAutomation.shared.getVisibleSpacesMap()
            DispatchQueue.main.async {
                self.visibleSpacesByDisplay = map
                // print(" [PetController] Updated Visible Spaces: \(map)")
            }
        }
    }
    
    private var worldSize: CGSize = .zero

    func configure(with size: CGSize) {
        guard !isConfigured else { return }
        isConfigured = true
        self.worldSize = size
        
        print(" [PetController] Configured with World Size: \(size)")
        
        // Setup shared logic (animations, etc)
        // Note: Camera is now set up per-view
        setupAnimations()
        
        // Initial Position
        characterNode.position = PetConfig.groundPos(for: size)
        
        // startSequence(size: size) // Disabled for mouse following
    }
    
    func update(atTime time: TimeInterval, screenSize: CGSize) {
        if lastUpdateTime == 0 {
            lastUpdateTime = time
            return
        }
        let deltaTime = time - lastUpdateTime
        lastUpdateTime = time
        
        // Mouse Following Logic
        let mouseLoc = NSEvent.mouseLocation
        
        // Update visible spaces map periodically (e.g. every second or on-demand?)
        // Ideally YabaiAutomation calls us when space changes, but for now we lazily update?
        // Or better: Assume `visibleSpaceByDisplay` is updated by AppDelegate -> PetController
        // Let's self-update if empty or stale? For minimal lag, let's just query if missing.
        // But query is slow. Let's rely on cached map updated by Yabai signals.
        // For now, let's triggers a background refresh if needed.
        
        // Find which screen the mouse is currently on
        // NSEvent.mouseLocation is in global screen coordinates
        var localX: CGFloat = 0
        var targetSpaceIndex: Int = activeDesktopIndex // Default fallback
        
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) {
            // Calculate X relative to that screen's origin
            localX = mouseLoc.x - screen.frame.minX
            
            // infer display index from screen list order (Main is 0 -> Display 1)
            if let screenIndex = NSScreen.screens.firstIndex(of: screen) {
                // Determine Display ID (Screen Index + 1 matches Yabai usually)
                let displayID = screenIndex + 1
                
                // Lookup visible space for this display
                if let visibleSpace = visibleSpacesByDisplay[displayID] {
                    targetSpaceIndex = visibleSpace
                }
            }
        } else {
            // Fallback if off-screen (shouldn't happen often)
            localX = mouseLoc.x.truncatingRemainder(dividingBy: screenSize.width)
        }
        
        // Target is: (Target Space Offset) + (Mouse Position on that Desktop)
        // Note: We assume all desktops have the same width for simplicity in this grid model
        let screenWidth = screenSize.width
        let worldOffsetX = CGFloat(targetSpaceIndex) * screenWidth
        
        let targetX = worldOffsetX + localX
        
        let currentX = characterNode.position.x
        let dx = targetX - currentX
        
        let threshold: CGFloat = 5.0
        let teleportThreshold: CGFloat = 1000.0 // Teleport if > 1000 units away (approx < 1 screen width but instant feel)
        
        if abs(dx) > threshold {
            // Standard Walking Logic
            if !isWalking {
                walkingAnimation?.start()
                isWalking = true
            }
            
            // Face direction
            characterNode.eulerAngles.y = dx > 0 ? .pi / 2 : -.pi / 2
            
            let distance = PetConfig.walkSpeed * CGFloat(deltaTime)
            if distance < abs(dx) {
                characterNode.position.x += distance * (dx > 0 ? 1 : -1)
            } else {
                characterNode.position.x = targetX
            }
            
            // Clamp to world bounds
            if worldSize.width > 0 {
                characterNode.position.x = max(0, min(characterNode.position.x, worldSize.width))
            }
        } else {
            if isWalking {
                walkingAnimation?.stop()
                isWalking = false
            }
        }
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
