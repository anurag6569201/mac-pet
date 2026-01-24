import SceneKit

struct FastRunAnimation {
    let characterNode: SCNNode
    let runningPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> FastRunAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.fastRunAnimationFile, to: characterNode)
        return FastRunAnimation(characterNode: characterNode, runningPlayers: players)
    }
    
    func start() {
        self.runningPlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.runningPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
