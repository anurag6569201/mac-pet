import SceneKit

struct AngryEmotionAnimation {
    let characterNode: SCNNode
    let angryPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> AngryEmotionAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.angryEmotionAnimationFile, to: characterNode, repeatCount: 1)
        return AngryEmotionAnimation(characterNode: characterNode, angryPlayers: players)
    }
    
    func start() {
        let speed = 1.0 / sqrt(CGFloat(max(0.05, PetConfig.characterScale.x)))
        self.angryPlayers.forEach { 
            $0.speed = speed
            $0.play() 
        }
    }
    
    func stop() {
        self.angryPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
