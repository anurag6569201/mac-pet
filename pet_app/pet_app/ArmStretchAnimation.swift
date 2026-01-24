import SceneKit

struct ArmStretchAnimation {
    let characterNode: SCNNode
    let armStretchPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> ArmStretchAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.armStretchAnimationFile, to: characterNode)
        return ArmStretchAnimation(characterNode: characterNode, armStretchPlayers: players)
    }
    
    func start() {
        self.armStretchPlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.armStretchPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
