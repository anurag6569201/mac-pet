import SceneKit

struct PointingGestureAnimation {
    let characterNode: SCNNode
    let pointingPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> PointingGestureAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.pointingGestureAnimationFile, to: characterNode, repeatCount: 1)
        return PointingGestureAnimation(characterNode: characterNode, pointingPlayers: players)
    }
    
    func start() {
        self.pointingPlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.pointingPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
