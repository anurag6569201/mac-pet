import SceneKit
import SwiftUI

class PetController {
    static let shared = PetController()
    
    let scene: SCNScene
    let characterNode: SCNNode
    // cameraNode is removed as we now create per-view cameras
    
    // Animations
    private var walkingAnimation: WalkingAnimation?
    private var fastRunAnimation: FastRunAnimation?
    private var slowRunAnimation: SlowRunAnimation?
    private var lookAroundAnimation: LookAroundAnimation?
    private var idleBreathingAnimation: IdleBreathingAnimation?
    private var armStretchAnimation: ArmStretchAnimation?
    private var neckStretchAnimation: NeckStretchAnimation?
    private var yawnAnimation: YawnAnimation?
    
    private var startSequenceHasRun = false
    private var lastUpdateTime: TimeInterval = 0
    private var isWalking = false
    private var isRunning = false
    private var isSlowRunning = false
    
    // Idle Animation State
    private var lastActivityTime: TimeInterval = 0
    private var isIdleBreathing = false
    private var isLookingAround = false
    private var isPerformingLongIdle = false // For stretch/yawn animations
    private var nextLookAroundTime: TimeInterval = 0
    private var nextScratchCheckTime: TimeInterval = 0
    private var longIdleTriggered = false
    
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
            // PRIORITY 1: MOVEMENT ANIMATIONS - Always override idle animations
            // Forcefully stop ALL idle animations immediately
            stopAllIdleAnimations()
            
            // Reset idle timers
            lastActivityTime = time
            longIdleTriggered = false
            
            let distance = abs(dx)
            
            if distance > 500 {
                // FAST RUN
                if isWalking { walkingAnimation?.stop(); isWalking = false }
                if isSlowRunning { slowRunAnimation?.stop(); isSlowRunning = false }
                
                if !isRunning {
                    fastRunAnimation?.start()
                    isRunning = true
                }
            } else if distance > 200 {
                // SLOW RUN
                if isWalking { walkingAnimation?.stop(); isWalking = false }
                if isRunning { fastRunAnimation?.stop(); isRunning = false }
                
                if !isSlowRunning {
                    slowRunAnimation?.start()
                    isSlowRunning = true
                }
            } else {
                // WALK
                if isRunning { fastRunAnimation?.stop(); isRunning = false }
                if isSlowRunning { slowRunAnimation?.stop(); isSlowRunning = false }
                
                if !isWalking {
                    walkingAnimation?.start()
                    isWalking = true
                }
            }
            
            // Face direction
            characterNode.eulerAngles.y = dx > 0 ? .pi / 2 : -.pi / 2
            
            // Determine speed
            let moveSpeed: CGFloat
            if distance > 500 {
                moveSpeed = PetConfig.runSpeed
            } else if distance > 200 {
                moveSpeed = PetConfig.slowRunSpeed
            } else {
                moveSpeed = PetConfig.walkSpeed
            }
            
            let moveDistance = moveSpeed * CGFloat(deltaTime)
            
            if moveDistance < abs(dx) {
                characterNode.position.x += moveDistance * (dx > 0 ? 1 : -1)
            } else {
                // Arrived
                characterNode.position.x = targetX
            }
            
            // Clamp to world bounds
            if worldSize.width > 0 {
                characterNode.position.x = max(0, min(characterNode.position.x, worldSize.width))
            }
        } else {
            // PRIORITY 2: IDLE ANIMATIONS - Only play when not moving
            // First, ensure all movement animations are stopped
            if isWalking { walkingAnimation?.stop(); isWalking = false }
            if isRunning { fastRunAnimation?.stop(); isRunning = false }
            if isSlowRunning { slowRunAnimation?.stop(); isSlowRunning = false }
            
            // Double-check: If any movement animation is still active, don't play idle animations
            if isWalking || isRunning || isSlowRunning {
                return
            }
            
            let idleTime = time - lastActivityTime
            
            // Start idle breathing if not already playing and no other idle animation is active
            if !isIdleBreathing && !isLookingAround && !isPerformingLongIdle {
                isIdleBreathing = true
                idleBreathingAnimation?.start()
            }
            
            // Initialize next look-around time if needed
            if nextLookAroundTime == 0 {
                nextLookAroundTime = time + Double.random(in: PetConfig.lookAroundMinInterval...PetConfig.lookAroundMaxInterval)
            }
            
            // Initialize next scratch check time if needed
            if nextScratchCheckTime == 0 {
                nextScratchCheckTime = time + PetConfig.scratchCheckInterval
            }
            
            // Check for long idle animations (stretch/yawn) - highest priority
            if idleTime >= PetConfig.longIdleTimeout && !longIdleTriggered && !isPerformingLongIdle {
                longIdleTriggered = true
                isPerformingLongIdle = true
                
                // Stop other idle animations
                if isIdleBreathing {
                    idleBreathingAnimation?.stop()
                    isIdleBreathing = false
                }
                if isLookingAround {
                    lookAroundAnimation?.stop()
                    isLookingAround = false
                }
                
                // Randomly select stretch or yawn animation
                let randomChoice = Int.random(in: 0...2)
                
                // Smoothly rotate to face forward
                let rotateAction = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: PetConfig.rotationTransitionDuration)
                rotateAction.timingMode = .easeInEaseOut
                
                characterNode.runAction(rotateAction) { [weak self] in
                    guard let self = self else { return }
                    
                    switch randomChoice {
                    case 0:
                        self.armStretchAnimation?.start()
                    case 1:
                        self.neckStretchAnimation?.start()
                    default:
                        self.yawnAnimation?.start()
                    }
                    
                    // Return to idle breathing after animation completes (estimate 3 seconds)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.isPerformingLongIdle = false
                        // Only restart idle breathing if character is actually still idle (not moving)
                        if !self.isIdleBreathing && !self.isLookingAround && !self.isWalking && !self.isRunning && !self.isSlowRunning {
                            self.isIdleBreathing = true
                            self.idleBreathingAnimation?.start()
                        }
                    }
                }
            }
            // Check for random scratch animation
            else if time >= nextScratchCheckTime && !isPerformingLongIdle && !isLookingAround {
                nextScratchCheckTime = time + PetConfig.scratchCheckInterval
                
                if Double.random(in: 0...1) < PetConfig.scratchChance {
                    isPerformingLongIdle = true
                    
                    // Stop idle breathing
                    if isIdleBreathing {
                        idleBreathingAnimation?.stop()
                        isIdleBreathing = false
                    }
                    
                    // Randomly select arm or neck stretch for scratch
                    let scratchChoice = Bool.random()
                    
                    // Smoothly rotate to face forward
                    let rotateAction = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: PetConfig.rotationTransitionDuration)
                    rotateAction.timingMode = .easeInEaseOut
                    
                    characterNode.runAction(rotateAction) { [weak self] in
                        guard let self = self else { return }
                        
                        if scratchChoice {
                            self.armStretchAnimation?.start()
                        } else {
                            self.neckStretchAnimation?.start()
                        }
                        
                        // Return to idle breathing after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.isPerformingLongIdle = false
                            // Only restart idle breathing if character is actually still idle (not moving)
                            if !self.isIdleBreathing && !self.isLookingAround && !self.isWalking && !self.isRunning && !self.isSlowRunning {
                                self.isIdleBreathing = true
                                self.idleBreathingAnimation?.start()
                            }
                        }
                    }
                }
            }
            // Check for look-around animation
            else if time >= nextLookAroundTime && !isLookingAround && !isPerformingLongIdle {
                isLookingAround = true
                
                // Stop idle breathing
                if isIdleBreathing {
                    idleBreathingAnimation?.stop()
                    isIdleBreathing = false
                }
                
                // Smoothly rotate to face forward
                let rotateAction = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: PetConfig.rotationTransitionDuration)
                rotateAction.timingMode = .easeInEaseOut
                
                characterNode.runAction(rotateAction) { [weak self] in
                    guard let self = self else { return }
                    self.lookAroundAnimation?.start()
                    
                    // Return to idle breathing after look-around completes (estimate 2 seconds)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.lookAroundAnimation?.stop()
                        self.isLookingAround = false
                        
                        // Only restart idle breathing if character is actually still idle (not moving)
                        if !self.isIdleBreathing && !self.isPerformingLongIdle && !self.isWalking && !self.isRunning && !self.isSlowRunning {
                            self.isIdleBreathing = true
                            self.idleBreathingAnimation?.start()
                        }
                        
                        // Schedule next look-around
                        self.nextLookAroundTime = time + Double.random(in: PetConfig.lookAroundMinInterval...PetConfig.lookAroundMaxInterval)
                    }
                }
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
        fastRunAnimation = FastRunAnimation.setup(for: characterNode)
        slowRunAnimation = SlowRunAnimation.setup(for: characterNode)
        lookAroundAnimation = LookAroundAnimation.setup(for: characterNode)
        idleBreathingAnimation = IdleBreathingAnimation.setup(for: characterNode)
        armStretchAnimation = ArmStretchAnimation.setup(for: characterNode)
        neckStretchAnimation = NeckStretchAnimation.setup(for: characterNode)
        yawnAnimation = YawnAnimation.setup(for: characterNode)
    }
    
    private func startSequence(size: CGSize) {
        // This function is currently disabled and not used
        // Mouse following logic is used instead
    }
    
    // MARK: - Helper Methods
    
    /// Forcefully stops all idle animations immediately
    private func stopAllIdleAnimations() {
        // Cancel any pending rotation actions from idle animations
        characterNode.removeAllActions()
        
        // Stop all idle animation players immediately (no blend)
        if isIdleBreathing {
            idleBreathingAnimation?.idleBreathingPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
            isIdleBreathing = false
        }
        if isLookingAround {
            lookAroundAnimation?.lookAroundPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
            isLookingAround = false
        }
        if isPerformingLongIdle {
            armStretchAnimation?.armStretchPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
            neckStretchAnimation?.neckStretchPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
            yawnAnimation?.yawnPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
            isPerformingLongIdle = false
        }
    }
    
    func updateSpotlightPosition(width: CGFloat, height: CGFloat) {
        // Optional: Update spotlight to center of the total view if needed
        if let spotNode = scene.rootNode.childNodes.first(where: { $0.light?.type == .spot }) {
             spotNode.position = SCNVector3(width / 2, height + 200, 200)
             spotNode.look(at: SCNVector3(width / 2, 0, 0))
        }
    }
}
