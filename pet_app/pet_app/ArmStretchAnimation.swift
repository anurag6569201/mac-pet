import SceneKit

struct ArmStretchAnimation {
    let characterNode: SCNNode
    let armStretchPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> ArmStretchAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.armStretchAnimationFile, to: characterNode)
        return ArmStretchAnimation(characterNode: characterNode, armStretchPlayers: players)
    }
    
    func start() {
        let speed = 1.0 / sqrt(CGFloat(max(0.05, PetConfig.characterScale.x)))
        self.armStretchPlayers.forEach { 
            $0.speed = speed
            $0.play() 
        }
    }
    
    func stop() {
        self.armStretchPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
