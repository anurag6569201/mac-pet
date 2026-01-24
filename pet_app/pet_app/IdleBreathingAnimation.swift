import SceneKit

struct IdleBreathingAnimation {
    let characterNode: SCNNode
    let idleBreathingPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> IdleBreathingAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.idleBreathingAnimationFile, to: characterNode)
        return IdleBreathingAnimation(characterNode: characterNode, idleBreathingPlayers: players)
    }
    
    func start() {
        self.idleBreathingPlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.idleBreathingPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
