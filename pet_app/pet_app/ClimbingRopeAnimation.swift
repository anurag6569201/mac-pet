import SceneKit

struct ClimbingRopeAnimation {
    let characterNode: SCNNode
    
    let ropePlayers: [SCNAnimationPlayer]
    
    // Current animation speed multiplier
    private var currentSpeedMultiplier: Float = 1.5
    
    static func setup(for characterNode: SCNNode) -> ClimbingRopeAnimation {
        // Assuming climbing-rope.dae is a loop
        let rope = AnimationHelper.loadAnimations(from: PetConfig.climbingRopeModel, to: characterNode, repeatCount: .infinity)
        
        return ClimbingRopeAnimation(
            characterNode: characterNode,
            ropePlayers: rope
        )
    }
    
    // MARK: - Animation Control
    
    func startClimb(overlap: TimeInterval = 0.2) {
        play(players: ropePlayers, blendInDuration: overlap)
    }
    
    func stopClimb(fadeDuration: TimeInterval = 0.2) {
        stop(players: ropePlayers, blendOutDuration: fadeDuration)
    }
    
    // MARK: - Private Helpers
    
    private func play(players: [SCNAnimationPlayer], blendInDuration: TimeInterval = 0.1) {
        players.forEach { 
            // Reset speed to current target
            $0.speed = CGFloat(currentSpeedMultiplier)
            $0.play() 
        }
    }
    
    private func stop(players: [SCNAnimationPlayer], blendOutDuration: TimeInterval = 0.1) {
        players.forEach { $0.stop(withBlendOutDuration: blendOutDuration) }
    }
    
    func stop() {
        stopClimb()
    }
}
