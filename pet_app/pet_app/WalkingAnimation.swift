import SceneKit

struct WalkingAnimation {
    let characterNode: SCNNode
    let walkingPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> WalkingAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.walkingAnimationFile, to: characterNode)
        return WalkingAnimation(characterNode: characterNode, walkingPlayers: players)
    }
    
    func playAction() -> SCNAction {
        return SCNAction.run { _ in
            self.start()
        }
    }
    
    func stopAction() -> SCNAction {
        return SCNAction.run { _ in
            self.stop()
        }
    }
    
    func start() {
        let speed = 1.0 / sqrt(CGFloat(max(0.05, PetConfig.characterScale.x)))
        self.walkingPlayers.forEach { 
            $0.speed = speed
            $0.play() 
        }
    }
    
    func stop() {
        self.walkingPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
    
    func moveAction(from start: SCNVector3, to end: SCNVector3, speed: CGFloat) -> SCNAction {
        let setupOrientation = SCNAction.run { node in
            node.position = start
            // Face the direction of movement
            if end.x < start.x {
                node.eulerAngles.y = -.pi / 2
            } else {
                node.eulerAngles.y = .pi / 2
            }
        }
        
        let distance = CGFloat(hypot(end.x - start.x, end.y - start.y))
        let duration = distance / speed
        let move = SCNAction.move(to: end, duration: TimeInterval(duration))
        
        return SCNAction.sequence([setupOrientation, move])
    }
    
    func run(from start: SCNVector3, to end: SCNVector3, speed: CGFloat = PetConfig.walkSpeed, completion: (() -> Void)? = nil) {
        let sequence = SCNAction.sequence([
            playAction(),
            moveAction(from: start, to: end, speed: speed),
            stopAction(),
            SCNAction.run { _ in completion?() }
        ])
        characterNode.runAction(sequence)
    }
}
