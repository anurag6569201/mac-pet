import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pet_state.dart';
import 'sprite_animator.dart';

/// Controller managing pet position, animation, and state transitions
class PetController extends ChangeNotifier {
  // Animation controller for sprite frame timing (12-20 FPS)
  late AnimationController _animationController;
  
  // Current pet state
  PetState _currentState = PetState.idle;
  
  // Pet position (x, y coordinates)
  double _x = 0.0;
  double _y = 0.0;
  
  // Screen dimensions
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;
  
  // Walking speed (pixels per second)
  static const double _walkSpeed = 30.0;
  
  // Timer for state transitions
  Timer? _stateTransitionTimer;
  
  // Time spent in current state
  DateTime? _stateStartTime;
  
  // Idle time tracking for sleep transition
  DateTime? _lastIdleTime;
  
  // Whether the app is currently visible
  bool _isVisible = true;
  
  PetController(TickerProvider vsync) {
    // Initialize animation controller with 15 FPS (0.067s per frame)
    _animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 67 * SpriteConfig.framesPerRow),
    )..repeat();
    
    _animationController.addListener(_onAnimationTick);
  }
  
  /// Initialize pet position on screen
  void initializePosition(double screenWidth, double screenHeight) {
    _screenWidth = screenWidth;
    _screenHeight = screenHeight;
    
    // Position pet on bottom edge, centered horizontally
    _x = screenWidth / 2 - SpriteConfig.frameWidth / 2;
    _y = screenHeight - (screenHeight * 0.1) - SpriteConfig.frameHeight;
    
    _stateStartTime = DateTime.now();
    _lastIdleTime = DateTime.now();
    
    notifyListeners();
  }
  
  /// Update screen dimensions (for multi-monitor support)
  void updateScreenSize(double width, double height) {
    _screenWidth = width;
    _screenHeight = height;
    
    // Keep pet within bounds
    _x = _x.clamp(0.0, _screenWidth - SpriteConfig.frameWidth);
    _y = _y.clamp(0.0, _screenHeight - SpriteConfig.frameHeight);
    
    notifyListeners();
  }
  
  /// Handle animation tick - update position if walking
  void _onAnimationTick() {
    if (!_isVisible) return;
    
    final now = DateTime.now();
    
    // Update position if walking
    if (PetStateMachine.isWalking(_currentState)) {
      final deltaTime = 0.067; // ~15 FPS
      final deltaX = _walkSpeed * deltaTime;
      
      if (_currentState == PetState.walkLeft) {
        _x -= deltaX;
      } else if (_currentState == PetState.walkRight) {
        _x += deltaX;
      }
      
      // Keep pet within screen bounds
      _x = _x.clamp(0.0, _screenWidth - SpriteConfig.frameWidth);
      
      notifyListeners();
    }
    
    // Check for state transitions
    _checkStateTransitions(now);
  }
  
  /// Check and perform state transitions based on timing rules
  void _checkStateTransitions(DateTime now) {
    if (_stateStartTime == null) return;
    
    final timeInState = now.difference(_stateStartTime!).inSeconds;
    
    // State transition rules
    switch (_currentState) {
      case PetState.idle:
        // After 4-8 seconds, randomly walk left or right
        if (timeInState >= 4 && timeInState <= 8) {
          final random = Random();
          if (random.nextDouble() < 0.1) { // 10% chance per tick
            _transitionToState(PetStateMachine.getRandomWalkState());
          }
        }
        // After 30 seconds of idle, go to sleep
        if (timeInState >= 30) {
          _transitionToState(PetState.sleep);
        }
        _lastIdleTime = now;
        break;
        
      case PetState.walkLeft:
      case PetState.walkRight:
        // After 4-8 seconds of walking, go idle
        if (timeInState >= 4 && timeInState <= 8) {
          final random = Random();
          if (random.nextDouble() < 0.1) { // 10% chance per tick
            _transitionToState(PetState.idle);
          }
        }
        // If reached screen edge, turn around
        if (_x <= 0 || _x >= _screenWidth - SpriteConfig.frameWidth) {
          _transitionToState(PetState.idle);
        }
        break;
        
      case PetState.sleep:
        // Sleep state persists until clicked (handled externally)
        break;
    }
  }
  
  /// Transition to a new state
  void _transitionToState(PetState newState) {
    if (_currentState == newState) return;
    
    _currentState = newState;
    _stateStartTime = DateTime.now();
    
    // Reset animation to start of new state
    _animationController.reset();
    _animationController.repeat();
    
    notifyListeners();
  }
  
  /// Handle pet click interaction
  void handleClick() {
    if (_currentState == PetState.sleep) {
      // Wake up from sleep
      _transitionToState(PetState.idle);
    } else if (PetStateMachine.isWalking(_currentState)) {
      // Stop walking and go idle
      _transitionToState(PetState.idle);
    }
  }
  
  /// Set app visibility (pause animation when hidden)
  void setVisible(bool visible) {
    if (_isVisible == visible) return;
    
    _isVisible = visible;
    
    if (visible) {
      _animationController.repeat();
    } else {
      _animationController.stop();
    }
  }
  
  /// Get current animation progress (0.0 to 1.0)
  double get animationProgress => _animationController.value;
  
  /// Get current pet state
  PetState get currentState => _currentState;
  
  /// Get current X position
  double get x => _x;
  
  /// Get current Y position
  double get y => _y;
  
  @override
  void dispose() {
    _stateTransitionTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}
