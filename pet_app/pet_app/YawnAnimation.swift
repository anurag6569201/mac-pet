import SceneKit

struct YawnAnimation {
    let characterNode: SCNNode
    let yawnPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> YawnAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.yawnAnimationFile, to: characterNode)
        return YawnAnimation(characterNode: characterNode, yawnPlayers: players)
    }
    
    func start() {
        self.yawnPlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.yawnPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
