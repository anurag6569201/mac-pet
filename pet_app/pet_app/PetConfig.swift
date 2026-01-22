import SceneKit

struct PetConfig {
    // MARK: - Character Settings
    static let characterScale = SCNVector3(0.8, 0.8, 0.8)
    
    // MARK: - Animation Speeds & Durations
    static let walkSpeed: CGFloat = 180.0
    static let fallDuration: TimeInterval = 1.0
    static let standUpDuration: TimeInterval = 1.0
    static let overlapDuration: TimeInterval = 0.5
    
    // MARK: - Positions
    static func startPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(size.width + 100, size.height + 200, 0)
    }
    
    static func groundPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(size.width - 200, 50, 0)
    }
    
    static func finalPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(50, 50, 0)
    }
    
    // MARK: - Asset Paths
    static let characterModel = "Assets.scnassets/character.dae"
    static let diffuseTexture = "diffuse.png"
    static let assetsDirectory = "Assets.scnassets"
    static let walkingAnimationFile = "normal-walking.dae"
    static let landingAnimationFile = "landing.dae"
    static let doorAnimationFile = "opening-closing-door.dae"
}
