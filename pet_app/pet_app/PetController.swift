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
    private var jumpOverAnimation: JumpOverAnimation?
    
    // Mouse Behavior Animations (PRIORITY 2)
    private var angryEmotionAnimation: AngryEmotionAnimation?
    private var doubleHandWaveAnimation: DoubleHandWaveAnimation?
    private var oneHandWaveAnimation: OneHandWaveAnimation?
    private var pointingGestureAnimation: PointingGestureAnimation?
    private var surpriseAnimation: SurpriseAnimation?
    
    private var startSequenceHasRun = false
    private var lastUpdateTime: TimeInterval = 0
    private var isWalking = false
    private var isRunning = false
    private var isSlowRunning = false
    private var isJumping = false
    
    // Idle Animation State
    private var lastActivityTime: TimeInterval = 0
    private var isIdleBreathing = false
    private var isLookingAround = false
    private var isPerformingLongIdle = false // For stretch/yawn animations
    private var nextLookAroundTime: TimeInterval = 0
    private var nextScratchCheckTime: TimeInterval = 0
    
    // Mouse Behavior State (PRIORITY 2)
    private var isPerformingMouseBehavior = false
    private var mousePositionHistory: [(position: CGPoint, time: TimeInterval)] = []
    private var lastMouseClickTime: TimeInterval = 0
    private var mouseHoverStartTime: TimeInterval? = nil
    private var lastMouseBehaviorTimes: [String: TimeInterval] = [:] // Cooldown tracking
    private var longIdleTriggered = false
    
    // Jump State
    private var activeJumpBoundaryX: CGFloat?
    
    private var isConfigured = false
        
    // Centralized Active Desktop State
    var activeDesktopIndex: Int = 0

    // Cache of visible spaces per display: [DisplayID (1-based) : SpaceIndex (0-based)]
    var visibleSpacesByDisplay: [Int: Int] = [:]
    
    // Chat Bubble
    private var chatBubble: ChatBubble?
    
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
    private var currentScreenSize: CGSize = .zero

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
        // Store current screen size for use in chat bubble positioning
        currentScreenSize = screenSize
        if lastUpdateTime == 0 {
            lastUpdateTime = time
            return
        }
        let deltaTime = time - lastUpdateTime
        lastUpdateTime = time
        
        // Apply current scale with clamping
        let rawScale = max(0.05, PetConfig.characterScale.x)
        characterNode.scale = SCNVector3(rawScale, rawScale, rawScale)
        
        let scaleFactor = CGFloat(rawScale)
        let physicsScale = sqrt(scaleFactor) // Froude scaling for dynamics
        
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
        
        // Update mouse position history for velocity tracking (PRIORITY 2 system)
        updateMouseHistory(position: CGPoint(x: targetX, y: mouseLoc.y), time: time)
        
        let currentX = characterNode.position.x
        let dx = targetX - currentX
        
        let threshold: CGFloat = PetConfig.mouseDeadZoneRadius * scaleFactor
        let teleportThreshold: CGFloat = 1000.0 * scaleFactor // Teleport if > 1000 units away (approx < 1 screen width but instant feel)
        
        // Normalize distance for logic checks
        let effectiveDistance = abs(dx) / scaleFactor
        
        if abs(dx) > threshold {
            // PRIORITY 1: MOVEMENT ANIMATIONS - Always override idle animations
            // Forcefully stop ALL idle animations and mouse behaviors immediately
            stopAllIdleAnimations()
            stopAllMouseBehaviors()
            
            // Check for space transition
            let currentSpaceIndex = Int(characterNode.position.x / screenWidth)
            let targetSpaceIndexCalc = Int(targetX / screenWidth)
            let isSpaceTransition = currentSpaceIndex != targetSpaceIndexCalc
            
            // Reset idle timers
            lastActivityTime = time
            longIdleTriggered = false
            
            let distance = abs(dx)
            
            // Jump Logic: 
            // 1. If already jumping, check if we finished the jump (moved past boundary + prepare dist)
            // 2. If not jumping, but transitioning space, check if close enough to start jump
            
            var shouldBeJumping = false
            
            if isJumping, let boundaryX = activeJumpBoundaryX {
                let distToBoundary = abs(characterNode.position.x - boundaryX)
                // Continue jumping if we are within range OR if we haven't crossed yet (handled by direction check implicitly via distance)
                // Actually, simple check: are we still within the "jump zone"?
                // Jump zone is [boundaryX - prepareDist, boundaryX + prepareDist]
                // But we mainly care about target side.
                
                if distToBoundary < PetConfig.jumpPrepareDistance + 50 { // Add buffer to ensure we land cleanly
                     shouldBeJumping = true
                } else {
                     // We landed
                     shouldBeJumping = false
                     activeJumpBoundaryX = nil
                }
            } else if isSpaceTransition {
                // Determine direction of movement for boundary
                let boundaryX: CGFloat
                if dx > 0 {
                    boundaryX = CGFloat(currentSpaceIndex + 1) * screenWidth
                } else {
                    boundaryX = CGFloat(currentSpaceIndex) * screenWidth
                }
                
                let distToBoundary = abs(boundaryX - currentX)
                
                // Only jump if we are close to the edge
                if distToBoundary < PetConfig.jumpPrepareDistance {
                    shouldBeJumping = true
                    activeJumpBoundaryX = boundaryX
                }
            }
            
            if shouldBeJumping {
                // JUMP OVER
                if isWalking { walkingAnimation?.stop(); isWalking = false }
                if isSlowRunning { slowRunAnimation?.stop(); isSlowRunning = false }
                if isRunning { fastRunAnimation?.stop(); isRunning = false }
                
                if !isJumping {
                    jumpOverAnimation?.start()
                    isJumping = true
                }
            } else if effectiveDistance > 500 {
                // FAST RUN
                if isWalking { walkingAnimation?.stop(); isWalking = false }
                if isSlowRunning { slowRunAnimation?.stop(); isSlowRunning = false }
                if isJumping { jumpOverAnimation?.stop(); isJumping = false; activeJumpBoundaryX = nil }
                
                if !isRunning {
                    fastRunAnimation?.start()
                    isRunning = true
                }
            } else if effectiveDistance > 200 {
                // SLOW RUN
                if isWalking { walkingAnimation?.stop(); isWalking = false }
                if isRunning { fastRunAnimation?.stop(); isRunning = false }
                if isJumping { jumpOverAnimation?.stop(); isJumping = false; activeJumpBoundaryX = nil }
                
                if !isSlowRunning {
                    slowRunAnimation?.start()
                    isSlowRunning = true
                }
            } else {
                // WALK
                if isRunning { fastRunAnimation?.stop(); isRunning = false }
                if isSlowRunning { slowRunAnimation?.stop(); isSlowRunning = false }
                if isJumping { jumpOverAnimation?.stop(); isJumping = false; activeJumpBoundaryX = nil }
                
                if !isWalking {
                    walkingAnimation?.start()
                    isWalking = true
                }
            }
            
            // Face direction
            characterNode.eulerAngles.y = dx > 0 ? .pi / 2 : -.pi / 2
            
            // Determine speed
            let moveSpeed: CGFloat
            if isJumping {
                moveSpeed = PetConfig.jumpSpeed * physicsScale
            } else if effectiveDistance > 500 {
                moveSpeed = PetConfig.runSpeed * physicsScale
            } else if effectiveDistance > 200 {
                moveSpeed = PetConfig.slowRunSpeed * physicsScale
            } else {
                moveSpeed = PetConfig.walkSpeed * physicsScale
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
            
            // Update chat bubble direction based on character position
            updateChatBubbleDirectionIfNeeded()
        } else {
            // Not moving - check for mouse behaviors and idle animations
            // First, ensure all movement animations are stopped
            if isWalking { walkingAnimation?.stop(); isWalking = false }
            if isRunning { fastRunAnimation?.stop(); isRunning = false }
            if isSlowRunning { slowRunAnimation?.stop(); isSlowRunning = false }
            if isJumping { jumpOverAnimation?.stop(); isJumping = false }
            
            // Double-check: If any movement animation is still active, don't play other animations
            if isWalking || isRunning || isSlowRunning || isJumping {
                return
            }
            
            // PRIORITY 2: MOUSE BEHAVIORS - Check for mouse interactions
            // Only check if not already performing a mouse behavior
            if !isPerformingMouseBehavior {
                checkMouseBehaviors(mousePos: CGPoint(x: targetX, y: mouseLoc.y), time: time, screenSize: screenSize)
            }
            
            // PRIORITY 3: IDLE ANIMATIONS - Only play when not moving and no mouse behaviors
            // Don't play idle animations if performing mouse behavior
            if isPerformingMouseBehavior {
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
                    
                    // STRICT PRIORITY CHECK: Don't start animation if movement started during rotation
                    guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping else {
                        self.isPerformingLongIdle = false
                        return
                    }
                    
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
                        // STRICT PRIORITY CHECK: Don't restart idle if movement started
                        guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping else {
                            self.isPerformingLongIdle = false
                            return
                        }
                        
                        self.isPerformingLongIdle = false
                        // Only restart idle breathing if character is actually still idle (not moving)
                        if !self.isIdleBreathing && !self.isLookingAround {
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
                        
                        // STRICT PRIORITY CHECK: Don't start animation if movement started during rotation
                        guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping else {
                            self.isPerformingLongIdle = false
                            return
                        }
                        
                        if scratchChoice {
                            self.armStretchAnimation?.start()
                        } else {
                            self.neckStretchAnimation?.start()
                        }
                        
                        // Return to idle breathing after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // STRICT PRIORITY CHECK: Don't restart idle if movement started
                            guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping else {
                                self.isPerformingLongIdle = false
                                return
                            }
                            
                            self.isPerformingLongIdle = false
                            // Only restart idle breathing if character is actually still idle (not moving)
                            if !self.isIdleBreathing && !self.isLookingAround {
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
                    
                    // STRICT PRIORITY CHECK: Don't start animation if movement started during rotation
                    guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping else {
                        self.isLookingAround = false
                        return
                    }
                    
                    self.lookAroundAnimation?.start()
                    
                    // Return to idle breathing after look-around completes (estimate 2 seconds)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // STRICT PRIORITY CHECK: Don't restart idle if movement started
                        guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping else {
                            self.lookAroundAnimation?.stop()
                            self.isLookingAround = false
                            return
                        }
                        
                        self.lookAroundAnimation?.stop()
                        self.isLookingAround = false
                        
                        // Only restart idle breathing if character is actually still idle (not moving)
                        if !self.isIdleBreathing && !self.isPerformingLongIdle {
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
        
        // Show initial chat bubble
        showChatBubble(text: "I am a pet and i am working for a software devloper for mac os app which is osm really awesome app")
    }

    // Factory method for per-desktop cameras
    func makeCameraNode(for desktopIndex: Int, screenSize: CGSize) -> SCNNode {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = Double(screenSize.height / 2)
        camera.zNear = 1
        camera.zFar = 2000

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
        
        node.position = SCNVector3(centerX, screenSize.height / 2, 400)
        
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
    
    func showChatBubble(text: String) {
        // remove existing
        chatBubble?.removeFromParentNode()
        
        let currentX = characterNode.position.x
        let scaleFactor = CGFloat(characterNode.scale.x)
        
        // Get screen width - use stored screenSize or fallback
        let screenWidth = currentScreenSize.width > 0 ? currentScreenSize.width : (NSScreen.main?.frame.width ?? 1440.0)
        
        // Calculate character's position relative to the ACTIVE desktop/screen
        // Use activeDesktopIndex to determine which screen we're viewing
        let activeScreenOffset = CGFloat(activeDesktopIndex) * screenWidth
        let relativeX = currentX - activeScreenOffset
        
        // Determine if character is on left or right side of the visible screen
        // Left side: relativeX < screenWidth / 2
        // Right side: relativeX >= screenWidth / 2
        
        // Bubble direction logic:
        // .left = Bubble appears to the RIGHT of pet (tail points bottom-left)
        // .right = Bubble appears to the LEFT of pet (tail points bottom-right)
        // So: character on left → bubble on right → use .left
        //     character on right → bubble on left → use .right
        
        var direction: ChatBubble.BubbleDirection = .left
        
        if relativeX >= screenWidth / 2 {
            // Character is on right side of visible screen → bubble on left
            direction = .right
        } else {
            // Character is on left side of visible screen → bubble on right
            direction = .left
        }
        
        let bubble = ChatBubble(text: text, direction: direction)
        
        // Smart vertical positioning based on character scale
        // Character height scales with characterNode.scale
        // Base head position is around 140-160 units, scaled appropriately
        let baseHeadHeight: CGFloat = 160.0
        let scaledHeadHeight = baseHeadHeight * scaleFactor
        
        // Position bubble above head with proper offset
        // The bubble's origin (tail tip) should be at the head position
        bubble.position = SCNVector3(0, scaledHeadHeight, -10)
        
        // Add constraint to always face camera for best readability
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .all
        bubble.constraints = [billboardConstraint]
        
        characterNode.addChildNode(bubble)
        chatBubble = bubble
        
        // Auto-hide after some time based on text length
        /*
        let duration = max(5.0, Double(text.count) * 0.1)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            // Only remove if it's still the SAME bubble
            if self?.chatBubble === bubble {
                self?.hideChatBubble()
            }
        }
        */
    }
    
    private func updateChatBubbleDirectionIfNeeded() {
        guard let bubble = chatBubble else { return }
        
        let currentX = characterNode.position.x
        let screenWidth = currentScreenSize.width > 0 ? currentScreenSize.width : (NSScreen.main?.frame.width ?? 1440.0)
        
        // Calculate character's position relative to the ACTIVE desktop/screen
        // Use activeDesktopIndex to determine which screen we're viewing
        let activeScreenOffset = CGFloat(activeDesktopIndex) * screenWidth
        let relativeX = currentX - activeScreenOffset
        
        // Determine new direction
        let newDirection: ChatBubble.BubbleDirection = relativeX >= screenWidth / 2 ? .right : .left
        
        // Only update if direction changed
        if bubble.direction != newDirection {
            bubble.setDirection(newDirection)
        }
    }
    
    func hideChatBubble() {
        guard let bubble = chatBubble else { return }
        
        // Smooth exit animation with fade
        let scaleDown = SCNAction.scale(to: 0.3, duration: 0.25)
        scaleDown.timingMode = .easeIn
        
        let fadeOut = SCNAction.fadeOut(duration: 0.25)
        
        let group = SCNAction.group([scaleDown, fadeOut])
        
        bubble.runAction(group) {
            bubble.removeFromParentNode()
        }
        
        if chatBubble === bubble {
            chatBubble = nil
        }
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
        jumpOverAnimation = JumpOverAnimation.setup(for: characterNode)
        
        // Mouse Behavior Animations
        angryEmotionAnimation = AngryEmotionAnimation.setup(for: characterNode)
        doubleHandWaveAnimation = DoubleHandWaveAnimation.setup(for: characterNode)
        oneHandWaveAnimation = OneHandWaveAnimation.setup(for: characterNode)
        pointingGestureAnimation = PointingGestureAnimation.setup(for: characterNode)
        surpriseAnimation = SurpriseAnimation.setup(for: characterNode)
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
        
        // UNCONDITIONALLY stop ALL idle animation players immediately (no blend)
        // Don't rely on state flags - just stop everything to be safe
        idleBreathingAnimation?.idleBreathingPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        lookAroundAnimation?.lookAroundPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        armStretchAnimation?.armStretchPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        neckStretchAnimation?.neckStretchPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        yawnAnimation?.yawnPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        
        // Reset all state flags
        isIdleBreathing = false
        isLookingAround = false
        isPerformingLongIdle = false
    }
    
    func updateSpotlightPosition(width: CGFloat, height: CGFloat) {
        // Optional: Update spotlight to center of the total view if needed
        if let spotNode = scene.rootNode.childNodes.first(where: { $0.light?.type == .spot }) {
             spotNode.position = SCNVector3(width / 2, height + 200, 200)
             spotNode.look(at: SCNVector3(width / 2, 0, 0))
        }
    }
    
    // MARK: - Mouse Behavior Helper Methods
    
    /// Stops all mouse behavior animations immediately
    private func stopAllMouseBehaviors() {
        // UNCONDITIONALLY stop ALL mouse behavior animation players immediately (no blend)
        // Don't rely on state flags - just stop everything to be safe
        angryEmotionAnimation?.angryPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        doubleHandWaveAnimation?.doubleWavePlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        oneHandWaveAnimation?.oneWavePlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        pointingGestureAnimation?.pointingPlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        surpriseAnimation?.surprisePlayers.forEach { $0.stop(withBlendOutDuration: 0) }
        
        // Reset state flag
        isPerformingMouseBehavior = false
        // Reset hover tracking
        mouseHoverStartTime = nil
    }
    
    /// Updates mouse position history for velocity tracking
    private func updateMouseHistory(position: CGPoint, time: TimeInterval) {
        mousePositionHistory.append((position: position, time: time))
        
        // Keep only recent history
        if mousePositionHistory.count > PetConfig.mouseHistorySize {
            mousePositionHistory.removeFirst()
        }
    }
    
    /// Calculates current mouse velocity in points per second
    private func calculateMouseVelocity() -> CGFloat {
        guard mousePositionHistory.count >= 2 else { return 0 }
        
        let recent = mousePositionHistory.suffix(3)
        guard let first = recent.first, let last = recent.last else { return 0 }
        
        let dx = last.position.x - first.position.x
        let dy = last.position.y - first.position.y
        let distance = sqrt(dx * dx + dy * dy)
        let timeDelta = last.time - first.time
        
        return timeDelta > 0 ? distance / CGFloat(timeDelta) : 0
    }
    
    /// Calculates distance between mouse and pet
    private func distanceToPet(mousePos: CGPoint) -> CGFloat {
        let petX = characterNode.position.x
        let dx = mousePos.x - petX
        let dy = mousePos.y - 0 // Pet is on ground (y=0)
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Checks if enough time has passed since last behavior (cooldown)
    private func canTriggerBehavior(_ behaviorName: String, cooldown: TimeInterval, currentTime: TimeInterval) -> Bool {
        guard let lastTime = lastMouseBehaviorTimes[behaviorName] else { return true }
        return currentTime - lastTime >= cooldown
    }
    
    /// Triggers a mouse behavior animation
    private func triggerMouseBehavior(_ behaviorName: String, currentTime: TimeInterval, animation: @escaping () -> Void, duration: TimeInterval = 2.0) {
        // Stop all idle animations
        stopAllIdleAnimations()
        
        // Stop any current mouse behavior
        stopAllMouseBehaviors()
        
        isPerformingMouseBehavior = true
        lastMouseBehaviorTimes[behaviorName] = currentTime
        
        // Face forward for the animation
        let rotateAction = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.3)
        rotateAction.timingMode = .easeInEaseOut
        
        characterNode.runAction(rotateAction) { [weak self] in
            guard let self = self else { return }
            
            // STRICT PRIORITY CHECK: Don't start animation if movement started during rotation
            guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping else {
                self.isPerformingMouseBehavior = false
                return
            }
            
            animation()
            
            // Return to idle after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                // STRICT PRIORITY CHECK: Don't change state if movement started
                guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping else {
                    return
                }
                
                self.isPerformingMouseBehavior = false
                // Reset hover tracking
                self.mouseHoverStartTime = nil
            }
        }
    }
    
    /// Detects and triggers mouse behaviors based on mouse state
    private func checkMouseBehaviors(mousePos: CGPoint, time: TimeInterval, screenSize: CGSize) {
        // Don't trigger if already performing a mouse behavior or moving
        guard !isPerformingMouseBehavior && !isWalking && !isRunning && !isSlowRunning && !isJumping else { return }
        
        // Scale proximity thresholds
        let scaleFactor = CGFloat(PetConfig.characterScale.x)
        let scaledProximityNear = PetConfig.mouseProximityNear * scaleFactor
        let scaledProximityClose = PetConfig.mouseProximityClose * scaleFactor
        
        let distance = distanceToPet(mousePos: mousePos)
        let velocity = calculateMouseVelocity()
        
        // BEHAVIOR 1: Surprise - Sudden mouse jump/teleport
        if velocity > PetConfig.mouseVelocitySudden && distance < scaledProximityClose {
            if canTriggerBehavior("surprise", cooldown: PetConfig.surpriseCooldown, currentTime: time) {
                triggerMouseBehavior("surprise", currentTime: time, animation: {
                    self.surpriseAnimation?.start()
                }, duration: 1.5)
                return
            }
        }
        
        // BEHAVIOR 2: Angry - Rapid erratic movement near pet
        if velocity > PetConfig.mouseVelocityRapid && distance < scaledProximityNear {
            if canTriggerBehavior("angry", cooldown: PetConfig.angryEmotionCooldown, currentTime: time) {
                triggerMouseBehavior("angry", currentTime: time, animation: {
                    self.angryEmotionAnimation?.start()
                }, duration: 2.5)
                return
            }
        }
        
        // BEHAVIOR 3: Double Wave - Mouse enters proximity zone
        if distance < scaledProximityNear && distance > scaledProximityClose {
            if canTriggerBehavior("doubleWave", cooldown: PetConfig.doubleWaveCooldown, currentTime: time) {
                triggerMouseBehavior("doubleWave", currentTime: time, animation: {
                    self.doubleHandWaveAnimation?.start()
                }, duration: 2.0)
                return
            }
        }
        
        // BEHAVIOR 4: One Hand Wave - Mouse hovers near pet
        if distance < scaledProximityNear {
            if mouseHoverStartTime == nil {
                mouseHoverStartTime = time
            } else if let hoverStart = mouseHoverStartTime, time - hoverStart >= PetConfig.hoverDuration {
                if canTriggerBehavior("oneWave", cooldown: PetConfig.oneHandWaveCooldown, currentTime: time) {
                    triggerMouseBehavior("oneWave", currentTime: time, animation: {
                        self.oneHandWaveAnimation?.start()
                    }, duration: 1.5)
                    mouseHoverStartTime = nil
                    return
                }
            }
        } else {
            mouseHoverStartTime = nil
        }
    }
    
    /// Handles mouse click events (call this from a global event monitor if needed)
    func handleMouseClick(at position: CGPoint, time: TimeInterval) {
        let distance = distanceToPet(mousePos: position)
        
        if distance < PetConfig.mouseProximityNear {
            if canTriggerBehavior("pointing", cooldown: PetConfig.pointingCooldown, currentTime: time) {
                triggerMouseBehavior("pointing", currentTime: time, animation: {
                    self.pointingGestureAnimation?.start()
                }, duration: 1.5)
            }
        }
    }
}
