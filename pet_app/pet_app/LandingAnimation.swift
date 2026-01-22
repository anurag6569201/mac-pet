import SceneKit

struct LandingAnimation {
    let characterNode: SCNNode
    let landingPlayers: [SCNAnimationPlayer]
    let walkingAnimation: WalkingAnimation
    
    static func setup(for characterNode: SCNNode, walkingAnimation: WalkingAnimation) -> LandingAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.landingAnimationFile, to: characterNode, repeatCount: 1)
        return LandingAnimation(characterNode: characterNode, landingPlayers: players, walkingAnimation: walkingAnimation)
    }
    
    func run(startPos: SCNVector3, groundPos: SCNVector3, finalPos: SCNVector3, walkSpeed: CGFloat = PetConfig.walkSpeed, completion: (() -> Void)? = nil) {
        characterNode.position = startPos
        characterNode.eulerAngles.y = -.pi / 2
        
        let startLandingAnim = SCNAction.run { _ in
            self.landingPlayers.forEach { $0.play() }
        }
        
        // Falling Phase: Fast fall
        let fallAction = SCNAction.move(to: groundPos, duration: PetConfig.fallDuration)
        fallAction.timingMode = .easeIn
        
        // Total Landing Animation is 2.5s based on landing.dae
        // Falling hits ground at 1.0s. Character stands up from 1.0s to 2.5s.
        let standUpWait = SCNAction.wait(duration: PetConfig.standUpDuration) 
        
        let startWalkingOverlap = walkingAnimation.playAction()
        
        let overlapWait = SCNAction.wait(duration: PetConfig.overlapDuration) 
        
        let stopLanding = SCNAction.run { _ in
            self.landingPlayers.forEach { $0.stop() }
        }
        
        // Define the walking part using the modular run method
        let startWalkingMove = SCNAction.run { _ in
            self.walkingAnimation.run(from: SCNVector3(groundPos.x - 100, groundPos.y, groundPos.z), to: finalPos, speed: walkSpeed, completion: completion)
        }
        
        let sequence = SCNAction.sequence([
            startLandingAnim,
            fallAction,         // 0s -> 1.0s
            standUpWait,        // 1.0s -> 2.0s
            startWalkingOverlap,// 2.0s starts playing animation (in place)
            overlapWait,        // 2.0s -> 2.5s
            stopLanding,        // 2.5s stops landing player
            startWalkingMove    // 2.5s starts actual horizontal movement
        ])
        
        characterNode.runAction(sequence)
    }
}

