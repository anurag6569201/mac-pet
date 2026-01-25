import SceneKit
import Cocoa

class ChatBubble: SCNNode {
    
    enum BubbleDirection {
        case left   // Tail points to bottom-left (Bubble is to the right of pet)
        case right  // Tail points to bottom-right (Bubble is to the left of pet)
        case center // Tail points to bottom-center (Bubble is above pet)
    }
    
    private let textNode: SCNNode
    private let backgroundNode: SCNNode
    private let textGeometry: SCNText
    
    // Configuration
    var bubbleColor: NSColor = NSColor(calibratedWhite: 0.98, alpha: 1.0) // Almost white
    var textColor: NSColor = NSColor(calibratedWhite: 0.15, alpha: 1.0) // Dark gray
    var cornerRadius: CGFloat = 20.0 // More rounded
    var padding: CGFloat = 20.0 // More spacious
    var tailHeight: CGFloat = 18.0 // Slightly taller tail
    var tailWidth: CGFloat = 24.0 // Slightly wider tail
    var font: NSFont = NSFont.systemFont(ofSize: 15, weight: .regular) // Better readability
    var extrusionDepth: CGFloat = 3.0 // More depth
    var maxWidth: CGFloat = 280.0 // Max bubble width for better wrapping
    
    // Private state
    private(set) var direction: BubbleDirection = .center
    
    init(text: String, direction: BubbleDirection = .center) {
        self.direction = direction
        
        // 1. Create Text Geometry with smart wrapping for multi-line paragraphs
        // Use maxWidth for consistent bubble width
        let containerWidth = maxWidth - (padding * 2)
        
        textGeometry = SCNText(string: text, extrusionDepth: 0.6)
        textGeometry.font = font
        textGeometry.flatness = 0.1 // Smoother, higher quality text
        textGeometry.containerFrame = CGRect(x: 0, y: -1000, width: containerWidth, height: 2000)
        textGeometry.alignmentMode = CATextLayerAlignmentMode.left.rawValue
        textGeometry.isWrapped = true // Enable text wrapping for paragraphs
        // Remove truncation to allow full paragraph display
        
        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = textColor
        textMaterial.isDoubleSided = true
        textGeometry.materials = [textMaterial]
        
        textNode = SCNNode(geometry: textGeometry)
        backgroundNode = SCNNode()
        
        super.init()
        
        setup(text: text)
        
        // Smooth entrance animation
        self.scale = SCNVector3(0.3, 0.3, 0.3)
        self.opacity = 0.0
        
        // Scale up with bounce
        let scaleUp = SCNAction.scale(to: 1.0, duration: 0.35)
        scaleUp.timingMode = .easeOut
        
        // Fade in
        let fadeIn = SCNAction.fadeIn(duration: 0.3)
        
        // Combine animations
        let group = SCNAction.group([scaleUp, fadeIn])
        self.runAction(group)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setText(_ text: String) {
        textGeometry.string = text
        updateLayout()
    }
    
    func setDirection(_ direction: BubbleDirection) {
        self.direction = direction
        updateLayout()
    }
    
    private func setup(text: String) {
        addChildNode(backgroundNode)
        addChildNode(textNode)
        updateLayout()
    }
    
    private func updateLayout() {
        // 1. Measure Text with proper bounds
        let (minBounds, maxBounds) = textNode.boundingBox
        let textWidth = Swift.max(CGFloat(maxBounds.x - minBounds.x), 40) // Minimum width for small text
        let textHeight = Swift.max(CGFloat(maxBounds.y - minBounds.y), 20) // Minimum height
        
        // 2. Calculate Bubble Size with smart constraints
        let constrainedWidth = Swift.min(textWidth + (padding * 2), maxWidth)
        let bubbleWidth = Swift.max(constrainedWidth, 80) // Minimum bubble width
        let bubbleHeight = Swift.max(textHeight + (padding * 2), 50) // Minimum bubble height with better proportions
        
        // 3. Create Bubble Shape (Bezier Path)
        let path = createBubblePath(width: bubbleWidth, height: bubbleHeight, tailHeight: tailHeight, direction: direction)
        
        // 4. Create Geometry from Path
        let shape = SCNShape(path: path, extrusionDepth: extrusionDepth)
        shape.chamferRadius = 1.5 // Slightly more chamfer for smoother edges 
        
        // --- Modern Premium Material Design ---
        let bgMaterial = SCNMaterial()
        // Soft, modern white with subtle warmth
        bgMaterial.diffuse.contents = NSColor(calibratedRed: 0.99, green: 0.99, blue: 1.0, alpha: 1.0)
        
        // Physically based rendering for realistic lighting
        bgMaterial.lightingModel = .physicallyBased
        bgMaterial.metalness.contents = 0.1 // Subtle metallic sheen
        bgMaterial.roughness.contents = 0.3 // Smooth but not too glossy
        bgMaterial.specular.contents = NSColor(white: 0.95, alpha: 1.0)
        
        // Subtle emission for visibility in all lighting
        bgMaterial.emission.contents = NSColor(white: 0.2, alpha: 1.0)
        
        bgMaterial.isDoubleSided = true
        
        // Chamfer (Rim) Material - subtle highlight
        let chamferMaterial = SCNMaterial()
        chamferMaterial.diffuse.contents = NSColor.white
        chamferMaterial.lightingModel = .constant
        chamferMaterial.emission.contents = NSColor(white: 0.4, alpha: 1.0) // Softer rim
        
        shape.materials = [bgMaterial, bgMaterial, bgMaterial, bgMaterial, chamferMaterial]
        
        backgroundNode.geometry = shape
        
        // 5. Position Text with left alignment
        // For left-aligned text, we need to position it at the left edge of the bubble with padding
        let pivotX = CGFloat(Float(minBounds.x))
        let pivotY = CGFloat(Float(minBounds.y + textHeight/2))
        textNode.pivot = SCNMatrix4MakeTranslation(pivotX, pivotY, 0)
        
        // Calculate position for left-aligned text
        let lateralOffset: CGFloat = 20.0
        var xOffset: CGFloat = 0
        
        // Position text at the left edge of the bubble body with padding
        if direction == .left {
            // Bubble on right side, body starts at lateralOffset
            xOffset = lateralOffset + padding
        } else if direction == .right {
            // Bubble on left side, body starts at -width - lateralOffset
            xOffset = -bubbleWidth - lateralOffset + padding
        } else {
            // Center bubble, body starts at -width/2
            xOffset = -bubbleWidth/2 + padding
        }
        
        // Position text in the vertical center of the bubble
        let textY = tailHeight + bubbleHeight / 2
        
        textNode.position = SCNVector3(xOffset, textY, extrusionDepth/2 + 0.6)
    }
    
    private func createBubblePath(width: CGFloat, height: CGFloat, tailHeight: CGFloat, direction: BubbleDirection) -> NSBezierPath {
        let path = NSBezierPath()
        let r = min(cornerRadius, height / 2)
        
        // Define Body Frame with Offset
        var bodyRect = NSRect.zero
        let lateralOffset: CGFloat = 20.0
        
        switch direction {
        case .left: // Bubble to Right
             bodyRect = NSRect(x: lateralOffset, y: tailHeight, width: width, height: height)
        case .right: // Bubble to Left
             bodyRect = NSRect(x: -width - lateralOffset, y: tailHeight, width: width, height: height)
        case .center: 
             bodyRect = NSRect(x: -width/2, y: tailHeight, width: width, height: height)
        }
        
        // Tail Tip is always at (0,0) based on our node logic
        let tailTip = NSPoint(x: 0, y: 0)
        
        // Vertices of the Body Rect (inset by radius for arcs)
        let minX = bodyRect.minX
        let maxX = bodyRect.maxX
        let minY = bodyRect.minY
        let maxY = bodyRect.maxY
        
        // START at Top-Center
        path.move(to: NSPoint(x: (minX + maxX)/2, y: maxY))
        
        // 1. Top Edge -> Top-Right
        path.line(to: NSPoint(x: maxX - r, y: maxY))
        path.appendArc(withCenter: NSPoint(x: maxX - r, y: maxY - r), radius: r, startAngle: 90, endAngle: 0, clockwise: true)
        
        // 2. Right Edge -> Bottom-Right
        path.line(to: NSPoint(x: maxX, y: minY + r))
        path.appendArc(withCenter: NSPoint(x: maxX - r, y: minY + r), radius: r, startAngle: 0, endAngle: 270, clockwise: true)
        
        // 3. Bottom Edge with Tail
        // We are at (maxX - r, minY). Moving towards minX.
        
        // Calculate Tail Connection Points on Body
        // Tail is roughly 'tailWidth' wide at base.
        let tailBaseHalf = tailWidth / 2
        
        var tailStart = NSPoint.zero
        var tailEnd = NSPoint.zero
        var hasTail = false
        
        if direction == .center {
            // Tail in middle
            tailEnd = NSPoint(x: tailBaseHalf, y: minY)   // Right side (encountered first when moving Right->Left)
            tailStart = NSPoint(x: -tailBaseHalf, y: minY) // Left side
            hasTail = true
        } else if direction == .left {
            // Bubble on Right. Side Offset = 20. Body Starts at x=20.
            // Tail Tip at 0.
            // Tail connects to body at x=20 (minX) + some padding.
            // We want tail to flow from body to 0.
            
            // End (Right side of base) -> Start (Left side of base).
            let baseRightX = minX + r + tailWidth
            let baseLeftX = minX + r
            
            tailEnd = NSPoint(x: baseRightX, y: minY)
            tailStart = NSPoint(x: baseLeftX, y: minY)
            hasTail = true
            
        } else if direction == .right {
            // Bubble on Left. Side Offset = 20. Body Ends at x=-20.
            // Tail Tip at 0.
            // Tail connects to body at maxX.
            
            let baseRightX = maxX - r
            let baseLeftX = maxX - r - tailWidth
            
            tailEnd = NSPoint(x: baseRightX, y: minY)
            tailStart = NSPoint(x: baseLeftX, y: minY)
            hasTail = true
        }
        
        if hasTail {
             path.line(to: tailEnd)
             // Curve to Tip (0,0)
             // Use Quad curve for simplicity or Cubic for style.
             
             // Control points to make it comma-like.
             // We are drawing Right -> Left.
             // Curve 1: End -> Tip.
             path.curve(to: tailTip,
                        controlPoint1: NSPoint(x: tailEnd.x - 5, y: minY - tailHeight * 0.5),
                        controlPoint2: NSPoint(x: tailTip.x + 5, y: tailHeight * 0.5))
             
             // Curve 2: Tip -> Start.
             path.curve(to: tailStart,
                        controlPoint1: NSPoint(x: tailTip.x - 5, y: tailHeight * 0.5),
                        controlPoint2: NSPoint(x: tailStart.x + 5, y: minY - tailHeight * 0.5))
        }
        
        // Continue to Bottom-Left
        path.line(to: NSPoint(x: minX + r, y: minY))
        path.appendArc(withCenter: NSPoint(x: minX + r, y: minY + r), radius: r, startAngle: 270, endAngle: 180, clockwise: true)
        
        // 4. Left Edge -> Top-Left
        path.line(to: NSPoint(x: minX, y: maxY - r))
        path.appendArc(withCenter: NSPoint(x: minX + r, y: maxY - r), radius: r, startAngle: 180, endAngle: 90, clockwise: true)
        
        path.close()
        return path
    }
}

