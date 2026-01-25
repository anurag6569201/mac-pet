import SceneKit

struct JumpOverAnimation {
    let characterNode: SCNNode
    let jumpOverPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> JumpOverAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.jumpOverAnimationFile, to: characterNode)
        return JumpOverAnimation(characterNode: characterNode, jumpOverPlayers: players)
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
        self.jumpOverPlayers.forEach { $0.play() }
    }
    
    func stop(immediate: Bool = false) {
        let duration = immediate ? 0 : PetConfig.transitionDuration
        self.jumpOverPlayers.forEach { $0.stop(withBlendOutDuration: duration) }
    }
}
