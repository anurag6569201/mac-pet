import Foundation
import SceneKit

/// Climbing state machine for realistic behavior
enum ClimbingState {
    case none
    case starting      // Initial grab and setup
    case steady        // Normal climbing rhythm
    case tired         // Fatigued climbing
    case resting       // Brief pause/rest
    case slipping      // Recovery from slip
    case reaching      // Final reach to top
    case pullingUp     // Pull up over edge
}

/// Physics calculations for realistic climbing behavior
struct ClimbingPhysics {
    
    // MARK: - Speed Calculations
    
    /// Calculate current climb speed based on stamina, height, and state
    /// - Parameters:
    ///   - stamina: Current stamina level (0-100)
    ///   - heightClimbed: Distance already climbed
    ///   - totalHeight: Total height to climb
    ///   - state: Current climbing state
    /// - Returns: Speed multiplier for climbing
    static func calculateSpeed(
        stamina: Float,
        heightClimbed: CGFloat,
        totalHeight: CGFloat,
        state: ClimbingState
    ) -> CGFloat {
        // Base speed from config
        let baseSpeed = PetConfig.climbSpeed
        
        // Progress through climb (0.0 to 1.0)
        let progress = min(1.0, heightClimbed / max(1.0, totalHeight))
        
        // Speed curve: slower at start and end, faster in middle
        // Using a sine curve for natural acceleration/deceleration
        let progressMultiplier: CGFloat
        if progress < 0.2 {
            // Starting phase: accelerating
            progressMultiplier = 0.6 + (progress / 0.2) * 0.4
        } else if progress > 0.8 {
            // Reaching phase: decelerating
            let endProgress = (progress - 0.8) / 0.2
            progressMultiplier = 1.0 - (endProgress * 0.3)
        } else {
            // Steady phase: full speed
            progressMultiplier = 1.0
        }
        
        // Stamina multiplier: affects speed when tired
        let staminaMultiplier: CGFloat
        if stamina > PetConfig.tiredThreshold {
            staminaMultiplier = 1.0
        } else {
            // Linear decrease from tired threshold to 0
            staminaMultiplier = 0.5 + (CGFloat(stamina) / CGFloat(PetConfig.tiredThreshold)) * 0.5
        }
        
        // State-based multiplier
        let stateMultiplier: CGFloat
        switch state {
        case .none:
            stateMultiplier = 0.0
        case .starting:
            stateMultiplier = 0.7
        case .steady:
            stateMultiplier = 1.0
        case .tired:
            stateMultiplier = 0.6
        case .resting:
            stateMultiplier = 0.0
        case .slipping:
            stateMultiplier = -0.5 // Negative for sliding down
        case .reaching:
            stateMultiplier = 0.8
        case .pullingUp:
            stateMultiplier = 0.5
        }
        
        // Height-based difficulty: taller climbs are more challenging
        let heightMultiplier: CGFloat
        if totalHeight < PetConfig.shortClimbHeight {
            heightMultiplier = 1.2 // Short climbs are easier/faster
        } else if totalHeight > PetConfig.tallClimbHeight {
            heightMultiplier = 0.8 // Tall climbs are harder/slower
        } else {
            heightMultiplier = 1.0
        }
        
        return baseSpeed * progressMultiplier * staminaMultiplier * stateMultiplier * heightMultiplier
    }
    
    // MARK: - Slip Mechanics
    
    /// Determine if a slip should occur based on conditions
    /// - Parameters:
    ///   - stamina: Current stamina level
    ///   - deltaTime: Time since last check
    ///   - heightClimbed: Current height climbed
    ///   - totalHeight: Total climb height
    /// - Returns: True if slip should occur
    static func shouldSlip(
        stamina: Float,
        deltaTime: TimeInterval,
        heightClimbed: CGFloat,
        totalHeight: CGFloat
    ) -> Bool {
        // Base slip chance per second
        var slipChance = PetConfig.baseSlipChance
        
        // Increase slip chance when tired
        if stamina < PetConfig.tiredThreshold {
            let tirednessMultiplier = 1.0 + (1.0 - stamina / PetConfig.tiredThreshold) * 2.0
            slipChance *= tirednessMultiplier
        }
        
        // Increase slip chance on very tall climbs (fatigue)
        if totalHeight > PetConfig.tallClimbHeight {
            slipChance *= 1.5
        }
        
        // Increase slip chance in the middle section (less secure grips)
        let progress = heightClimbed / max(1.0, totalHeight)
        if progress > 0.3 && progress < 0.7 {
            slipChance *= 1.3
        }
        
        // Convert to probability for this frame
        let frameSlipChance = slipChance * Float(deltaTime)
        
        return Float.random(in: 0...1) < frameSlipChance
    }
    
    // MARK: - Stamina Management
    
    /// Calculate stamina drain rate based on climbing conditions
    /// - Parameters:
    ///   - climbSpeed: Current climbing speed
    ///   - windowHeight: Total window height
    ///   - state: Current climbing state
    /// - Returns: Stamina drain per second
    static func calculateStaminaDrain(
        climbSpeed: CGFloat,
        windowHeight: CGFloat,
        state: ClimbingState
    ) -> Float {
        // Base drain rate
        var drainRate = PetConfig.staminaDrainRate
        
        // Faster climbing = more stamina drain
        let speedMultiplier = Float(climbSpeed / PetConfig.climbSpeed)
        drainRate *= speedMultiplier
        
        // Taller windows are more exhausting
        if windowHeight > PetConfig.tallClimbHeight {
            drainRate *= 1.5
        }
        
        // State-based drain
        switch state {
        case .resting:
            drainRate = -PetConfig.staminaRecoveryRate // Negative = recovery
        case .slipping:
            drainRate *= 2.0 // Panic uses more energy
        case .pullingUp:
            drainRate *= 1.8 // Pull-ups are exhausting
        case .starting, .reaching:
            drainRate *= 1.2
        default:
            break
        }
        
        return drainRate
    }
    
    /// Determine if the character should rest
    /// - Parameters:
    ///   - stamina: Current stamina level
    ///   - timeClimbing: Total time spent climbing
    ///   - deltaTime: Time since last check
    /// - Returns: True if rest is needed
    static func shouldRest(
        stamina: Float,
        timeClimbing: TimeInterval,
        deltaTime: TimeInterval
    ) -> Bool {
        // Don't rest if stamina is high
        guard stamina < PetConfig.restStaminaThreshold else { return false }
        
        // Don't rest too early in the climb
        guard timeClimbing > 2.0 else { return false }
        
        // Calculate rest probability based on stamina
        let staminaFactor = 1.0 - (stamina / PetConfig.restStaminaThreshold)
        let restChance = PetConfig.restChancePerSecond * staminaFactor
        
        // Convert to frame probability
        let frameRestChance = restChance * Float(deltaTime)
        
        return Float.random(in: 0...1) < frameRestChance
    }
    
    // MARK: - Movement Variation
    
    /// Calculate horizontal sway for realistic movement
    /// - Parameters:
    ///   - timeClimbing: Total time spent climbing
    ///   - stamina: Current stamina level
    ///   - heightClimbed: Current height
    /// - Returns: Horizontal offset for sway
    static func calculateSway(
        timeClimbing: TimeInterval,
        stamina: Float,
        heightClimbed: CGFloat
    ) -> CGFloat {
        // Use sine wave for natural oscillation
        let frequency = 0.3 // Slower oscillations per second for subtle movement
        let baseAmplitude: CGFloat = 0.5 // Much smaller base amplitude for subtle sway
        
        // Increase sway when tired (but keep it subtle)
        let staminaMultiplier = stamina < PetConfig.tiredThreshold 
            ? 1.0 + (1.0 - CGFloat(stamina) / CGFloat(PetConfig.tiredThreshold)) * 0.3
            : 1.0
        
        // Very slight increase in sway at greater heights (less stable)
        let heightMultiplier = 1.0 + (heightClimbed / 2000.0) * 0.2
        
        let amplitude = baseAmplitude * staminaMultiplier * heightMultiplier
        
        return sin(timeClimbing * frequency * 2.0 * .pi) * amplitude
    }
    
    /// Calculate micro-adjustment for grip repositioning
    /// - Returns: Small random offset for natural movement
    static func calculateMicroAdjustment() -> CGFloat {
        return CGFloat.random(in: -PetConfig.microAdjustmentRange...PetConfig.microAdjustmentRange)
    }
    
    // MARK: - State Transitions
    
    /// Determine next climbing state based on conditions
    /// - Parameters:
    ///   - currentState: Current climbing state
    ///   - stamina: Current stamina level
    ///   - progress: Climb progress (0-1)
    ///   - isSlipping: Whether a slip is occurring
    ///   - shouldRest: Whether rest is needed
    /// - Returns: Next state to transition to
    static func determineNextState(
        currentState: ClimbingState,
        stamina: Float,
        progress: CGFloat,
        isSlipping: Bool,
        shouldRest: Bool
    ) -> ClimbingState {
        // Handle slip events (highest priority)
        if isSlipping && currentState != .slipping {
            return .slipping
        }
        
        // Recover from slip
        if currentState == .slipping {
            return stamina > PetConfig.tiredThreshold ? .steady : .tired
        }
        
        // Handle rest
        if shouldRest && currentState != .resting {
            return .resting
        }
        
        // Resume from rest
        if currentState == .resting {
            return stamina > PetConfig.tiredThreshold ? .steady : .tired
        }
        
        // Progress-based transitions
        if progress < 0.1 && currentState == .starting {
            return stamina > PetConfig.tiredThreshold ? .steady : .tired
        }
        
        if progress > 0.9 && currentState != .reaching && currentState != .pullingUp {
            return .reaching
        }
        
        if progress >= 0.98 && currentState == .reaching {
            return .pullingUp
        }
        
        // Stamina-based transitions
        if stamina < PetConfig.tiredThreshold && currentState == .steady {
            return .tired
        }
        
        if stamina > PetConfig.tiredThreshold * 1.5 && currentState == .tired {
            return .steady
        }
        
        // Default: maintain current state
        return currentState
    }
    
    /// Get rest duration based on stamina level
    /// - Parameter stamina: Current stamina level
    /// - Returns: Rest duration in seconds
    static func getRestDuration(stamina: Float) -> TimeInterval {
        // Lower stamina = longer rest
        let staminaFactor = 1.0 - Double(stamina / PetConfig.maxStamina)
        let range = PetConfig.restDurationMax - PetConfig.restDurationMin
        return PetConfig.restDurationMin + (range * staminaFactor)
    }
}
