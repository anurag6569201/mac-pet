/// Pet state enum representing different behavioral states
enum PetState {
  /// Pet is idle, standing still
  idle,
  
  /// Pet is walking left
  walkLeft,
  
  /// Pet is walking right
  walkRight,
  
  /// Pet is sleeping
  sleep,
}

/// State machine logic for pet behavior
class PetStateMachine {
  /// Determines if a state transition is allowed from current state
  static bool canTransitionFrom(PetState current, PetState next) {
    // All states can transition to any other state
    // This allows for flexible behavior
    return true;
  }
  
  /// Gets a random walking direction
  static PetState getRandomWalkState() {
    return DateTime.now().millisecond % 2 == 0 
        ? PetState.walkLeft 
        : PetState.walkRight;
  }
  
  /// Checks if the pet is in a walking state
  static bool isWalking(PetState state) {
    return state == PetState.walkLeft || state == PetState.walkRight;
  }
}
