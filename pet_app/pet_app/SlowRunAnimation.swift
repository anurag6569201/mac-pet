import SceneKit

struct SlowRunAnimation {
    let characterNode: SCNNode
    let runningPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> SlowRunAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.slowRunAnimationFile, to: characterNode)
        return SlowRunAnimation(characterNode: characterNode, runningPlayers: players)
    }
    
    func start() {
        self.runningPlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.runningPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
