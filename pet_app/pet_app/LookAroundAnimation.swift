import SceneKit

struct LookAroundAnimation {
    let characterNode: SCNNode
    let lookAroundPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> LookAroundAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.lookAroundAnimationFile, to: characterNode)
        return LookAroundAnimation(characterNode: characterNode, lookAroundPlayers: players)
    }
    
    func start() {
        self.lookAroundPlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.lookAroundPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
