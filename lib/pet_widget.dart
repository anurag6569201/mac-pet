import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pet_controller.dart';
import 'pet_state.dart';
import 'sprite_animator.dart';

/// Widget that renders the pet with sprite animation
class PetWidget extends StatefulWidget {
  final PetController controller;
  final ui.Image spriteImage;
  
  const PetWidget({
    super.key,
    required this.controller,
    required this.spriteImage,
  });
  
  @override
  State<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends State<PetWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }
  
  void _onControllerUpdate() {
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Positioned(
        left: widget.controller.x,
        top: widget.controller.y,
        child: GestureDetector(
          onTap: () {
            widget.controller.handleClick();
          },
          child: CustomPaint(
            size: Size(
              SpriteConfig.frameWidth,
              SpriteConfig.frameHeight,
            ),
            painter: _PetPainter(
              controller: widget.controller,
              spriteImage: widget.spriteImage,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for efficient sprite rendering
class _PetPainter extends CustomPainter {
  final PetController controller;
  final ui.Image spriteImage;
  
  _PetPainter({
    required this.controller,
    required this.spriteImage,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final state = controller.currentState;
    final progress = controller.animationProgress;
    
    // Get source rectangle from sprite sheet
    final sourceRect = SpriteAnimator.getSourceRect(state, progress);
    
    // Destination rectangle (full widget size)
    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Check if we need to flip horizontally
    final shouldFlip = SpriteAnimator.shouldFlipHorizontally(state);
    
    if (shouldFlip) {
      // Flip horizontally by scaling and translating
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1.0, 1.0);
      canvas.drawImageRect(
        spriteImage,
        sourceRect,
        destRect,
        Paint(),
      );
      canvas.restore();
    } else {
      canvas.drawImageRect(
        spriteImage,
        sourceRect,
        destRect,
        Paint(),
      );
    }
  }
  
  @override
  bool shouldRepaint(_PetPainter oldDelegate) {
    // Repaint when state or animation progress changes
    return oldDelegate.controller.currentState != controller.currentState ||
           oldDelegate.controller.animationProgress != controller.animationProgress ||
           oldDelegate.controller.x != controller.x ||
           oldDelegate.controller.y != controller.y;
  }
}
