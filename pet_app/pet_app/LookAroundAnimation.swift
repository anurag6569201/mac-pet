import SceneKit

struct LookAroundAnimation {
    let characterNode: SCNNode
    let lookAroundPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> LookAroundAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.lookAroundAnimationFile, to: characterNode)
        return LookAroundAnimation(characterNode: characterNode, lookAroundPlayers: players)
    }
    
    func start() {
        let speed = 1.0 / sqrt(CGFloat(max(0.05, PetConfig.characterScale.x)))
        self.lookAroundPlayers.forEach { 
            $0.speed = speed
            $0.play() 
        }
    }
    
    func stop() {
        self.lookAroundPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
