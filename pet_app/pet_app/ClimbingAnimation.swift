import SceneKit

struct ClimbingAnimation {
    let characterNode: SCNNode
    
    let startPlayers: [SCNAnimationPlayer]
    let midPlayers: [SCNAnimationPlayer]
    let endPlayers: [SCNAnimationPlayer]
    
    // Current animation speed multiplier
    private var currentSpeedMultiplier: Float = 1.0
    
    static func setup(for characterNode: SCNNode) -> ClimbingAnimation {
        let start = AnimationHelper.loadAnimations(from: PetConfig.climbingStartAnimationFile, to: characterNode, repeatCount: 1)
        let mid = AnimationHelper.loadAnimations(from: PetConfig.climbingMidAnimationFile, to: characterNode, repeatCount: .infinity)
        let end = AnimationHelper.loadAnimations(from: PetConfig.climbingEndAnimationFile, to: characterNode, repeatCount: 1)
        
        return ClimbingAnimation(
            characterNode: characterNode,
            startPlayers: start,
            midPlayers: mid,
            endPlayers: end
        )
    }
    
    // MARK: - Basic Animation Control
    
    func startClimb(overlap: TimeInterval = 0.2, completion: @escaping () -> Void) {
        // Play start animation
        play(players: startPlayers)
        
        // Schedule completion after duration minus overlap
        if let duration = startPlayers.first?.animation.duration {
            let delay = max(0, duration - overlap)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // We don't stop startPlayers here immediately if we want them to blend out
                // typically the loop starts, and we let the start animation finish naturally or fade out
                // But since 'start' is non-looping, it effectively stops on its own visual end? 
                // Actually, for smoothness, we might want to fade it out as loop fades in.
                
                self.stop(players: self.startPlayers, blendOutDuration: overlap)
                completion()
            }
        } else {
            completion()
        }
    }
    
    func startLoop() {
        play(players: midPlayers)
    }
    
    func stopLoop(fadeDuration: TimeInterval = 0.2) {
        stop(players: midPlayers, blendOutDuration: fadeDuration)
    }
    
    func endClimb(blendInDuration: TimeInterval = 0.2, completion: @escaping () -> Void) {
        // Play end with blend in
        play(players: endPlayers, blendInDuration: blendInDuration)
        
        if let duration = endPlayers.first?.animation.duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.stop(players: self.endPlayers, blendOutDuration: 0.1)
                completion()
            }
        } else {
            completion()
        }
    }
    
    // MARK: - Enhanced Physics-Based Control
    
    /// Update animation speed based on climbing state and stamina
    /// - Parameter speedMultiplier: Speed multiplier (1.0 = normal, 0.5 = half speed, etc.)
    mutating func updateClimbSpeed(multiplier: Float) {
        currentSpeedMultiplier = max(0.1, min(2.0, multiplier)) // Clamp between 0.1 and 2.0
        
        // Apply speed to all active players
        midPlayers.forEach { player in
            player.speed = CGFloat(currentSpeedMultiplier)
        }
    }
    
    /// Play slip recovery animation (character slides down slightly then recovers)
    /// - Parameter completion: Called when recovery is complete
    func playSlipRecovery(completion: @escaping () -> Void) {
        // Temporarily speed up animation to show panic/recovery
        midPlayers.forEach { player in
            player.speed = 1.5
        }
        
        // Return to normal speed after recovery time
        DispatchQueue.main.asyncAfter(deadline: .now() + PetConfig.slipRecoveryTime) {
            self.midPlayers.forEach { player in
                player.speed = CGFloat(self.currentSpeedMultiplier)
            }
            completion()
        }
    }
    
    /// Play rest animation (pause climbing, character hangs and catches breath)
    /// - Parameters:
    ///   - duration: How long to rest
    ///   - completion: Called when rest is complete
    func playRest(duration: TimeInterval, completion: @escaping () -> Void) {
        // Slow down animation significantly (almost paused)
        midPlayers.forEach { player in
            player.speed = 0.2 // Very slow breathing/idle motion
        }
        
        // Resume normal speed after rest
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.midPlayers.forEach { player in
                player.speed = CGFloat(self.currentSpeedMultiplier)
            }
            completion()
        }
    }
    
    /// Adjust animation for tired state (slower, heavier movements)
    func setTiredState(isTired: Bool) {
        if isTired {
            // Slower, more labored animation
            midPlayers.forEach { player in
                player.speed = CGFloat(currentSpeedMultiplier * 0.7)
            }
        } else {
            // Normal speed
            midPlayers.forEach { player in
                player.speed = CGFloat(currentSpeedMultiplier)
            }
        }
    }
    
    /// Play reaching animation (stretching to reach top)
    /// - Parameter completion: Called when reach is complete
    func playReaching(completion: @escaping () -> Void) {
        // Slow down for careful reaching
        midPlayers.forEach { player in
            player.speed = CGFloat(currentSpeedMultiplier * 0.6)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion()
        }
    }
    
    /// Play pull-up animation (final effort to get over edge)
    /// - Parameter completion: Called when pull-up is complete
    func playPullUp(completion: @escaping () -> Void) {
        // Use end animation for pull-up
        stopLoop()
        endClimb(completion: completion)
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
    
    /// Stop all animations immediately
    func stopAll() {
        stop(players: startPlayers)
        stop(players: midPlayers)
        stop(players: endPlayers)
    }
}
