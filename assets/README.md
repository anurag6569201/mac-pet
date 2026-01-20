# Sprite Sheet Requirements

## File: `pet_sprite.png`

### Dimensions
- **Frame Size**: 64x64 pixels per frame
- **Frames per Row**: 8 frames
- **Total Rows**: 4 rows
- **Total Dimensions**: 512x256 pixels (8 frames × 64px width, 4 rows × 64px height)

### Layout
The sprite sheet should be organized in 4 horizontal rows:

1. **Row 0 (Top)**: `idle` state
   - 8 frames of the pet standing still/idle animation
   - Frame indices: 0-7

2. **Row 1**: `walk_left` state
   - 8 frames of the pet walking animation (facing right, will be flipped)
   - Frame indices: 0-7

3. **Row 2**: `walk_right` state
   - 8 frames of the pet walking animation (facing right)
   - Frame indices: 0-7

4. **Row 3 (Bottom)**: `sleep` state
   - 8 frames of the pet sleeping animation
   - Frame indices: 0-7

### Animation Notes
- Animation loops continuously for each state
- Frame rate: 12-20 FPS (approximately 15 FPS default)
- Each animation cycle completes in ~0.5 seconds (8 frames × 0.067s per frame)
- The `walk_left` sprite will be horizontally flipped by the renderer

### Example Layout
```
[Frame 0] [Frame 1] [Frame 2] ... [Frame 7]  ← Row 0: idle
[Frame 0] [Frame 1] [Frame 2] ... [Frame 7]  ← Row 1: walk_left
[Frame 0] [Frame 1] [Frame 2] ... [Frame 7]  ← Row 2: walk_right
[Frame 0] [Frame 1] [Frame 2] ... [Frame 7]  ← Row 3: sleep
```

### Creating Your Sprite Sheet
You can use any image editing software (Photoshop, GIMP, Aseprite, etc.) to create the sprite sheet. Ensure:
- All frames are exactly 64x64 pixels
- No gaps between frames
- Consistent alignment across all rows
- Transparent background (PNG with alpha channel)

### Placeholder
If you don't have a sprite sheet yet, you can:
1. Use a placeholder image (solid color rectangles) for testing
2. Create a simple sprite sheet with colored squares representing each frame
3. Download a free sprite sheet from resources like OpenGameArt.org

The app will work with any 512x256 PNG image, but animations will only look correct with properly formatted sprite sheets.
