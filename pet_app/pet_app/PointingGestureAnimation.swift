import SceneKit

struct PointingGestureAnimation {
    let characterNode: SCNNode
    let pointingPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> PointingGestureAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.pointingGestureAnimationFile, to: characterNode, repeatCount: 1)
        return PointingGestureAnimation(characterNode: characterNode, pointingPlayers: players)
    }
    
    func start() {
        let speed = 1.0 / sqrt(CGFloat(max(0.05, PetConfig.characterScale.x)))
        self.pointingPlayers.forEach { 
            $0.speed = speed
            $0.play() 
        }
    }
    
    func stop() {
        self.pointingPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
