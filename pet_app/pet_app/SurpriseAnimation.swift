import SceneKit

struct SurpriseAnimation {
    let characterNode: SCNNode
    let surprisePlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> SurpriseAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.surpriseAnimationFile, to: characterNode, repeatCount: 1)
        return SurpriseAnimation(characterNode: characterNode, surprisePlayers: players)
    }
    
    func start() {
        self.surprisePlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.surprisePlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
