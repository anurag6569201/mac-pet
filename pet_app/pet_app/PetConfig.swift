import SceneKit

struct PetConfig {
    // MARK: - Character Settings
    static let characterScale = SCNVector3(0.8, 0.8, 0.8)
    
    // MARK: - Animation Speeds & Durations
    static let walkSpeed: CGFloat = 130.0
    static let runSpeed: CGFloat = 550.0
    static let slowRunSpeed: CGFloat = 380.0

    static let fallDuration: TimeInterval = 1.0
    static let standUpDuration: TimeInterval = 1.0
    static let overlapDuration: TimeInterval = 0.5
    static let transitionDuration: CGFloat = 0.3
    
    // MARK: - Positions
    static func startPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(size.width + 100, size.height + 200, 0)
    }
    
    static func groundPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(size.width - 200, 0, 0)
    }
    
    static func finalPos(for size: CGSize) -> SCNVector3 {
        return SCNVector3(50, 0, 0)
    }
    
    // MARK: - Asset Paths
    static let characterModel = "Assets.scnassets/character.dae"
    static let diffuseTexture = "diffuse.png"
    static let assetsDirectory = "Assets.scnassets"
    static let walkingAnimationFile = "normal-walking.dae"
    static let landingAnimationFile = "landing.dae"
    static let doorAnimationFile = "opening-closing-door.dae"
    static let fastRunAnimationFile = "fast-run.dae"
    static let slowRunAnimationFile = "slow-run.dae"
}
