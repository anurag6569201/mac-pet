import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pet_controller.dart';
import 'pet_widget.dart';

/// Main app widget with transparent background
class PetApp extends StatefulWidget {
  const PetApp({super.key});
  
  @override
  State<PetApp> createState() => _PetAppState();
}

class _PetAppState extends State<PetApp> with TickerProviderStateMixin {
  PetController? _controller;
  ui.Image? _spriteImage;
  bool _isLoading = true;
  double _screenWidth = 0.0;
  double _screenHeight = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadSpriteImage();
    _updateScreenSize();
  }
  
  /// Load sprite image from assets
  Future<void> _loadSpriteImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/pet_sprite.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      
      setState(() {
        _spriteImage = frame.image;
        _isLoading = false;
      });
      
      // Initialize controller after image is loaded
      if (_spriteImage != null) {
        _controller = PetController(this);
        _controller!.initializePosition(_screenWidth, _screenHeight);
        
        // Listen to app lifecycle to pause animation when hidden
        WidgetsBinding.instance.addObserver(_AppLifecycleObserver(_controller!));
      }
    } catch (e) {
      debugPrint('Error loading sprite image: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Update screen size from window
  void _updateScreenSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mediaQuery = MediaQuery.of(context);
      if (mounted) {
        setState(() {
          _screenWidth = mediaQuery.size.width;
          _screenHeight = mediaQuery.size.height;
        });
        
        if (_controller != null) {
          _controller!.updateScreenSize(_screenWidth, _screenHeight);
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Update screen size on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mediaQuery = MediaQuery.of(context);
      if (mounted && (_screenWidth != mediaQuery.size.width || 
                      _screenHeight != mediaQuery.size.height)) {
        setState(() {
          _screenWidth = mediaQuery.size.width;
          _screenHeight = mediaQuery.size.height;
        });
        
        if (_controller != null) {
          _controller!.updateScreenSize(_screenWidth, _screenHeight);
        }
      }
    });
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mac Pet',
      // Transparent background
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: _screenWidth,
          height: _screenHeight,
          color: Colors.transparent,
          child: _isLoading || _spriteImage == null || _controller == null
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Stack(
                  children: [
                    PetWidget(
                      controller: _controller!,
                      spriteImage: _spriteImage!,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    _spriteImage?.dispose();
    super.dispose();
  }
}

/// Observer for app lifecycle to pause/resume animation
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final PetController controller;
  
  _AppLifecycleObserver(this.controller) {
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        controller.setVisible(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.setVisible(false);
        break;
    }
  }
}
