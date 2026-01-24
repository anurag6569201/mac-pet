import SceneKit

struct DoubleHandWaveAnimation {
    let characterNode: SCNNode
    let doubleWavePlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> DoubleHandWaveAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.doubleHandWaveAnimationFile, to: characterNode, repeatCount: 1)
        return DoubleHandWaveAnimation(characterNode: characterNode, doubleWavePlayers: players)
    }
    
    func start() {
        self.doubleWavePlayers.forEach { $0.play() }
    }
    
    func stop() {
        self.doubleWavePlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
