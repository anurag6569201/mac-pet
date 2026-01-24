import SceneKit

struct NeckStretchAnimation {
    let characterNode: SCNNode
    let neckStretchPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> NeckStretchAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.neckStretchAnimationFile, to: characterNode)
        return NeckStretchAnimation(characterNode: characterNode, neckStretchPlayers: players)
    }
    
    func start() {
        self.neckStretchPlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.neckStretchPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
