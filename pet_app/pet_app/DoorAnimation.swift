import SceneKit

struct DoorAnimation {
    let characterNode: SCNNode
    let doorPlayers: [SCNAnimationPlayer]
    
    static func setup(for characterNode: SCNNode) -> DoorAnimation {
        // We set repeatCount to 1 because we want the door to open and close once
        let players = AnimationHelper.loadAnimations(from: PetConfig.doorAnimationFile, to: characterNode, repeatCount: 1)
        return DoorAnimation(characterNode: characterNode, doorPlayers: players)
    }
    
    func playAction() -> SCNAction {
        return SCNAction.run { _ in
            self.doorPlayers.forEach { $0.play() }
        }
    }
    
    func stopAction() -> SCNAction {
        return SCNAction.run { _ in
            self.doorPlayers.forEach { $0.stop() }
        }
    }
    
    func run(completion: (() -> Void)? = nil) {
        // Find the longest animation duration among all players to know when it finishes
        let maxDuration = doorPlayers.map { player in
            TimeInterval(player.animation.duration)
        }.max() ?? 1.0
        
        let sequence = SCNAction.sequence([
            playAction(),
            SCNAction.wait(duration: maxDuration),
            stopAction(),
            SCNAction.run { _ in completion?() }
        ])
        characterNode.runAction(sequence)
    }
}
