import SwiftUI
import SceneKit

struct CharacterView: NSViewRepresentable {
    let size: CGSize
    let desktopIndex: Int

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear

        // Initialize Shared Controller (Idempotent)
        // Note: size here is just THIS screen's size. 
        // We might want to pass total world size if needed, but the controller handles that?
        // Actually, PetController.configure expects "size". Previously we passed "fullWidth".
        // Now we are passing "screenSize". This is a behaviour change.
        // If we want the world to be consistent, we need to know the GLOBAL topology.
        // However, standard `PetConfig` logic (startPos etc) depends on size.
        // Let's assume PetController needs to know if it's being configured for the first time.
        // But if we pass just one screen size, `groundPos` might be wrong if it expects full width.
        // Let's fix this in AppDelegate or just pass a hardcoded "World Size" (e.g. screen width * count).
        // Since we don't pass `desktopCount` here easily without changing init... 
        // Actually OverlayView knows `desktopCount`. Let's pass `worldSize` or just handle it.
        // Ideally, PetController configuration should happen once with valid world data.
        // For now, let's keep it simple: configure with "size" (which is screen size), BUT
        // the PetController logic for "groundPos" etc might need adjustment if it was relying on "size" being the full width.
        // Let's look at PetController config usage again.
        // It uses `size` for `startPos`, `groundPos`, `finalPos`.
        // `groundPos = size.width - 200`. If size is 1 screen, ground is on screen 1.
        // If we want the pet to walk across 3 screens, groundPos needs to be at the end of screen 3.
        // So we should indeed pass the "Virtual World Size" to configure.
        // But `makeNSView` is local.
        // Let's rely on `PetController` having been configured correctly OR
        // we update `CharacterView` to take `worldSize`?
        // No, let's stick to the plan: `AppDelegate` knows everything.
        // But here we are calling `PetController.shared.configure(with: size)`.
        // We should ONLY call configure if we know the full size.
        // Let's assume `configure` is called with a "best guess" or we update it to not rely on this local call?
        // Or we pass `desktopCount` to `CharacterView` too so it can compute world size?
        // Better: let `AppDelegate` call `PetController.shared.configure(...)` explicitly before creating windows?
        // Yes, that is cleaner.
        // For now, let's leave the call here but we need to be careful about what `size` is.
        // If we pass `screenSize`, the pet will live in that small world.
        // Let's change `CharacterView` to take `viewSize` and `worldSize`?
        // Simplify: Just don't call `configure` here? Or call it with a calculated world size?
        // Let's just pass `size` as it was (full world size) in previous code?
        // No, `OverlayView` now passes `screenSize`.
        // Let's update `CharacterView` to NOT call `configure` unless it's the main/first one?
        // Actually, safe bet: Update `AppDelegate` to configure the world once.
        // Remove `configure` call from here? Or leave it as a fallback?
        // Let's leave it but we need to solve the size mismatch.
        // Let's update `CharacterView` signature to just `size` (local) and generic.
        
        // Let's create the camera for THIS view.
        let cameraNode = PetController.shared.makeCameraNode(for: desktopIndex, screenSize: size)
        
        // Use Shared Scene
        view.scene = PetController.shared.scene
        
        // Set POV to our local camera
        view.pointOfView = cameraNode
        
        // Custom Lighting is handled in PetController
        view.autoenablesDefaultLighting = false
        view.isPlaying = true
        
        // Connect Delegate for locking hip/root position
        view.delegate = context.coordinator
        
        return view
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, SCNSceneRendererDelegate {
        func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
            // Find the Hips/Root node and lock it to prevent root motion
            // We use the shared scene from the renderer
            if let scene = renderer.scene {
                let root = scene.rootNode
                
                // Search for common root identifiers
                let keywords = ["mixamorig:Hips", "Hips", "Root", "Pelvis", "Armature"]
                
                func lockNode(_ node: SCNNode) {
                    if let name = node.name, keywords.contains(where: { name.contains($0) }) {
                        node.position.x = 0
                        node.position.z = 0
                    }
                    for child in node.childNodes {
                        lockNode(child)
                    }
                }
                
                // Only traverse the first few levels to avoid performance hit
                // or just hit the main skeleton
                for child in root.childNodes {
                    lockNode(child)
                }
            }
        }
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        // We might want to update resizing here if needed, but the camera is effectively static in the shared model
        // If the total size changes dynamically (e.g. plugged in monitor), we might need to reconfigure PetController.
    }
}
