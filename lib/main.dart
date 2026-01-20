import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pet_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure window via platform channel
  _configureWindow();
  
  runApp(const PetApp());
}

/// Configure native macOS window properties via platform channel
Future<void> _configureWindow() async {
  const platform = MethodChannel('com.macpet.window/config');
  
  try {
    // Call Swift method to configure window
    await platform.invokeMethod('configureWindow');
  } on PlatformException catch (e) {
    debugPrint('Failed to configure window: ${e.message}');
  }
}
