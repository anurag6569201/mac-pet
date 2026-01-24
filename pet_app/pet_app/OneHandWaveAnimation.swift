import SceneKit

struct OneHandWaveAnimation {
    let characterNode: SCNNode
    let oneWavePlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> OneHandWaveAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.oneHandWaveAnimationFile, to: characterNode, repeatCount: 1)
        return OneHandWaveAnimation(characterNode: characterNode, oneWavePlayers: players)
    }
    
    func start() {
        self.oneWavePlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.oneWavePlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
