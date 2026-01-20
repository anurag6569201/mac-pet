import 'package:flutter/material.dart';
import 'pet_state.dart';

/// Sprite sheet configuration
/// Assumes sprite sheet with 4 rows (idle, walk_left, walk_right, sleep)
/// Each row has 8 frames, each frame is 64x64 pixels
class SpriteConfig {
  static const int framesPerRow = 8;
  static const double frameWidth = 64.0;
  static const double frameHeight = 64.0;
  static const int totalRows = 4;
}

/// Handles sprite sheet animation calculations
class SpriteAnimator {
  /// Maps pet state to sprite sheet row index
  /// Row 0: idle, Row 1: walk_left, Row 2: walk_right, Row 3: sleep
  static int getRowIndex(PetState state) {
    switch (state) {
      case PetState.idle:
        return 0;
      case PetState.walkLeft:
        return 1;
      case PetState.walkRight:
        return 2;
      case PetState.sleep:
        return 3;
    }
  }
  
  /// Calculates the current frame index based on animation progress
  /// Progress should be between 0.0 and 1.0
  static int getFrameIndex(double progress) {
    // Clamp progress to [0, 1]
    final clampedProgress = progress.clamp(0.0, 1.0);
    // Calculate frame index (0 to framesPerRow - 1)
    final frameIndex = (clampedProgress * SpriteConfig.framesPerRow).floor();
    return frameIndex.clamp(0, SpriteConfig.framesPerRow - 1);
  }
  
  /// Gets the source rectangle for the current sprite frame
  static Rect getSourceRect(PetState state, double animationProgress) {
    final rowIndex = getRowIndex(state);
    final frameIndex = getFrameIndex(animationProgress);
    
    final x = frameIndex * SpriteConfig.frameWidth;
    final y = rowIndex * SpriteConfig.frameHeight;
    
    return Rect.fromLTWH(
      x,
      y,
      SpriteConfig.frameWidth,
      SpriteConfig.frameHeight,
    );
  }
  
  /// Determines if sprite should be flipped horizontally
  /// For walk_left, we flip the walk_right sprite
  static bool shouldFlipHorizontally(PetState state) {
    return state == PetState.walkLeft;
  }
}
