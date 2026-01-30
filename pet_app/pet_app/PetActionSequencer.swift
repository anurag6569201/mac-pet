import SceneKit
import SwiftUI

/// A centralized sequencer to manage and demonstrate all pet animations.
/// This class consolidates all individual animation structs and provides
/// a unified interface to trigger them.
class PetActionSequencer {
    
    // MARK: - Core
    let characterNode: SCNNode
    
    // MARK: - Animation Modules
    // Movement
    var walkingAnimation: WalkingAnimation?
    var fastRunAnimation: FastRunAnimation?
    var slowRunAnimation: SlowRunAnimation?
    var jumpOverAnimation: JumpOverAnimation?
    
    // Idle / Status
    var lookAroundAnimation: LookAroundAnimation?
    var idleBreathingAnimation: IdleBreathingAnimation?
    var armStretchAnimation: ArmStretchAnimation?
    var neckStretchAnimation: NeckStretchAnimation?
    var yawnAnimation: YawnAnimation?
    
    // Actions / Gestures (Mouse Behavior)
    var angryEmotionAnimation: AngryEmotionAnimation?
    var doubleHandWaveAnimation: DoubleHandWaveAnimation?
    var oneHandWaveAnimation: OneHandWaveAnimation?
    var pointingGestureAnimation: PointingGestureAnimation?
    var surpriseAnimation: SurpriseAnimation?
    var climbingAnimation: ClimbingAnimation?
    var climbingRopeAnimation: ClimbingRopeAnimation?

    // MARK: - Initialization
    init(characterNode: SCNNode) {
        self.characterNode = characterNode
        setupAllAnimations()
    }
    
    private func setupAllAnimations() {
        // Initialize all animation structs using their static setup methods
        
        // Movement
        self.walkingAnimation = WalkingAnimation.setup(for: characterNode)
        self.fastRunAnimation = FastRunAnimation.setup(for: characterNode)
        self.slowRunAnimation = SlowRunAnimation.setup(for: characterNode)
        self.jumpOverAnimation = JumpOverAnimation.setup(for: characterNode)
        
        // Idle
        self.lookAroundAnimation = LookAroundAnimation.setup(for: characterNode)
        self.idleBreathingAnimation = IdleBreathingAnimation.setup(for: characterNode)
        self.armStretchAnimation = ArmStretchAnimation.setup(for: characterNode)
        self.neckStretchAnimation = NeckStretchAnimation.setup(for: characterNode)
        self.yawnAnimation = YawnAnimation.setup(for: characterNode)
        
        // Actions
        self.angryEmotionAnimation = AngryEmotionAnimation.setup(for: characterNode)
        self.doubleHandWaveAnimation = DoubleHandWaveAnimation.setup(for: characterNode)
        self.oneHandWaveAnimation = OneHandWaveAnimation.setup(for: characterNode)
        self.pointingGestureAnimation = PointingGestureAnimation.setup(for: characterNode)
        self.surpriseAnimation = SurpriseAnimation.setup(for: characterNode)
        
        // Climbing (Note: Climbing usually requires context like a window or rope, but we init the anims here)
        self.climbingAnimation = ClimbingAnimation.setup(for: characterNode)
        self.climbingRopeAnimation = ClimbingRopeAnimation.setup(for: characterNode)
    }
    
    // MARK: - Unified Public API
    // These functions allow you to simply call "sequencer.walk()" without worrying about setup.
    
    func stopAll() {
        walkingAnimation?.stop()
        fastRunAnimation?.stop()
        slowRunAnimation?.stop()
        jumpOverAnimation?.stop()
        lookAroundAnimation?.stop()
        idleBreathingAnimation?.stop()
        armStretchAnimation?.stop()
        neckStretchAnimation?.stop()
        yawnAnimation?.stop()
        angryEmotionAnimation?.stop()
        doubleHandWaveAnimation?.stop()
        oneHandWaveAnimation?.stop()
        pointingGestureAnimation?.stop()
        surpriseAnimation?.stop()
        climbingAnimation?.stop()
        climbingRopeAnimation?.stop()
        
        characterNode.removeAllActions()
    }
    
    // -- Movement --
    
    func walk() {
        stopAll()
        walkingAnimation?.start()
    }
    
    func runFast() {
        stopAll()
        fastRunAnimation?.start()
    }
    
    func runSlow() {
        stopAll()
        slowRunAnimation?.start()
    }
    
    func jump() {
        stopAll()
        jumpOverAnimation?.start()
    }
    
    // -- Idle --
    
    func idleBreathe() {
        stopAll()
        idleBreathingAnimation?.start()
    }
    
    func lookAround() {
        stopAll()
        lookAroundAnimation?.start()
    }
    
    func stretchArms() {
        stopAll()
        armStretchAnimation?.start()
    }
    
    func stretchNeck() {
        stopAll()
        neckStretchAnimation?.start()
    }
    
    func yawn() {
        stopAll()
        yawnAnimation?.start()
    }
    
    // -- Gestures --
    
    func actAngry() {
        stopAll()
        angryEmotionAnimation?.start()
    }
    
    func waveDoubleHand() {
        stopAll()
        doubleHandWaveAnimation?.start()
    }
    
    func waveOneHand() {
        stopAll()
        oneHandWaveAnimation?.start()
    }
    
    func pointGesture() {
        stopAll()
        pointingGestureAnimation?.start()
    }
    
    func actSurprised() {
        stopAll()
        surpriseAnimation?.start()
    }
    
    // MARK: - Demo Sequence
    /// wrapper to create an SCNAction that runs a block code
    private func runBlock(_ block: @escaping () -> Void) -> SCNAction {
        return SCNAction.run { _ in block() }
    }
    
    /// Returns a full demo sequence action that plays every animation one by one.
    /// You can run this on the characterNode: characterNode.runAction(sequencer.getDemoSequence())
    func getDemoSequence() -> SCNAction {
        let waitShort = SCNAction.wait(duration: 2.0)
        let waitMedium = SCNAction.wait(duration: 4.0)
        
        return SCNAction.sequence([
            // 1. Introduction: Wave
            runBlock { print("Demo: Wave (One Hand)"); self.waveOneHand() },
            waitShort,
            
            runBlock { print("Demo: Wave (Double Hand)"); self.waveDoubleHand() },
            waitShort,
            
            // 2. Idle States
            runBlock { print("Demo: Idle Breathing"); self.idleBreathe() },
            waitMedium,
            
            runBlock { print("Demo: Look Around"); self.lookAround() },
            waitMedium,
            
            runBlock { print("Demo: Yawn"); self.yawn() },
            waitShort,
            
            runBlock { print("Demo: Neck Stretch"); self.stretchNeck() },
            waitShort,
            
            runBlock { print("Demo: Arm Stretch"); self.stretchArms() },
            waitShort,
            
            // 3. Emotions
            runBlock { print("Demo: Surprise"); self.actSurprised() },
            waitShort,
            
            runBlock { print("Demo: Angry"); self.actAngry() },
            waitShort,
            
            runBlock { print("Demo: Pointing"); self.pointGesture() },
            waitShort,

            // 4. Movement (Stationary animation playback)
            runBlock { print("Demo: Walk"); self.walk() },
            waitMedium,
            
            runBlock { print("Demo: Slow Run"); self.runSlow() },
            waitMedium,
            
            runBlock { print("Demo: Fast Run"); self.runFast() },
            waitMedium,
            
            runBlock { print("Demo: Jump"); self.jump() },
            waitShort,
            
            // End
            runBlock { print("Demo: Finished"); self.idleBreathe() }
        ])
    }
    
    /// Immediately starts the demo sequence on the character
    func playDemoSequence() {
        print("Starting Pet Animation Demo...")
        characterNode.removeAllActions()
        characterNode.runAction(getDemoSequence())
    }
}
