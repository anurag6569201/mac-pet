//
//  CharacterView.swift
//  mac-pet
//
//  SceneKit view for displaying rigged 3D character with walking animation
//

import SwiftUI
import SceneKit
import AppKit
import ModelIO
import SceneKit.ModelIO

struct CharacterView: NSViewRepresentable {
    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = createScene()
        scnView.allowsCameraControl = false
        scnView.backgroundColor = .clear
        scnView.autoenablesDefaultLighting = true
        
        // Transparency is handled via backgroundColor = .clear and scene.background.contents
        
        return scnView
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        // No updates needed
    }
    
    private func findResource(name: String, extension ext: String) -> URL? {
        let fileName = "\(name).\(ext)"
        
        // 1. Try main bundle (standard approach)
        if let mainURL = Bundle.main.url(forResource: name, withExtension: ext) {
            print("Found resource in main bundle: \(mainURL.path)")
            return mainURL
        }
        
        // 2. Try with resources/ prefix
        if let resourcesURL = Bundle.main.url(forResource: "resources/\(name)", withExtension: ext) {
            print("Found resource with resources/ prefix: \(resourcesURL.path)")
            return resourcesURL
        }
        
        // 3. Try constructing path relative to executable (for SPM/Xcode builds)
        if let executablePath = Bundle.main.executablePath {
            let executableURL = URL(fileURLWithPath: executablePath)
            let executableDir = executableURL.deletingLastPathComponent()
            
            // Try the SPM bundle (mac-pet_mac-pet.bundle)
            let bundlePath = executableDir.appendingPathComponent("mac-pet_mac-pet.bundle")
            if let spmBundle = Bundle(path: bundlePath.path),
               let bundleURL = spmBundle.url(forResource: name, withExtension: ext) {
                print("Found resource in SPM bundle: \(bundleURL.path)")
                return bundleURL
            }
            
            // Try directly in executable directory
            let directURL = executableDir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: directURL.path) {
                print("Found resource in executable directory: \(directURL.path)")
                return directURL
            }
            
            // Try in resources subdirectory of executable directory
            let resourcesURL = executableDir.appendingPathComponent("resources").appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: resourcesURL.path) {
                print("Found resource in executable/resources: \(resourcesURL.path)")
                return resourcesURL
            }
            
            // List contents of executable directory for debugging
            print("Contents of executable directory (\(executableDir.path)):")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: executableDir.path) {
                for item in contents {
                    print("  - \(item)")
                }
            }
        }
        
        // 4. Try source directory (for development - check common locations)
        let possibleSourcePaths = [
            "/Users/anuragsingh/Documents/GitHub/mac-pet/mac-pet/resources/\(fileName)",
            FileManager.default.currentDirectoryPath + "/mac-pet/resources/\(fileName)",
            FileManager.default.currentDirectoryPath + "/resources/\(fileName)"
        ]
        
        for sourcePath in possibleSourcePaths {
            if FileManager.default.fileExists(atPath: sourcePath) {
                print("Found resource in source directory: \(sourcePath)")
                return URL(fileURLWithPath: sourcePath)
            }
        }
        
        // 5. Try relative to Package.swift location (workspace root)
        if let packagePath = findPackageRoot() {
            let packageResourceURL = packagePath
                .appendingPathComponent("mac-pet")
                .appendingPathComponent("resources")
                .appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: packageResourceURL.path) {
                print("Found resource in package root: \(packageResourceURL.path)")
                return packageResourceURL
            }
        }
        
        return nil
    }
    
    private func findPackageRoot() -> URL? {
        // Try to find the package root by looking for Package.swift
        var currentPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        // Also try executable's parent directories
        if let executablePath = Bundle.main.executablePath {
            currentPath = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
        }
        
        // Walk up the directory tree looking for Package.swift
        var searchPath = currentPath
        for _ in 0..<10 { // Limit to 10 levels up
            let packageSwift = searchPath.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageSwift.path) {
                return searchPath
            }
            guard searchPath.path != "/" else { break }
            searchPath = searchPath.deletingLastPathComponent()
        }
        
        // Fallback: try the known workspace path
        let knownPath = URL(fileURLWithPath: "/Users/anuragsingh/Documents/GitHub/mac-pet")
        if FileManager.default.fileExists(atPath: knownPath.appendingPathComponent("Package.swift").path) {
            return knownPath
        }
        
        return nil
    }
    
    private func createScene() -> SCNScene {
        // Create empty scene with transparent background
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        
        // Try loading character model in order of preference:
        // 1. USDZ (best support)
        // 2. DAE (Collada - good support)
        // 3. SCN (SceneKit native)
        // 4. FBX (limited support)
        
        let supportedFormats = ["usdz", "dae", "scn", "fbx"]
        var characterURL: URL? = nil
        var loadedFormat: String = ""
        
        for format in supportedFormats {
            if let url = findResource(name: "character", extension: format) {
                characterURL = url
                loadedFormat = format
                print("Found character.\(format) at: \(url.path)")
                break
            }
        }
        
        guard let url = characterURL else {
            print("Error: Could not find character model in any supported format")
            print("Supported formats: \(supportedFormats.joined(separator: ", "))")
            print("Please convert your FBX file to USDZ or DAE format.")
            print("")
            print("=== HOW TO CONVERT FBX TO USDZ ===")
            print("Option 1: Use Apple's Reality Converter (free)")
            print("  - Download from Apple Developer website")
            print("  - Open your .fbx file")
            print("  - Export as .usdz")
            print("")
            print("Option 2: Use Blender (free)")
            print("  - Import FBX into Blender")
            print("  - Export as DAE (Collada) or USD")
            print("")
            print("Option 3: Online converters")
            print("  - Convert FBX to GLTF, then to USDZ")
            print("")
            print("Creating placeholder character for testing...")
            return createPlaceholderScene(scene: scene)
        }
        
        return loadCharacterFromURL(url, format: loadedFormat, scene: scene)
    }
    
    private func createPlaceholderScene(scene: SCNScene) -> SCNScene {
        // Create a simple animated placeholder to test the rendering pipeline
        
        // Create a simple humanoid shape
        let bodyNode = SCNNode()
        bodyNode.name = "PlaceholderCharacter"
        
        // Body (capsule)
        let body = SCNCapsule(capRadius: 0.3, height: 1.2)
        body.firstMaterial?.diffuse.contents = NSColor.systemBlue
        let bodyPart = SCNNode(geometry: body)
        bodyPart.position = SCNVector3(0, 0.6, 0)
        bodyNode.addChildNode(bodyPart)
        
        // Head (sphere)
        let head = SCNSphere(radius: 0.25)
        head.firstMaterial?.diffuse.contents = NSColor.systemPink
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 1.5, 0)
        bodyNode.addChildNode(headNode)
        
        // Left leg
        let leftLeg = SCNCapsule(capRadius: 0.1, height: 0.8)
        leftLeg.firstMaterial?.diffuse.contents = NSColor.systemGreen
        let leftLegNode = SCNNode(geometry: leftLeg)
        leftLegNode.position = SCNVector3(-0.15, -0.4, 0)
        leftLegNode.name = "LeftLeg"
        bodyNode.addChildNode(leftLegNode)
        
        // Right leg
        let rightLeg = SCNCapsule(capRadius: 0.1, height: 0.8)
        rightLeg.firstMaterial?.diffuse.contents = NSColor.systemGreen
        let rightLegNode = SCNNode(geometry: rightLeg)
        rightLegNode.position = SCNVector3(0.15, -0.4, 0)
        rightLegNode.name = "RightLeg"
        bodyNode.addChildNode(rightLegNode)
        
        scene.rootNode.addChildNode(bodyNode)
        
        // Add walking animation to legs
        addPlaceholderWalkingAnimation(to: bodyNode)
        
        // Set up camera
        setupCamera(in: scene, for: bodyNode)
        
        print("Placeholder character created with walking animation")
        return scene
    }
    
    private func addPlaceholderWalkingAnimation(to node: SCNNode) {
        // Animate the legs for a simple walking motion
        guard let leftLeg = node.childNode(withName: "LeftLeg", recursively: true),
              let rightLeg = node.childNode(withName: "RightLeg", recursively: true) else {
            return
        }
        
        // Left leg animation
        let leftRotation = CABasicAnimation(keyPath: "rotation")
        leftRotation.fromValue = SCNVector4(1, 0, 0, -Float.pi / 6)
        leftRotation.toValue = SCNVector4(1, 0, 0, Float.pi / 6)
        leftRotation.duration = 0.5
        leftRotation.autoreverses = true
        leftRotation.repeatCount = .greatestFiniteMagnitude
        leftLeg.addAnimation(leftRotation, forKey: "walking")
        
        // Right leg animation (opposite phase)
        let rightRotation = CABasicAnimation(keyPath: "rotation")
        rightRotation.fromValue = SCNVector4(1, 0, 0, Float.pi / 6)
        rightRotation.toValue = SCNVector4(1, 0, 0, -Float.pi / 6)
        rightRotation.duration = 0.5
        rightRotation.autoreverses = true
        rightRotation.repeatCount = .greatestFiniteMagnitude
        rightLeg.addAnimation(rightRotation, forKey: "walking")
        
        // Slight body bob
        let bodyBob = CABasicAnimation(keyPath: "position.y")
        bodyBob.fromValue = node.position.y
        bodyBob.toValue = node.position.y + 0.05
        bodyBob.duration = 0.25
        bodyBob.autoreverses = true
        bodyBob.repeatCount = .greatestFiniteMagnitude
        node.addAnimation(bodyBob, forKey: "bobbing")
    }
    
    private func loadCharacterFromURL(_ characterURL: URL, format: String, scene: SCNScene) -> SCNScene {
        // Verify file exists and is readable
        guard FileManager.default.fileExists(atPath: characterURL.path) else {
            print("Error: character.\(format) file does not exist at: \(characterURL.path)")
            return createPlaceholderScene(scene: scene)
        }
        
        // Check file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: characterURL.path),
           let fileSize = attributes[.size] as? Int64 {
            print("character.\(format) file size: \(fileSize) bytes")
            if fileSize == 0 {
                print("Error: character.\(format) file is empty")
                return createPlaceholderScene(scene: scene)
            }
        }
        
        // Always copy bundle files to temp directory to avoid permission issues
        // Bundle files may have restricted permissions that SceneKit can't access
        let finalURL: URL
        let baseURL: URL? // For texture resolution
        let isInBundle = characterURL.path.contains(".bundle") || characterURL.path.contains("/Contents/Resources/")
        
        if isInBundle {
            print("File is in bundle, copying to temp directory to avoid permission issues...")
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("character.\(format)")
                
                // Remove old temp file if exists
                try? FileManager.default.removeItem(at: tempURL)
                
                // Copy to temp directory
                try FileManager.default.copyItem(at: characterURL, to: tempURL)
                
                // Set proper permissions on the copied file
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tempURL.path)
                
                // Copy textures directory if it exists (for DAE files with relative texture paths)
                // Try multiple locations: bundle, source directory, etc.
                var texturesCopied = false
                
                // Try 1: In the bundle Resources directory
                let originalDir = characterURL.deletingLastPathComponent()
                let texturesDir = originalDir.appendingPathComponent("textures")
                if FileManager.default.fileExists(atPath: texturesDir.path) {
                    let tempTexturesDir = tempDir.appendingPathComponent("textures")
                    try? FileManager.default.removeItem(at: tempTexturesDir)
                    try FileManager.default.copyItem(at: texturesDir, to: tempTexturesDir)
                    print("Copied textures directory from bundle to temp: \(tempTexturesDir.path)")
                    texturesCopied = true
                }
                
                // Try 2: In the source resources directory (if bundle doesn't have it)
                if !texturesCopied {
                    if let packageRoot = findPackageRoot() {
                        let sourceTexturesDir = packageRoot
                            .appendingPathComponent("mac-pet")
                            .appendingPathComponent("resources")
                            .appendingPathComponent("textures")
                        if FileManager.default.fileExists(atPath: sourceTexturesDir.path) {
                            let tempTexturesDir = tempDir.appendingPathComponent("textures")
                            try? FileManager.default.removeItem(at: tempTexturesDir)
                            try FileManager.default.copyItem(at: sourceTexturesDir, to: tempTexturesDir)
                            print("Copied textures directory from source to temp: \(tempTexturesDir.path)")
                            texturesCopied = true
                        }
                    }
                }
                
                if !texturesCopied {
                    print("⚠ Warning: Could not find textures directory to copy")
                }
                
                print("Copied to temp location: \(tempURL.path)")
                finalURL = tempURL
                baseURL = tempDir // Use temp directory as base for texture resolution
            } catch {
                print("Failed to copy file to temp: \(error.localizedDescription)")
                print("Attempting to load directly from bundle (may fail)...")
                finalURL = characterURL
                baseURL = characterURL.deletingLastPathComponent() // Use original directory as base
            }
        } else {
            finalURL = characterURL
            baseURL = characterURL.deletingLastPathComponent() // Use original directory as base
        }
        
        // For USDZ and DAE, try multiple loading methods
        if format == "usdz" || format == "dae" || format == "scn" {
            // Method 1: Try loading with Data first (more reliable for permission issues)
            if let fileData = try? Data(contentsOf: finalURL) {
                print("Loaded file data (\(fileData.count) bytes), attempting to load scene from data...")
                
                // Try SCNSceneSource with data and base URL for texture resolution
                var options: [SCNSceneSource.LoadingOption: Any] = [:]
                if let base = baseURL {
                    options[.assetDirectoryURLs] = [base]
                }
                
                if let sceneSource = SCNSceneSource(data: fileData, options: options.isEmpty ? nil : options) {
                    do {
                        let characterScene = try sceneSource.scene(options: options.isEmpty ? nil : options)
                        print("Successfully loaded character.\(format) using SCNSceneSource with Data")
                        printNodeHierarchy(characterScene.rootNode, indent: 0)
                        // Fix textures after loading
                        fixTextures(in: characterScene, baseURL: baseURL)
                        return processCharacterScene(characterScene, scene: scene)
                    } catch {
                        print("SCNSceneSource with Data failed: \(error.localizedDescription)")
                    }
                }
            }
            
            // Method 2: Direct SCNScene loading from URL
            do {
                var options: [SCNSceneSource.LoadingOption: Any] = [:]
                if let base = baseURL {
                    options[.assetDirectoryURLs] = [base]
                }
                let characterScene = try SCNScene(url: finalURL, options: options.isEmpty ? nil : options)
                print("Successfully loaded character.\(format) using SCNScene")
                printNodeHierarchy(characterScene.rootNode, indent: 0)
                // Fix textures after loading
                fixTextures(in: characterScene, baseURL: baseURL)
                return processCharacterScene(characterScene, scene: scene)
            } catch {
                print("SCNScene loading failed: \(error.localizedDescription)")
            }
            
            // Method 3: Use SCNSceneSource (better for DAE files)
            if format == "dae" {
                print("Trying SCNSceneSource for DAE file...")
                var options: [SCNSceneSource.LoadingOption: Any] = [:]
                if let base = baseURL {
                    options[.assetDirectoryURLs] = [base]
                }
                if let sceneSource = SCNSceneSource(url: finalURL, options: options.isEmpty ? nil : options) {
                    do {
                        let characterScene = try sceneSource.scene(options: options.isEmpty ? nil : options)
                        print("Successfully loaded character.\(format) using SCNSceneSource")
                        printNodeHierarchy(characterScene.rootNode, indent: 0)
                        // Fix textures after loading
                        fixTextures(in: characterScene, baseURL: baseURL)
                        return processCharacterScene(characterScene, scene: scene)
                    } catch {
                        print("SCNSceneSource loading failed: \(error.localizedDescription)")
                    }
                }
            }
            
            // Method 4: Try Model I/O as fallback
            print("Trying Model I/O as fallback...")
            let mdlAsset = MDLAsset(url: finalURL)
            if mdlAsset.count > 0 {
                print("Model I/O loaded asset with \(mdlAsset.count) top-level objects")
                mdlAsset.loadTextures()
                let characterScene = SCNScene(mdlAsset: mdlAsset)
                print("Successfully converted MDLAsset to SCNScene")
                printNodeHierarchy(characterScene.rootNode, indent: 0)
                // Fix textures after loading
                fixTextures(in: characterScene, baseURL: baseURL)
                return processCharacterScene(characterScene, scene: scene)
            }
            
            print("All loading methods failed for character.\(format)")
            return createPlaceholderScene(scene: scene)
        }
        
        // For FBX, try Model I/O first (has better FBX support)
        print("Loading FBX using Model I/O framework...")
        let mdlAsset = MDLAsset(url: characterURL)
        
        if mdlAsset.count > 0 {
            print("Model I/O loaded asset with \(mdlAsset.count) top-level objects")
            mdlAsset.loadTextures()
            let characterScene = SCNScene(mdlAsset: mdlAsset)
            print("Successfully converted MDLAsset to SCNScene")
            printNodeHierarchy(characterScene.rootNode, indent: 0)
            return processCharacterScene(characterScene, scene: scene)
        }
        
        print("Model I/O failed to load FBX")
        print("")
        print("=== FBX FORMAT NOT SUPPORTED ===")
        print("Your FBX file uses a format that Apple's frameworks cannot read.")
        print("This is a known limitation of SceneKit and Model I/O.")
        print("")
        print("Please convert your FBX files to USDZ or DAE format:")
        print("")
        print("Option 1: Apple Reality Converter (recommended)")
        print("  - Download from: https://developer.apple.com/augmented-reality/tools/")
        print("  - Open character.fbx → Export as character.usdz")
        print("  - Open walking.fbx → Export as walking.usdz")
        print("")
        print("Option 2: Blender (free)")
        print("  - Import FBX → Export as DAE (Collada)")
        print("  - Or install USD add-on and export as USDZ")
        print("")
        print("Place converted files in: mac-pet/resources/")
        print("")
        print("Using placeholder character for now...")
        
        return createPlaceholderScene(scene: scene)
    }
    
    private func printNodeHierarchy(_ node: SCNNode, indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        let hasGeometry = node.geometry != nil ? " [geometry]" : ""
        let hasSkinner = node.skinner != nil ? " [skinner]" : ""
        let childCount = node.childNodes.count
        print("\(prefix)- \(node.name ?? "unnamed")\(hasGeometry)\(hasSkinner) (\(childCount) children)")
        
        for child in node.childNodes {
            printNodeHierarchy(child, indent: indent + 1)
        }
    }
    
    private func fixTextures(in scene: SCNScene, baseURL: URL?) {
        // Find and fix texture paths that failed to load
        // This is needed when DAE files have relative texture paths
        
        // Known texture files from the DAE - try these first
        let knownDiffuseTextures = ["akai_diffuse.png", "textures/akai_diffuse.png"]
        let knownNormalTextures = ["akai_normal.png", "textures/akai_normal.png"]
        
        func fixTexturesInNode(_ node: SCNNode) {
            // Fix textures for this node's geometry
            if let geometry = node.geometry {
                print("  Processing geometry in node: \(node.name ?? "unnamed")")
                print("  Materials count: \(geometry.materials.count)")
                for (index, material) in geometry.materials.enumerated() {
                    print("  Material \(index):")
                    print("    Diffuse contents type: \(type(of: material.diffuse.contents ?? "nil"))")
                    if let diffuseStr = material.diffuse.contents as? String {
                        print("    Diffuse (string): \(diffuseStr)")
                    }
                    // Check current diffuse contents
                    let currentDiffuse = material.diffuse.contents
                    let isString = (currentDiffuse as? String) != nil
                    let isColor = (currentDiffuse as? NSColor) != nil
                    let needsDiffuseFix = currentDiffuse == nil || isString || isColor
                    
                    if needsDiffuseFix {
                        print("    Material needs diffuse texture fix (nil: \(currentDiffuse == nil), string: \(isString), color: \(isColor))")
                    }
                    
                    // Try to find and assign diffuse texture
                    if needsDiffuseFix {
                        var diffuseAssigned = false
                        // Try known texture paths first
                        for texturePath in knownDiffuseTextures {
                            if let textureURL = findTexture(named: texturePath, baseURL: baseURL) {
                                material.diffuse.contents = textureURL
                                print("✓ Assigned diffuse texture: \(texturePath) -> \(textureURL.path)")
                                diffuseAssigned = true
                                break
                            }
                        }
                        
                        // If not found, try searching for any diffuse texture
                        if !diffuseAssigned {
                            if let textureURL = findTexture(named: "akai_diffuse.png", baseURL: baseURL) {
                                material.diffuse.contents = textureURL
                                print("✓ Assigned diffuse texture (fallback): \(textureURL.path)")
                                diffuseAssigned = true
                            }
                        }
                        
                        // If still not found and contents is a string (failed path), try to fix it
                        if !diffuseAssigned, let failedPath = currentDiffuse as? String {
                            if let textureURL = findTexture(named: failedPath, baseURL: baseURL) {
                                material.diffuse.contents = textureURL
                                print("✓ Fixed diffuse texture from failed path: \(failedPath) -> \(textureURL.path)")
                            } else {
                                print("⚠ Could not find diffuse texture for path: \(failedPath)")
                            }
                        }
                    }
                    
                    // Check current normal contents
                    let currentNormal = material.normal.contents
                    let needsNormalFix = currentNormal == nil || 
                                        (currentNormal as? String) != nil
                    
                    // Try to find and assign normal texture
                    if needsNormalFix {
                        var normalAssigned = false
                        // Try known texture paths first
                        for texturePath in knownNormalTextures {
                            if let textureURL = findTexture(named: texturePath, baseURL: baseURL) {
                                material.normal.contents = textureURL
                                print("✓ Assigned normal texture: \(texturePath) -> \(textureURL.path)")
                                normalAssigned = true
                                break
                            }
                        }
                        
                        // If not found and contents is a string (failed path), try to fix it
                        if !normalAssigned, let failedPath = currentNormal as? String {
                            if let textureURL = findTexture(named: failedPath, baseURL: baseURL) {
                                material.normal.contents = textureURL
                                print("✓ Fixed normal texture from failed path: \(failedPath) -> \(textureURL.path)")
                            }
                        }
                    }
                }
            }
            
            // Recursively fix child nodes
            for child in node.childNodes {
                fixTexturesInNode(child)
            }
        }
        
        print("Fixing textures in scene...")
        print("Base URL for texture resolution: \(baseURL?.path ?? "nil")")
        fixTexturesInNode(scene.rootNode)
        print("Texture fixing complete.")
    }
    
    private func findTexture(named texturePath: String, baseURL: URL?) -> URL? {
        // Try multiple approaches to find the texture file
        
        // Remove any invalid path components (like Windows paths in DAE)
        let cleanPath = texturePath.replacingOccurrences(of: "C:\\Users\\", with: "")
            .replacingOccurrences(of: "\\", with: "/")
            .replacingOccurrences(of: "//", with: "/")
        
        // Extract just the filename
        let fileName = (cleanPath as NSString).lastPathComponent
        
        // Try to find the texture file
        var searchPaths: [URL] = []
        
        // 1. Try baseURL (temp directory or original location)
        if let base = baseURL {
            // Try textures subdirectory
            searchPaths.append(base.appendingPathComponent("textures").appendingPathComponent(fileName))
            // Try directly in base
            searchPaths.append(base.appendingPathComponent(fileName))
            // Try with full relative path
            if cleanPath.hasPrefix("textures/") {
                searchPaths.append(base.appendingPathComponent(cleanPath))
            }
        }
        
        // 2. Try original resources directory
        if let packageRoot = findPackageRoot() {
            let resourcesDir = packageRoot.appendingPathComponent("mac-pet").appendingPathComponent("resources")
            searchPaths.append(resourcesDir.appendingPathComponent("textures").appendingPathComponent(fileName))
            searchPaths.append(resourcesDir.appendingPathComponent(fileName))
            if cleanPath.hasPrefix("textures/") {
                searchPaths.append(resourcesDir.appendingPathComponent(cleanPath))
            }
        }
        
        // 3. Try bundle resources
        if let bundleURL = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "textures") {
            searchPaths.append(bundleURL)
        }
        if let bundleURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
            searchPaths.append(bundleURL)
        }
        
        // Check each path
        for url in searchPaths {
            if FileManager.default.fileExists(atPath: url.path) {
                print("Found texture at: \(url.path)")
                return url
            } else {
                print("  Checked (not found): \(url.path)")
            }
        }
        
        print("⚠ Could not find texture: \(texturePath) (searched for: \(fileName))")
        print("  Searched \(searchPaths.count) locations")
        return nil
    }
    
    private func processCharacterScene(_ characterScene: SCNScene, scene: SCNScene) -> SCNScene {
        
        // Find the root node of the character (usually the first child or a specific node)
        // FBX files typically have a root node containing the character
        var characterRootNode: SCNNode?
        
        // Try to find a node with geometry or skeleton
        for child in characterScene.rootNode.childNodes {
            if child.geometry != nil || child.childNodes.contains(where: { $0.skinner != nil }) {
                characterRootNode = child
                break
            }
        }
        
        // If no specific node found, use the first child or root node itself
        if characterRootNode == nil {
            characterRootNode = characterScene.rootNode.childNodes.first ?? characterScene.rootNode
        }
        
        guard let characterNode = characterRootNode else {
            print("Error: Could not find character node in character.fbx")
            return scene
        }
        
        // Clone the character node to add to our scene
        let clonedCharacter = characterNode.clone()
        
        // Add character to scene
        scene.rootNode.addChildNode(clonedCharacter)
        
        // Load and apply walking animation
        loadAndApplyWalkingAnimation(to: clonedCharacter)
        
        // Set up camera to view the character
        setupCamera(in: scene, for: clonedCharacter)
        
        return scene
    }
    
    private func loadAndApplyWalkingAnimation(to characterNode: SCNNode) {
        // Try to find walking animation in multiple formats and case variations
        let animationFormats = ["dae", "usdz", "fbx"]
        let animationNames = ["walking", "Walking", "WALKING"]
        var walkingURL: URL? = nil
        var animationFormat: String = ""
        
        // Try all combinations
        for name in animationNames {
            for format in animationFormats {
                if let url = findResource(name: name, extension: format) {
                    walkingURL = url
                    animationFormat = format
                    print("Found animation file: \(name).\(format)")
                    break
                }
            }
            if walkingURL != nil { break }
        }
        
        guard let url = walkingURL else {
            print("Error: Could not find walking animation in any format")
            print("Tried: walking/Walking/WALKING with extensions: dae, usdz, fbx")
            return
        }
        
        loadAnimationFromURL(url, format: animationFormat, characterNode: characterNode)
    }
    
    private func loadAnimationFromURL(_ walkingURL: URL, format: String, characterNode: SCNNode) {
        // Always copy bundle files to temp directory to avoid permission issues
        let finalURL: URL
        let isInBundle = walkingURL.path.contains(".bundle") || walkingURL.path.contains("/Contents/Resources/")
        
        if isInBundle {
            print("Animation file is in bundle, copying to temp directory...")
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("walking.\(format)")
                
                // Remove old temp file if exists
                try? FileManager.default.removeItem(at: tempURL)
                
                // Copy to temp directory
                try FileManager.default.copyItem(at: walkingURL, to: tempURL)
                
                // Set proper permissions on the copied file
                try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: tempURL.path)
                
                print("Copied animation to temp location: \(tempURL.path)")
                finalURL = tempURL
            } catch {
                print("Failed to copy animation file to temp: \(error.localizedDescription)")
                print("Attempting to load directly from bundle (may fail)...")
                finalURL = walkingURL
            }
        } else {
            finalURL = walkingURL
        }
        
        // Try loading with Data first (more reliable for permission issues)
        var sceneSource: SCNSceneSource? = nil
        if let fileData = try? Data(contentsOf: finalURL) {
            print("Loaded animation file data (\(fileData.count) bytes)")
            sceneSource = SCNSceneSource(data: fileData, options: nil)
        }
        
        // Fallback to URL-based loading
        if sceneSource == nil {
            sceneSource = SCNSceneSource(url: finalURL, options: nil)
        }
        
        guard let sceneSource = sceneSource else {
            print("Error: Could not create SCNSceneSource from animation file at: \(finalURL.path)")
            return
        }
        
        // Get all animation identifiers from the file
        let animationIDs = sceneSource.identifiersOfEntries(withClass: CAAnimation.self)
        
        guard !animationIDs.isEmpty else {
            print("Error: No animations found in animation file")
            print("File path: \(walkingURL.path)")
            print("File format: \(format)")
            return
        }
        
        print("Found \(animationIDs.count) animation(s) in animation file")
        
        // Load the first animation (animation files typically have one main animation)
        guard let animationID = animationIDs.first,
              let caAnimation = sceneSource.entryWithIdentifier(animationID, withClass: CAAnimation.self) else {
            print("Error: Could not load animation from file")
            return
        }
        
        // Convert CAAnimation to SCNAnimation
        // SceneKit can work with CAAnimation directly, but we need to configure it properly
        let scnAnimation = SCNAnimation(caAnimation: caAnimation)
        
        // Configure animation to loop forever
        scnAnimation.repeatCount = .greatestFiniteMagnitude
        scnAnimation.usesSceneTimeBase = false
        
        // Find the skeleton root node in the character
        // The skeleton is typically attached to nodes with skinner components
        var skeletonRoot: SCNNode?
        
        // Search for nodes with skinner (these are the skinned mesh nodes)
        func findSkeletonRoot(node: SCNNode) -> SCNNode? {
            // If this node has a skinner, its skeleton root is the skinner's skeleton
            if let skinner = node.skinner {
                return skinner.skeleton
            }
            
            // Recursively search child nodes
            for child in node.childNodes {
                if let found = findSkeletonRoot(node: child) {
                    return found
                }
            }
            
            return nil
        }
        
        skeletonRoot = findSkeletonRoot(node: characterNode)
        
        // If skeleton root not found via skinner, try to find a node with bone structure
        // Sometimes the skeleton is the root or a direct child
        if skeletonRoot == nil {
            // Try common skeleton root names (including Mixamo naming)
            let commonNames = [
                "mixamorig:Hips", "mixamorig_Hips", "Hips", "hips",
                "root", "Root", "ROOT",
                "skeleton", "Skeleton",
                "Armature", "armature",
                "Scene Root", "SceneRoot"
            ]
            for name in commonNames {
                if let found = characterNode.childNode(withName: name, recursively: true) {
                    skeletonRoot = found
                    print("Found skeleton root by name: \(name)")
                    break
                }
            }
            
            // If still not found, try searching for any node containing "Hips" or "root"
            if skeletonRoot == nil {
                characterNode.enumerateChildNodes { (node, _) in
                    if let nodeName = node.name?.lowercased(),
                       (nodeName.contains("hips") || nodeName.contains("root") || nodeName.contains("mixamorig")) {
                        skeletonRoot = node
                        print("Found skeleton root by pattern matching: \(node.name ?? "unnamed")")
                        return
                    }
                }
            }
        }
        
        // If still not found, use the character node itself as the animation target
        let animationTarget = skeletonRoot ?? characterNode
        
        print("Applying animation to node: \(animationTarget.name ?? "unnamed")")
        
        // Create SCNAnimationPlayer and attach to the skeleton root
        // This is where the animation binds to the skeleton
        let animationPlayer = SCNAnimationPlayer(animation: scnAnimation)
        animationTarget.addAnimationPlayer(animationPlayer, forKey: "walking")
        
        // Start playing the animation immediately
        animationPlayer.play()
        
        print("Walking animation applied and playing (looping forever)")
    }
    
    private func setupCamera(in scene: SCNScene, for characterNode: SCNNode) {
        // Create camera
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.fieldOfView = CGFloat(45)
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        // Calculate bounding box of character to position camera appropriately
        var minVec = SCNVector3(x: CGFloat(Float.greatestFiniteMagnitude), y: CGFloat(Float.greatestFiniteMagnitude), z: CGFloat(Float.greatestFiniteMagnitude))
        var maxVec = SCNVector3(x: CGFloat(-Float.greatestFiniteMagnitude), y: CGFloat(-Float.greatestFiniteMagnitude), z: CGFloat(-Float.greatestFiniteMagnitude))
        var hasGeometry = false
        
        characterNode.enumerateChildNodes { (node, _) in
            if let geometry = node.geometry {
                hasGeometry = true
                let boundingBox = geometry.boundingBox
                minVec.x = Swift.min(minVec.x, boundingBox.min.x)
                minVec.y = Swift.min(minVec.y, boundingBox.min.y)
                minVec.z = Swift.min(minVec.z, boundingBox.min.z)
                maxVec.x = Swift.max(maxVec.x, boundingBox.max.x)
                maxVec.y = Swift.max(maxVec.y, boundingBox.max.y)
                maxVec.z = Swift.max(maxVec.z, boundingBox.max.z)
            }
        }
        
        // Calculate center and size, with fallback defaults
        let center: SCNVector3
        let size: Float
        
        if hasGeometry && minVec.x != CGFloat(Float.greatestFiniteMagnitude) {
            let centerX: Float = Float((minVec.x + maxVec.x) / 2.0)
            let centerY: Float = Float((minVec.y + maxVec.y) / 2.0)
            let centerZ: Float = Float((minVec.z + maxVec.z) / 2.0)
            center = SCNVector3(x: CGFloat(centerX), y: CGFloat(centerY), z: CGFloat(centerZ))
            
            let sizeX: Float = Float(maxVec.x - minVec.x)
            let sizeY: Float = Float(maxVec.y - minVec.y)
            let sizeZ: Float = Float(maxVec.z - minVec.z)
            let maxSizeXY: Float = Swift.max(sizeX, sizeY)
            size = Swift.max(maxSizeXY, sizeZ)
        } else {
            // Fallback: use character node's position and default size
            center = characterNode.position
            size = Float(2.0)
        }
        
        // Position camera to view the character from an angle
        let distanceMultiplier: Float = 2.5
        let minDistance: Float = 5.0
        let calculatedDistance = size * distanceMultiplier
        let distance = Swift.max(calculatedDistance, minDistance) // Ensure minimum distance
        let camOffsetX: Float = distance * Float(0.7)
        let camOffsetY: Float = distance * Float(0.5)
        let camOffsetZ: Float = distance * Float(0.7)
        cameraNode.position = SCNVector3(
            x: center.x + CGFloat(camOffsetX),
            y: center.y + CGFloat(camOffsetY),
            z: center.z + CGFloat(camOffsetZ)
        )
        
        // Look at the character center
        cameraNode.look(at: center)
        
        scene.rootNode.addChildNode(cameraNode)
        
        // Add default lighting (already enabled via autoenablesDefaultLighting, but add explicit light for better control)
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = CGFloat(1000)
        let lightOffsetX: Float = distance * Float(0.5)
        let lightOffsetY: Float = distance * Float(0.8)
        let lightOffsetZ: Float = distance * Float(0.5)
        lightNode.position = SCNVector3(
            x: center.x + CGFloat(lightOffsetX),
            y: center.y + CGFloat(lightOffsetY),
            z: center.z + CGFloat(lightOffsetZ)
        )
        scene.rootNode.addChildNode(lightNode)
        
        // Add ambient light for better visibility
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.intensity = CGFloat(500)
        scene.rootNode.addChildNode(ambientLightNode)
    }
}
