# Mac Pet - Desktop Pet Application for macOS

A DeskPet-like desktop pet application built with Flutter for macOS. Features a cute animated pet that floats above all windows, walks around, and responds to clicks.

## Features

- **Transparent Always-on-Top Window**: Pet appears above all applications
- **Multi-Space Support**: Pet appears on all macOS Spaces
- **No Dock Icon**: Runs as a background accessory application
- **Sprite-Based Animation**: Smooth frame-based animations at 12-20 FPS
- **State Machine**: Pet has idle, walking, and sleep states
- **Interactive**: Click the pet to wake it up or make it idle
- **Performance Optimized**: <2% CPU usage when idle

## Requirements

- macOS 10.14 or later
- Flutter SDK (latest stable)
- Xcode with macOS development tools

## Setup

1. **Clone or navigate to the project directory:**
   ```bash
   cd mac-pet
   ```

2. **Get Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Add sprite sheet asset:**
   - Place your sprite sheet at `assets/pet_sprite.png`
   - See `assets/README.md` for sprite sheet specifications
   - Required: 512x256 pixels, 4 rows, 8 frames per row, 64x64 pixels per frame

4. **Run the application:**
   ```bash
   flutter run -d macos
   ```

## Sprite Sheet Format

The sprite sheet must be organized as follows:
- **Dimensions**: 512x256 pixels (8 frames × 64px × 4 rows × 64px)
- **Row 0**: Idle animation (8 frames)
- **Row 1**: Walk left animation (8 frames, will be flipped horizontally)
- **Row 2**: Walk right animation (8 frames)
- **Row 3**: Sleep animation (8 frames)

See `assets/README.md` for detailed specifications.

## Project Structure

```
lib/
 ├─ main.dart              # Entry point, platform channel setup
 ├─ pet_app.dart           # Main app widget with transparent background
 ├─ pet_widget.dart        # Pet rendering widget with sprite animation
 ├─ pet_state.dart         # State enum and state machine logic
 ├─ pet_controller.dart    # Animation controller, position, state transitions
 └─ sprite_animator.dart   # Sprite sheet frame calculation

macos/Runner/
 ├─ AppDelegate.swift      # Platform channel setup, window configuration
 ├─ WindowController.swift # NSWindow configuration for transparency/always-on-top
 └─ MainFlutterWindow.swift # Window delegate

assets/
 └─ pet_sprite.png        # Sprite sheet (you need to provide this)
```

## Behavior

### Pet States

- **Idle**: Pet stands still. Transitions to walking after 4-8 seconds.
- **Walk Left/Right**: Pet moves horizontally along the bottom edge. Transitions to idle after 4-8 seconds or when clicked.
- **Sleep**: Pet sleeps after 30 seconds of idle. Wakes up when clicked.

### Interactions

- **Click on pet**: 
  - If sleeping → wakes up (idle)
  - If walking → stops and goes idle

### Window Behavior

- Borderless and transparent
- Always on top of all windows
- Appears on all macOS Spaces
- No dock icon
- Does not steal keyboard focus
- Supports multiple monitors

## Building for Release

```bash
flutter build macos --release
```

The built application will be in `build/macos/Build/Products/Release/`.

## Performance

- **CPU Usage**: <2% when idle
- **Animation Frame Rate**: 12-20 FPS (default 15 FPS)
- **Memory**: Minimal footprint with efficient sprite rendering

## Troubleshooting

### Window doesn't appear on top
- Ensure the app has proper permissions (usually not required)
- Check that `WindowController.swift` is properly configured

### Sprite animation looks wrong
- Verify sprite sheet dimensions match specifications
- Check that frames are aligned correctly (no gaps)
- Ensure PNG has transparent background

### App doesn't launch
- Run `flutter clean` and `flutter pub get`
- Ensure Xcode command line tools are installed
- Check that macOS deployment target is set correctly

## License

This project is provided as-is for educational and personal use.

## Notes

- The app runs as a background accessory (no dock icon) - use Activity Monitor or `killall` to quit
- To quit the app, use: `killall mac_pet` or `pkill -f mac_pet`
- The pet will automatically pause animations when the app is hidden
