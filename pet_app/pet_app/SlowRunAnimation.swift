import SceneKit

struct SlowRunAnimation {
    let characterNode: SCNNode
    let runningPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> SlowRunAnimation {
        let players = AnimationHelper.loadAnimations(from: PetConfig.slowRunAnimationFile, to: characterNode)
        return SlowRunAnimation(characterNode: characterNode, runningPlayers: players)
    }
    
    func start() {
        let speed = 1.0 / sqrt(CGFloat(max(0.05, PetConfig.characterScale.x)))
        self.runningPlayers.forEach { 
            $0.speed = speed
            $0.play() 
        }
    }
    
    func stop() {
        self.runningPlayers.forEach { $0.stop(withBlendOutDuration: PetConfig.transitionDuration) }
    }
}
