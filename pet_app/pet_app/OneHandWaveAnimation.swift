import SceneKit

struct OneHandWaveAnimation {
    let characterNode: SCNNode
    let oneWavePlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> OneHandWaveAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.oneHandWaveAnimationFile, to: characterNode, repeatCount: 1)
        return OneHandWaveAnimation(characterNode: characterNode, oneWavePlayers: players)
    }
    
    func start() {
        let speed = 1.0 / sqrt(CGFloat(max(0.05, PetConfig.characterScale.x)))
        self.oneWavePlayers.forEach { 
            $0.speed = speed
            $0.play() 
        }
    }
    
    func stop() {
        self.oneWavePlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
