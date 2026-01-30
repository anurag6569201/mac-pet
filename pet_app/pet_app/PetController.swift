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
    private var climbingAnimation: ClimbingAnimation?
    
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
    private var isClimbing = false
    private var isOnWindowTop = false
    private var isSafetyJumping = false

    
    // Climbing Physics State
    private var climbingStamina: Float = PetConfig.maxStamina
    private var climbingState: ClimbingState = .none
    private var climbingStartTime: TimeInterval = 0
    private var currentClimbHeight: CGFloat = 0
    private var totalClimbHeight: CGFloat = 0
    private var isClimbingResting: Bool = false
    private var lastClimbingUpdate: TimeInterval = 0
    private var climbingBaseX: CGFloat = 0 // Store original X position for sway calculation
    private var isFalling = false
    private var verticalVelocity: CGFloat = 0.0 // Current falling speed
    
    // Window Support State
    private var currentSupportWindow: YabaiWindow?
    private var lastSupportWindowFrame: YabaiFrame? // To track movement
    private var lastWindowPollTime: TimeInterval = 0
    private let windowPollInterval: TimeInterval = 0.05 // 20 FPS polling for riding
    
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
    
    // Cache of visible windows
    private var visibleWindows: [YabaiWindow] = []
    private var windowNodes: [Int: SCNNode] = [:] // Map window ID to SCNNode
    private var lastWindowUpdateTime: TimeInterval = 0
    private let windowUpdateInterval: TimeInterval = 1.0
    
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
            }
        }
    }
    
    func refreshVisibleWindows() {
        DispatchQueue.global(qos: .background).async {
            let windows = YabaiAutomation.shared.getVisibleWindows()
            DispatchQueue.main.async {
                self.visibleWindows = windows
                self.updateWindowNodes()
            }
        }
    }
    
    private func updateWindowNodes() {
        // Use current screen dimensions or fallback
        let screenH = currentScreenSize.height > 0 ? currentScreenSize.height : (NSScreen.main?.frame.height ?? 1080)
        let screenW = currentScreenSize.width > 0 ? currentScreenSize.width : (NSScreen.main?.frame.width ?? 1920)
        
        var activeWindowIDs: Set<Int> = []
        
        for window in visibleWindows {
            // Treat all windows as potentially walkable surfaces.
            // If window is "HOLLOW" (Height > 75% of screen), we create a thin CAP at the top.
            // This allows the pet to pass through the body but land on top.
            // If "RIGID" (Normal), we act as a solid block.
            let isHollow = window.frame.h > (screenH * 0.75)
            let targetHeight = isHollow ? 20.0 : window.frame.h
            
            activeWindowIDs.insert(window.id)
            
            // Calculate Virtual Position
            // localX assumes window.frame.x is global, so we take modulus for local display offset
            let localX = window.frame.x.truncatingRemainder(dividingBy: screenW)
            // space index is 1-based, convert to 0-based index for virtual world slot
            let virtualX = CGFloat(window.space - 1) * screenW + localX
            
            // Convert Y (Yabai Top-Left -> SceneKit Bottom-Left)
            // Top of window in SceneKit coords = screenH - window.frame.y
            // Center Y of the node = Top - (targetHeight / 2)
            let topY = screenH - window.frame.y
            let centerY = topY - (targetHeight / 2)
            let centerX = virtualX + window.frame.w / 2
            
            // Find or Create Node
            let node: SCNNode
            if let existing = windowNodes[window.id] {
                node = existing
            } else {
                node = SCNNode()
                node.name = "window_\(window.id)"
                
                // Add Static Physics Body (Rigid Body)
                node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                node.physicsBody?.categoryBitMask = 2 // Category 2: Windows
                node.physicsBody?.collisionBitMask = 1 // Collides with Character (1)
                
                scene.rootNode.addChildNode(node)
                windowNodes[window.id] = node
            }
            
            // Update Geometry and Position
            if let box = node.geometry as? SCNBox {
                if box.width != window.frame.w || box.height != targetHeight {
                    box.width = window.frame.w
                    box.height = targetHeight
                    // Update physics shape
                    node.physicsBody?.physicsShape = SCNPhysicsShape(geometry: box, options: nil)
                }
            } else {
                let box = SCNBox(width: window.frame.w, height: targetHeight, length: 100, chamferRadius: 0)
                // Invisible material
                let mat = SCNMaterial()
                mat.diffuse.contents = NSColor.clear // Invisible
                box.materials = [mat]
                node.geometry = box
                
                node.physicsBody?.physicsShape = SCNPhysicsShape(geometry: box, options: nil)
            }
            
            node.position = SCNVector3(centerX, centerY, 0)
        }
        
        // Remove nodes for closed/hidden windows OR windows that became hollow (if logic changed)
        for (id, node) in windowNodes {
            if !activeWindowIDs.contains(id) {
                node.removeFromParentNode()
                windowNodes.removeValue(forKey: id)
            }
        }
    }
    
    // Check if a proposed position collides with any rigid window
    // Returns the Window ID if collision detected, nil otherwise
    private func checkCollision(at position: SCNVector3) -> Int? {
        // Simple AABB Check against all window nodes
        // Character approximation: Box 40x80 centered at position
        let charWidth: CGFloat = 40 * CGFloat(characterNode.scale.x)
        let charHeight: CGFloat = 80 * CGFloat(characterNode.scale.y)
        
        // Character bounds (centered on X, Y is bottom)
        let charMinX = position.x - charWidth/2
        let charMaxX = position.x + charWidth/2
        let charMinY = position.y
        let charMaxY = position.y + charHeight
        
        // Collect all collision candidates
        var collisions: [YabaiWindow] = []
        
        for window in visibleWindows {
            guard let node = windowNodes[window.id],
                  let box = node.geometry as? SCNBox else { continue }
            
            // Node position is center
            let boxW = box.width
            let boxH = box.height
            
            let boxMinX = node.position.x - boxW/2
            let boxMaxX = node.position.x + boxW/2
            let boxMinY = node.position.y - boxH/2
            let boxMaxY = node.position.y + boxH/2
            
            // Buffer to allow touching
            let buffer: CGFloat = 2.0
            
            // Intersection Check
            if charMaxX > boxMinX + buffer && charMinX < boxMaxX - buffer &&
               charMaxY > boxMinY + buffer && charMinY < boxMaxY - buffer {
                collisions.append(window)
            }
        }
        
        // No collisions?
        if collisions.isEmpty { return nil }
        
        // Sort collisions by Z-order (Index in visibleWindows represents stack order, 0 is top)
        // We want the TOP-most window that is relevant.
        // visibleWindows is already sorted by Yabai (usually).
        // Let's ensure we are picking based on visibleWindows order.
        let sortedCollisions = collisions.sorted { w1, w2 in
            let idx1 = visibleWindows.firstIndex(where: { $0.id == w1.id }) ?? Int.max
            let idx2 = visibleWindows.firstIndex(where: { $0.id == w2.id }) ?? Int.max
            return idx1 < idx2 // Lower index = Higher Z-order (Top)
        }
        
        // If we are currently standing on a window, we should ignore any window that is BEHIND it.
        if isOnWindowTop, let supportWindow = currentSupportWindow {
            let supportIndex = visibleWindows.firstIndex(where: { $0.id == supportWindow.id }) ?? Int.max
            
            // Filter out any collision that is BEHIND (higher index) the support window
            // EXCEPT if it is the support window itself? (Wait, collision check is usually for movement blocking)
            // If we are ON TOP of a window, we shouldn't collide with IT physically as a wall unless we hit a side... 
            // implementation detail: checkCollision prevents x-movement.
            
            // We only care about windows IN FRONT of the support window.
            // OR windows that are the support window itself? No, we walk ON TOP of support.
            
            for window in sortedCollisions {
                let index = visibleWindows.firstIndex(where: { $0.id == window.id }) ?? Int.max
                
                // If this window is BEHIND or SAME level as support, ignore it as an obstacle?
                // Actually, if it is SAME level, it IS the support window (or same layer).
                // Usually we shouldn't collide with the thing we are standing on unless we hit a "wall" part of it?
                // But our windows are simple boxes. Colliding with support window usually means we are 'inside' it?
                // No, checkCollision is called with `nextX`. If we walk INTO the support window's bounds? 
                // Since we are ON TOP, we are logically 'above' it. `checkCollision` checks 3D intersection.
                // If `isOnWindowTop`, our Y is `supportWindow.topY`. 
                // The box extends down. So our feet touch the top. 
                // Strictly speaking, we might intersect the top edge slightly.
                
                if index >= supportIndex {
                     // This window is behind or equal to support.
                     // It shouldn't block us.
                     continue
                }
                
                // If we found a window strictly in front (lower index), that's a blocker!
                return window.id
            }
            
            return nil // No valid blockers found in front
            
        } else {
            // Not on any window (Ground or falling)
            // Return the top-most collision
            return sortedCollisions.first?.id
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
            // Update window data periodically
            if time - lastWindowUpdateTime > windowUpdateInterval {
                lastWindowUpdateTime = time
                refreshVisibleWindows()
            }
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
        
        // Edge Detection - Check if character walked off window top
        // This must run EVERY frame, not just when moving
        // Edge Detection - Check if character walked off window top
        // This must run EVERY frame, not just when moving
        if isOnWindowTop, let window = currentSupportWindow {
            // 1. Poll for Window Movement
            if time - lastWindowPollTime > windowPollInterval {
                lastWindowPollTime = time
                
                let winID = window.id
                // Use a dedicated serial queue or check if we are already polling?
                // For simplicity, just dispatch. Throttling handles overload.
                DispatchQueue.global(qos: .userInteractive).async {
                    if let newWindow = YabaiAutomation.shared.getWindow(id: winID) {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self, self.isOnWindowTop, 
                                  self.currentSupportWindow?.id == winID,
                                  let lastFrame = self.lastSupportWindowFrame else { return }
                            
                            // Check for movement
                            let dx = newWindow.frame.x - lastFrame.x
                            let dy = newWindow.frame.y - lastFrame.y
                            
                            if dx != 0 || dy != 0 {
                                // Apply delta to character
                                // Note: Yabai Y+ is Down, SceneKit Y+ is Up.
                                // If window moves DOWN (+dy), Character should move DOWN (-dy)
                                self.characterNode.position.x += dx
                                self.characterNode.position.y -= dy
                                
                                // Update tracking
                                self.lastSupportWindowFrame = newWindow.frame
                                // Update current window reference so edge detection uses new frame
                                self.currentSupportWindow = newWindow 
                            }
                        }
                    }
                }
            }

            // 2. Edge Detection (use updated window frame if available)
            // We use the latest known frame from currentSupportWindow
            let currentX = characterNode.position.x
            let winX = window.frame.x // This might be slightly stale if poll hasn't returned yet, but that's acceptable
            let winW = window.frame.w
            
            // Allow small buffer
            let buffer: CGFloat = 10.0 
            
            if currentX < winX - buffer || currentX > winX + winW + buffer {
                // Walked off!
                // If moving significantly, perform a safety jump
                if abs(dx) > PetConfig.mouseDeadZoneRadius * scaleFactor {
                    performSafetyJump()
                } else {
                    startFalling()
                }
            }
        }
        
        // Gravity Logic
        if isFalling {
            // Apply gravity
            verticalVelocity += PetConfig.gravity * CGFloat(deltaTime)
            verticalVelocity = min(verticalVelocity, PetConfig.maxFallSpeed)
            
            let fallDist = verticalVelocity * CGFloat(deltaTime)
            let newY = characterNode.position.y - fallDist
            
            // Check for landing on windows
            var landingY: CGFloat? = nil
            var landingWindow: YabaiWindow? = nil
            
            let charWidth: CGFloat = 40 * CGFloat(characterNode.scale.x)
            let charMinX = characterNode.position.x - charWidth/2
            let charMaxX = characterNode.position.x + charWidth/2
            
            for (id, node) in windowNodes {
                guard let box = node.geometry as? SCNBox else { continue }
                
                // Get absolute top Y of the physical surface
                let nodeTopY = node.position.y + box.height/2
                let nodeMinX = node.position.x - box.width/2
                let nodeMaxX = node.position.x + box.width/2
                
                // Horizontal buffer
                let buffer: CGFloat = 15.0
                
                if charMaxX > nodeMinX - buffer && charMinX < nodeMaxX + buffer {
                    // Check if we crossed the top edge
                    let oldY = characterNode.position.y
                    
                    // Interaction logic:
                    // 1. We must be falling (velocity > 0 downwards, handled by isFalling)
                    // 2. Prior Position >= Surface (or very close)
                    // 3. New Position <= Surface
                    if oldY >= nodeTopY - 5.0 && newY <= nodeTopY + 5.0 {
                        // We found a landing candidate
                        // Pick the highest one if multiple overlap (though rare for standard windows)
                        if landingY == nil || nodeTopY > landingY! {
                            landingY = nodeTopY
                            landingWindow = visibleWindows.first(where: { $0.id == id })
                        }
                    }
                }
            }
            
            if let targetY = landingY, let window = landingWindow {
                // Landed on window
                characterNode.position.y = targetY
                isFalling = false
                isSafetyJumping = false
                verticalVelocity = 0.0
                
                isOnWindowTop = true
                currentSupportWindow = window
                lastSupportWindowFrame = window.frame
            } else if newY <= 0 {
                // Landed on ground
                characterNode.position.y = 0
                isFalling = false
                isSafetyJumping = false
                verticalVelocity = 0.0
                
                isOnWindowTop = false
                currentSupportWindow = nil
                lastSupportWindowFrame = nil
            } else {
                characterNode.position.y = newY
            }
        }
        
        if abs(dx) > threshold {
            // PRIORITY 1: MOVEMENT ANIMATIONS - Always override idle animations
            
            // STRICT PRIORITY CHECK: If Climbing or Falling, IGNORE horizontal movement requests
            // This prevents "stuck at mid" issues where walk animation tries to override climb animation
            // EXCEPTION: Allow movement if Safety Jumping
            guard !isClimbing && (!isFalling || isSafetyJumping) else {
                return
            }
            
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
            
            // Climbing Trigger Logic - REMOVED (User preferred collision-only climbing)
            // Previously checked if mouse is near any window edge to start climbing.
            // Now relying on collision detection to trigger climbing.
            
            // Jump Logic: 
            // 1. If already jumping, check if we finished the jump (moved past boundary + prepare dist)
            // 2. If not jumping, but transitioning space, check if close enough to start jump
            
            var shouldBeJumping = isSafetyJumping
            
            if !shouldBeJumping {
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
            
            // Check collision for next position
            let nextX = characterNode.position.x + moveDistance * (dx > 0 ? 1 : -1)
            let proposedPosition = SCNVector3(nextX, characterNode.position.y, characterNode.position.z)
            
            if checkCollision(at: proposedPosition) == nil {
                if moveDistance < abs(dx) {
                    characterNode.position.x += moveDistance * (dx > 0 ? 1 : -1)
                } else {
                    // Arrived
                    characterNode.position.x = targetX
                }
            } else if let hitWindowID = checkCollision(at: proposedPosition) {
                // Blocked by rigid body
                // Check if we should start climbing this window!
                if let window = visibleWindows.first(where: { $0.id == hitWindowID }) {
                    // We hit a window. Are we facing it?
                    // dx > 0 means moving right. If we hit something, it must be to our right.
                    // dx < 0 means moving left. If we hit something, it must be to our left.
                    
                    // Trigger climb!
                    // Determine which side we are on relative to the window CENTER
                    // This helps deciding facingRight logic
                    // Actually, if we are moving RIGHT (dx > 0), we are hitting the LEFT side of the window.
                    // If we are moving LEFT (dx < 0), we are hitting the RIGHT side of the window.
                    
                    let facingRight = dx > 0 // We face right to climb the left edge of the window
                    
                    // Double check we are actually at the edge
                    let winX = window.frame.x
                    let winW = window.frame.w
                    
                    // Simple validation: If moving right, we should be near winX
                    // If moving left, we should be near winX + winW
                    
                    // Only start climbing if we are NOT already climbing and have stamina
                    if !isClimbing && climbingStamina > 10 {
                         startClimbing(window: window, facingRight: facingRight) {
                             // completion
                         }
                    }
                }
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
            
            // Double-check: If any movement animation is still active or falling, don't play other animations
            if isWalking || isRunning || isSlowRunning || isJumping || isClimbing || isFalling {
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
                    guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping && !self.isClimbing && !self.isFalling else {
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
                        guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping && !self.isClimbing && !self.isFalling else {
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
                        guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping && !self.isClimbing && !self.isFalling else {
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
                            guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping && !self.isClimbing && !self.isFalling else {
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
                    guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping && !self.isClimbing && !self.isFalling else {
                        self.isLookingAround = false
                        return
                    }
                    
                    self.lookAroundAnimation?.start()
                    
                    // Return to idle breathing after look-around completes (estimate 2 seconds)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // STRICT PRIORITY CHECK: Don't restart idle if movement started
                        guard !self.isWalking && !self.isRunning && !self.isSlowRunning && !self.isJumping && !self.isClimbing && !self.isFalling else {
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
        
        // Always update chat bubble position to keep it aligned with character
        updateChatBubblePosition()
        
        // Recover stamina when not climbing
        recoverStamina(deltaTime: deltaTime)
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
        
        // Add Kinematic Physics Body to Character
        // Capsule approx size: height 100, radius 25
        let charShape = SCNPhysicsShape(geometry: SCNCapsule(capRadius: 20, height: 100), options: nil)
        characterNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: charShape)
        characterNode.physicsBody?.categoryBitMask = 1 // Category 1: Character
        characterNode.physicsBody?.collisionBitMask = 2 | 4 // Collides with Windows (2) and Floor (4 if set)
        
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
        
        // Mark as rigid surface for physics interactions
        floorNode.name = "rigidSurface"
        floorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        
        scene.rootNode.addChildNode(floorNode)
        
        // Show initial chat bubble with a large paragraph
        showChatBubble(text: "Hello! I'm your desktop pet companion. I can walk, run, jump across multiple desktops, and perform various animations. I'll follow your mouse cursor around and react to your movements. Try moving your mouse near me to see different behaviors!")
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
        
        // Calculate which screen the character is currently on based on their X position
        let characterScreenIndex = Int(currentX / screenWidth)
        
        // Calculate character's position relative to THEIR current screen (not active desktop)
        let screenLeftEdge = CGFloat(characterScreenIndex) * screenWidth
        let relativeX = currentX - screenLeftEdge
        
        // Determine if character is on left or right side of their current screen
        // Left side: relativeX < screenWidth / 2
        // Right side: relativeX >= screenWidth / 2
        
        // Bubble direction logic:
        // .left = Bubble appears to the RIGHT of pet (tail points bottom-left)
        // .right = Bubble appears to the LEFT of pet (tail points bottom-right)
        // So: character on left → bubble on right → use .left
        //     character on right → bubble on left → use .right
        
        var direction: ChatBubble.BubbleDirection = .left
        
        if relativeX >= screenWidth / 2 {
            // Character is on right side of their screen → bubble on left
            direction = .right
        } else {
            // Character is on left side of their screen → bubble on right
            direction = .left
        }
        
        let bubble = ChatBubble(text: text, direction: direction)
        
        // Ensure bubble scale is always 1.0 (independent from character scale)
        bubble.scale = SCNVector3(1.0, 1.0, 1.0)
        
        // Smart vertical positioning - use fixed height independent of character scale
        // Base head position is around 140-160 units, but we keep it fixed regardless of scale
        let baseHeadHeight: CGFloat = 160.0
        // Scale the head height based on character scale for positioning, but bubble itself stays unscaled
        let scaledHeadHeight = baseHeadHeight * scaleFactor
        
        // Position bubble in world space relative to character's world position
        // The bubble's origin (tail tip) should be at the head position
        let worldBubbleY = characterNode.position.y + scaledHeadHeight
        bubble.position = SCNVector3(characterNode.position.x, worldBubbleY, characterNode.position.z - 10)
        
        // Add constraint to always face camera for best readability
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .all
        bubble.constraints = [billboardConstraint]
        
        // Add to scene root instead of characterNode to avoid inheriting scale
        scene.rootNode.addChildNode(bubble)
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
        
        // Calculate which screen the character is currently on based on their X position
        let characterScreenIndex = Int(currentX / screenWidth)
        
        // Calculate character's position relative to THEIR current screen (not active desktop)
        let screenLeftEdge = CGFloat(characterScreenIndex) * screenWidth
        let relativeX = currentX - screenLeftEdge
        
        // Determine new direction based on character's position within their screen
        let newDirection: ChatBubble.BubbleDirection = relativeX >= screenWidth / 2 ? .right : .left
        
        // Only update if direction changed
        if bubble.direction != newDirection {
            bubble.setDirection(newDirection)
        }
    }
    
    private func updateChatBubblePosition() {
        guard let bubble = chatBubble else { return }
        
        // Ensure bubble scale remains independent (always 1.0)
        bubble.scale = SCNVector3(1.0, 1.0, 1.0)
        
        // Calculate head height based on character scale for positioning
        let scaleFactor = CGFloat(characterNode.scale.x)
        let baseHeadHeight: CGFloat = 160.0
        let scaledHeadHeight = baseHeadHeight * scaleFactor
        
        // Update bubble position in world space to follow character
        let worldBubbleY = characterNode.position.y + scaledHeadHeight
        bubble.position = SCNVector3(characterNode.position.x, worldBubbleY, characterNode.position.z - 10)
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
        
        // Climbing Animation
        climbingAnimation = ClimbingAnimation.setup(for: characterNode)
    }
    
    private func startSequence(size: CGSize) {
        // This function is currently disabled and not used
        // Mouse following logic is used instead
    }
    
    // MARK: - Climbing Logic
    
    func startClimbing(window: YabaiWindow, facingRight: Bool, completion: @escaping () -> Void) {
        guard !isClimbing else { return }
        
        stopAllIdleAnimations()
        stopAllMouseBehaviors()
        
        isClimbing = true
        isFalling = false
        isSafetyJumping = false
        isOnWindowTop = false // Critical: We are on the wall, not the top
        verticalVelocity = 0.0
        currentSupportWindow = window
        
        // Orient towards the wall (Inside -> Facing Edge)
        // If we are facing right (moving right), we want to KEEP facing right (pi/2) to hit the wall
        // If we are facing left (moving left), we want to KEEP facing left (-pi/2) to hit the wall
        characterNode.eulerAngles.y = facingRight ? .pi / 2 : -.pi / 2
        
        // Calculate window edge X position with alignment offset
        // If facing right (Left Edge of window), we want to be inside (to the right of edge)
        // If facing left (Right Edge of window), we want to be inside (to the left of edge)
        let offset = facingRight ? PetConfig.climbingAlignmentOffset : -PetConfig.climbingAlignmentOffset
        let windowEdgeX = (facingRight ? window.frame.x : (window.frame.x + window.frame.w)) + offset
        
        // Store base X for sway calculations
        climbingBaseX = windowEdgeX
        
        // Move character to window edge first (if not already there)
        let targetPosition = SCNVector3(windowEdgeX, characterNode.position.y, characterNode.position.z)
        let distance = abs(characterNode.position.x - windowEdgeX)
        // Calculate duration based on distance to be snappy (using 2x run speed approx 1000pts/sec)
        // If very close (< 2 pts), make it instant. Max duration 0.2s to avoid slowness if far.
        let duration = distance < 2.0 ? 0.0 : min(0.2, TimeInterval(distance / 1000.0))
        
        let moveToEdge = SCNAction.move(to: targetPosition, duration: duration)
        moveToEdge.timingMode = .easeOut
        
        characterNode.runAction(moveToEdge) { [weak self] in
            guard let self = self, self.isClimbing else { return }
            
            // Now calculate climb height from current position
            let screenHeight = self.currentScreenSize.height > 0 ? self.currentScreenSize.height : (NSScreen.main?.frame.height ?? 1080)
            let windowTopY = screenHeight - window.frame.y
            let currentY = self.characterNode.position.y
            
            // Calculate effective climb distance, stopping short for the pull-up animation
            // This prevents the character from climbing with feet all the way to the top
            let climbDistance = windowTopY - currentY - PetConfig.climbingPullUpOffset
            
            // Set total height for physics calculations
            self.totalClimbHeight = climbDistance
            
            // Safety check
            guard climbDistance > 0 else {
                self.isClimbing = false
                self.currentSupportWindow = nil
                return
            }
            
            // DIRECTLY start climbing loop and movement (Skip startClimb wait)
            // The "start" animation file is now same as loop, so waiting for it effectively
            // pauses the character in place for one cycle. We skip that to allow continuous movement.
            
            // FLIP DIRECTION for the loop phase
            // User requirement: "flip the character like its climbing left caing to do right facing"
            // Start: Face Wall -> Loop: Face Away (or vice versa depending on asset)
            // We flip 180 degrees from the start direction.
            
            let currentYAngle = self.characterNode.eulerAngles.y
            self.characterNode.eulerAngles.y = currentYAngle + .pi
            
            self.climbingAnimation?.startLoop()
            
            // Simple climb action - just move up
            let duration = TimeInterval(climbDistance / PetConfig.climbSpeed)
            let climbAction = SCNAction.moveBy(x: 0, y: climbDistance, z: 0, duration: duration)
            climbAction.timingMode = .linear
            
            self.characterNode.runAction(climbAction) {
                self.stopClimbing(completion: completion)
            }
        }
    }
    
    func stopClimbing(completion: @escaping () -> Void) {
        guard isClimbing, let window = currentSupportWindow else { completion(); return }
        
        characterNode.removeAllActions() 
        
        climbingAnimation?.stopLoop()
        
        // Determine side and direction to move onto ledge
        let winCenter = window.frame.x + (window.frame.w / 2)
        let isLeftEdge = climbingBaseX < winCenter
        
        // Target: move slightly inside the window to avoid immediately falling off
        let safeBuffer: CGFloat = 30.0
        let targetX = isLeftEdge ? (window.frame.x + safeBuffer) : (window.frame.x + window.frame.w - safeBuffer)
        let moveDistanceX = targetX - characterNode.position.x
        
        // Target Y: Top of window (should match where we want to land)
        let screenHeight = self.currentScreenSize.height > 0 ? self.currentScreenSize.height : (NSScreen.main?.frame.height ?? 1080)
        let targetY = screenHeight - window.frame.y
        let moveDistanceY = targetY - characterNode.position.y
        
        // Animate onto ledge concurrently with end animation
        // Duration matches roughly with the pull-up animation
        let pullUpDuration: TimeInterval = 1.0
        let moveAction = SCNAction.moveBy(x: moveDistanceX, y: moveDistanceY, z: 0, duration: pullUpDuration)
        moveAction.timingMode = .easeOut
        
        characterNode.runAction(moveAction)
        
        // Flip rotation for end animation since it has opposite orientation
        characterNode.eulerAngles.y += .pi
        
        // Stop loop with fade and start end with blend
        climbingAnimation?.stopLoop(fadeDuration: 0.2)
        climbingAnimation?.endClimb(blendInDuration: 0.2) { [weak self] in
            guard let self = self else { return }
            self.isClimbing = false
            
            // Transition to Window Top
            self.isOnWindowTop = true
            
            // Ensure positions are exact
            if let win = self.currentSupportWindow {
                   let screenHeight = self.currentScreenSize.height > 0 ? self.currentScreenSize.height : (NSScreen.main?.frame.height ?? 1080)
                   self.characterNode.position.y = screenHeight - win.frame.y
                   self.characterNode.position.x = targetX
                   
                   // Initialize tracking frame
                   self.lastSupportWindowFrame = win.frame
            }
            
            completion()
        }
    }
    
    private func performSafetyJump() {
        guard !isFalling else { return }
        
        stopAllIdleAnimations()
        if isWalking { walkingAnimation?.stop(); isWalking = false }
        if isSlowRunning { slowRunAnimation?.stop(); isSlowRunning = false }
        if isRunning { fastRunAnimation?.stop(); isRunning = false }
        
        isOnWindowTop = false
        currentSupportWindow = nil
        lastSupportWindowFrame = nil
        isFalling = true
        isSafetyJumping = true
        isJumping = true
        climbingState = .none
        
        // Initial upward velocity
        verticalVelocity = -400.0
        
        jumpOverAnimation?.start()
    }
    
    func startFalling() {
        guard !isFalling else { return }
        
        stopAllIdleAnimations() // Stop anything like breathing if we were idle
        // Might want a falling animation eventually
        
        isOnWindowTop = false
        currentSupportWindow = nil
        lastSupportWindowFrame = nil
        isFalling = true
        verticalVelocity = 0.0 // Reset velocity
        
        // Reset climbing state
        climbingState = .none
        climbingStamina = min(PetConfig.maxStamina, climbingStamina + 20.0) // Small stamina boost from rest
    }
    
    // MARK: - Climbing Physics
    
    /// Update climbing physics - called every frame while climbing
    private func updateClimbingPhysics(deltaTime: TimeInterval, time: TimeInterval) {
        guard isClimbing, let window = currentSupportWindow else { return }
        
        // Calculate progress
        let progress = currentClimbHeight / max(1.0, totalClimbHeight)
        
        // Update stamina
        updateClimbingStamina(deltaTime: deltaTime)
        
        // Check for slip events (unless already slipping or resting)
        if climbingState != .slipping && climbingState != .resting {
            let shouldSlip = ClimbingPhysics.shouldSlip(
                stamina: climbingStamina,
                deltaTime: deltaTime,
                heightClimbed: currentClimbHeight,
                totalHeight: totalClimbHeight
            )
            
            if shouldSlip {
                handleClimbingSlip()
                return // Skip movement this frame
            }
        }
        
        // Check for rest events (unless already resting or slipping)
        if climbingState != .resting && climbingState != .slipping {
            let timeClimbing = time - climbingStartTime
            let shouldRest = ClimbingPhysics.shouldRest(
                stamina: climbingStamina,
                timeClimbing: timeClimbing,
                deltaTime: deltaTime
            )
            
            if shouldRest {
                initiateClimbingRest()
                return // Skip movement this frame
            }
        }
        
        // Update climbing state
        let newState = ClimbingPhysics.determineNextState(
            currentState: climbingState,
            stamina: climbingStamina,
            progress: progress,
            isSlipping: false,
            shouldRest: false
        )
        
        if newState != climbingState {
            transitionClimbingState(to: newState)
        }
        
        // Multi-window climbing: Check for overlapping windows
        checkForClimbingTransition()

        
        // Calculate climbing speed based on physics
        let maxClimbSpeed = ClimbingPhysics.calculateSpeed(
            stamina: climbingStamina,
            heightClimbed: currentClimbHeight,
            totalHeight: totalClimbHeight,
            state: climbingState
        )
        
        // MOUSE FOLLOWING LOGIC (Vertical)
        // Get mouse position relative to window bottom (our coordinate system)
        let mouseLoc = NSEvent.mouseLocation
        // We need to compare mouse Y to character Y
        // Simply: Target Y is mouseLoc.y
        // But we clamp it to the window range
        
        let targetY = mouseLoc.y
        let currentY = characterNode.position.y
        
        // Calculate desired movement
        let dy = targetY - currentY
        
        // Apply deadzone
        var verticalMovement: CGFloat = 0
        if abs(dy) > 10.0 { // Small deadzone
             // Determine direction
             let direction: CGFloat = dy > 0 ? 1 : -1
             
             // Move towards mouse, capped by maxClimbSpeed
             let moveDist = min(abs(dy), maxClimbSpeed * CGFloat(deltaTime))
             verticalMovement = moveDist * direction
        }
        
        // Update animation speed to match ACTUAL movement
        // If moving up, positive speed. If moving down, negative speed.
        // If stationary, 0.
        let speedMultiplier = Float(verticalMovement / (PetConfig.climbSpeed * CGFloat(deltaTime)))
        // We might want to clamp this to avoid crazy animation speeds if lag occurs, but typical ranges are fine.
        // Identify "stopped" vs "moving"
        if abs(verticalMovement) < 0.001 {
             climbingAnimation?.updateClimbSpeed(multiplier: 0)
        } else {
             // Use absolute value for speed magnitude, or keep sign?
             // Animation usually plays forward for up.
             // If we go down, we might want to play backward? 
             // Standard `climbingAnimation` might expect positive multiplier.
             // Let's assume positive for now, or check Animation class capabilities.
             // Actually, usually backward playback needs negative speed.
             climbingAnimation?.updateClimbSpeed(multiplier: speedMultiplier)
        }
        
        // Add horizontal sway for realism
        let timeClimbing = time - climbingStartTime
        let sway = ClimbingPhysics.calculateSway(
            timeClimbing: timeClimbing,
            stamina: climbingStamina,
            heightClimbed: currentClimbHeight
        )
        
        // Apply movement (allow movement in all states except resting)
        if climbingState != .resting {
            // Even in slipping state, we want controlled movement
            characterNode.position.y += verticalMovement
            
            // Apply subtle sway relative to base X position
            characterNode.position.x = climbingBaseX + sway
            
            // Update climb height reference
            // currentClimbHeight should be relative to START of climb?
            // Actually `currentClimbHeight` tracks how far up the window we are.
            // Let's recalculate it based on Y position relative to window bottom?
            // Or just accumulate? Accumulating matches previous logic.
            currentClimbHeight += verticalMovement
        }
        
        // Check if reached top (with small buffer for floating point errors)
        if currentClimbHeight >= totalClimbHeight * 0.95 || progress >= 0.95 {
             // Only auto-finish if we are moving UP
             if verticalMovement > 0 {
                stopClimbing {
                    // Climbing complete
                }
             }
        }
        
        // Check if reached bottom (abort climb)
        if currentClimbHeight <= 0 {
             // Fell off bottom / User went down
             isClimbing = false
             currentSupportWindow = nil
             // Reset to ground or whatever
             characterNode.position.y = 0 // Or just let gravity take over next frame if we set isFalling?
             // Let's just exit climb state cleanly
             climbingAnimation?.stopLoop()
        }
    }
    
    /// Update stamina based on climbing state
    private func updateClimbingStamina(deltaTime: TimeInterval) {
        let drainRate = ClimbingPhysics.calculateStaminaDrain(
            climbSpeed: PetConfig.climbSpeed,
            windowHeight: totalClimbHeight,
            state: climbingState
        )
        
        climbingStamina -= drainRate * Float(deltaTime)
        climbingStamina = max(0, min(PetConfig.maxStamina, climbingStamina))
        
        // Update animation to reflect tiredness
        climbingAnimation?.setTiredState(isTired: climbingStamina < PetConfig.tiredThreshold)
    }
    
    /// Handle slip event
    private func handleClimbingSlip() {
        guard climbingState != .slipping else { return }
        
        climbingState = .slipping
        
        // Play slip recovery animation
        climbingAnimation?.playSlipRecovery { [weak self] in
            guard let self = self else { return }
            // Return to previous state after recovery
            self.climbingState = self.climbingStamina > PetConfig.tiredThreshold ? .steady : .tired
        }
        
        // Slide down slightly
        let slipAmount = PetConfig.slipDistance
        characterNode.position.y -= slipAmount
        currentClimbHeight = max(0, currentClimbHeight - slipAmount)
        
        // Slipping costs extra stamina (panic)
        climbingStamina -= 5.0
        climbingStamina = max(0, climbingStamina)
    }
    
    /// Initiate rest period
    private func initiateClimbingRest() {
        guard climbingState != .resting else { return }
        
        climbingState = .resting
        isClimbingResting = true
        
        let restDuration = ClimbingPhysics.getRestDuration(stamina: climbingStamina)
        
        climbingAnimation?.playRest(duration: restDuration) { [weak self] in
            guard let self = self else { return }
            self.isClimbingResting = false
            // Return to appropriate state after rest
            self.climbingState = self.climbingStamina > PetConfig.tiredThreshold ? .steady : .tired
        }
    }
    
    /// Transition between climbing states
    private func transitionClimbingState(to newState: ClimbingState) {
        let oldState = climbingState
        climbingState = newState
        
        // Handle state-specific animations
        switch newState {
        case .reaching:
            // Just slow down animation, don't stop climbing
            climbingAnimation?.playReaching { }
        case .pullingUp:
            // Final animation, but let physics complete the climb
            climbingAnimation?.playPullUp { }
        case .tired:
            climbingAnimation?.setTiredState(isTired: true)
        case .steady:
            if oldState == .tired {
                climbingAnimation?.setTiredState(isTired: false)
            }
        default:
            break
        }
    }
    
    /// Recover stamina when on ground or window top
    private func recoverStamina(deltaTime: TimeInterval) {
        if !isClimbing && !isFalling {
            // Climbing trigger removed per user request
            climbingStamina = min(PetConfig.maxStamina, climbingStamina)
        }
    }
    
    /// Checks if the pet should transition to a different overlapping window while climbing
    private func checkForClimbingTransition() {
        guard isClimbing, let currentWindow = currentSupportWindow else { return }
        
        let position = characterNode.position
        
        // Iterate through visible windows to find a better support
        // visibleWindows is sorted by z-order (0 is top)
        for window in visibleWindows {
            // Stop if we reach current (only transition to windows in front)
            if window.id == currentWindow.id { return }
            
            // Skip hollow/invalid (must be rigid surface)
            guard let node = windowNodes[window.id],
                  node.physicsBody?.type == .static else { continue }
            
            // Get bounds
            let winFrame = window.frame
            let screenHeight = currentScreenSize.height > 0 ? currentScreenSize.height : (NSScreen.main?.frame.height ?? 1080)
            let winBottomY = screenHeight - (winFrame.y + winFrame.h)
            let winTopY = screenHeight - winFrame.y
            let winLeft = winFrame.x
            let winRight = winFrame.x + winFrame.w
            
            // Check vertical overlap first
            if position.y > winBottomY && position.y < winTopY {
                // Check distance to edges
                let distLeft = abs(position.x - winLeft)
                let distRight = abs(position.x - winRight)
                let minEdgeDist = min(distLeft, distRight)
                
                // Only transition if we are close enough to an edge to grab it
                let transitionReach: CGFloat = 40.0
                
                if minEdgeDist < transitionReach {
                    // Transition!
                    let newFacingRight = distLeft < distRight
                    
                    print("Climb Transition: Window \(currentWindow.id) -> \(window.id)")
                    
                    // Force restart climbing on the new window
                    // We momentarily disable isClimbing to bypass the guard in startClimbing
                    self.isClimbing = false
                    
                    self.startClimbing(window: window, facingRight: newFacingRight) {
                         // Completion block
                    }
                    
                    return // Stop
                }
            }
        }
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
