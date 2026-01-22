import SceneKit

enum AnimationHelper {
    static func loadAnimations(from fileName: String, to targetRoot: SCNNode, repeatCount: Float = .infinity) -> [SCNAnimationPlayer] {
        var players: [SCNAnimationPlayer] = []
        if let animationScene = SCNScene(named: "Assets.scnassets/\(fileName)") {
            func addAnimationsRecursive(from sourceNode: SCNNode) {
                for key in sourceNode.animationKeys {
                    if let player = sourceNode.animationPlayer(forKey: key) {
                        let targetNode = targetRoot.childNode(withName: sourceNode.name ?? "", recursively: true) ?? targetRoot
                        let newPlayer = SCNAnimationPlayer(animation: player.animation)
                        newPlayer.animation.repeatCount = CGFloat(repeatCount)
                        newPlayer.animation.isRemovedOnCompletion = false
                        
                        newPlayer.stop() 
                        targetNode.addAnimationPlayer(newPlayer, forKey: "\(fileName)_\(key)")
                        players.append(newPlayer)
                    }
                }
                for child in sourceNode.childNodes {
                    addAnimationsRecursive(from: child)
                }
            }
            addAnimationsRecursive(from: animationScene.rootNode)
        }
        return players
    }
}
