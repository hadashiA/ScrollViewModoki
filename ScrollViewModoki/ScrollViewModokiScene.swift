import SpriteKit

func rubberBandDistance(offset offset: CGFloat, dimension: CGFloat) -> CGFloat {
    // * x = distance from the edge
    // * c = constant value, UIScrollView uses 0.55
    // * d = dimension, either width or height
    //   b = (1.0 – (1.0 / ((x * c / d) + 1.0))) * d
    
    let c: CGFloat = 0.55
    return (1.0 - (1.0 / ((offset * c / dimension) + 1.0))) * dimension
}

struct Camera {
    var x: CGFloat = 0 {
        didSet {
            lastX = oldValue
        }
    }
    var y: CGFloat = 0 {
        didSet {
            lastY = oldValue
        }
    }
    var zoom: CGFloat = 1 {
        didSet {
            lastZoom = oldValue
        }
    }
    var velocity = CGPoint.zero
    var lastX: CGFloat = 0
    var lastY: CGFloat = 0
    var lastZoom: CGFloat = 0
    
    var deltaX: CGFloat {
        return x - lastX
    }
    
    var deltaY: CGFloat {
        return y - lastY
    }
    
    init() {}
    
    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
    
    mutating func updateVelocity() {
        if abs(velocity.x) < 0.1 && abs(velocity.y) < 0.1 {
            velocity = CGPoint.zero
        } else {
            velocity.x *= 0.9
            velocity.y *= 0.9
            // x += velocity.x
            y += velocity.y
        }
    }
}

final class ScrollViewModokiScene: SKScene {
    var worldCamera: Camera {
        didSet {
            cameraDirty = true
        }
    }
    
    var dragging: Bool {
        return lastPanTranslation != nil || lastPinchScale != nil
    }

    private let cameraMinZoom: CGFloat = 1
    private let cameraMaxZoom: CGFloat = 3
    private let topOfWorld: CGFloat = 1000
    private let world = SKNode()
    private var cameraDirty = true
    private var enableVelocity = true
    private var lastPanTranslation: CGPoint?
    private var lastPinchScale: CGFloat?
    private var lastPinchPointInScene = CGPoint.zero
    
    override init(size: CGSize) {
        worldCamera = Camera(
            x: size.width * 0.5,
            y: size.height * 0.5)
        
        super.init(size: size)
        
        backgroundColor = UIColor.whiteColor()
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func update(currentTime: NSTimeInterval) {
        super.update(currentTime)
        
        fixCamera()
        if !dragging {
            worldCamera.updateVelocity()
        }
    }
    
    override func didMoveToView(view: SKView) {
        super.didMoveToView(view)
        
        for i in (0..<20) {
            let color: UIColor
            switch i % 4 {
            case 0:
                color = UIColor(red: 244/255, green: 214/255, blue: 224/255, alpha: 1.0)
            case 1:
                color = UIColor(red: 204/255, green: 233/255, blue: 249/255, alpha: 1.0)
            case 2:
                color = UIColor(red: 214/255, green: 233/255, blue: 201/255, alpha: 1.0)
            default:
                color = UIColor(red: 249/255, green: 244/255, blue: 214/255, alpha: 1.0)
            }

            let shape = SKShapeNode(rect: CGRect(
                x: 0,
                y: 0,
                width: size.width,
                height: 50))
            shape.fillColor = color
            shape.strokeColor = color
            shape.position = CGPoint(x: 0, y: CGFloat(i * 50))
            world.addChild(shape)
        }
        addChild(world)
    }
    
    private func cameraRectInWorld(camera: Camera) -> CGRect {
        let originX = size.width * anchorPoint.x
        let originY = size.height * anchorPoint.y
        let zoom = camera.zoom
        
        let width = size.width / zoom
        let height = size.height / zoom
        let x = (camera.x - originX) / zoom
        let y = (camera.y - originY) / zoom
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func fixCamera() {
        guard cameraDirty else { return }
        
        let cameraRect = cameraRectInWorld(worldCamera)
        let cameraTop = cameraRect.maxY
        let cameraBottom = cameraRect.minY
        let deltaY = worldCamera.deltaY
        
        if cameraBottom < 0 {
            if deltaY < 0 && lastPanTranslation != nil {
                worldCamera.y = worldCamera.lastY + deltaY * 0.4
            } else {
                let newBottom = 0 - rubberBandDistance(offset: abs(cameraBottom), dimension: topOfWorld)
                worldCamera.y = (newBottom * worldCamera.zoom) + (size.height * anchorPoint.y)
            }
        } else if cameraTop > topOfWorld {
            if deltaY > 0 && lastPanTranslation != nil {
                worldCamera.y = worldCamera.lastY + deltaY * 0.4
            } else {
                let newTop = topOfWorld + rubberBandDistance(offset: abs(cameraTop - topOfWorld), dimension: topOfWorld)
                worldCamera.y = ((newTop - cameraRect.size.height) * worldCamera.zoom) + (size.height * anchorPoint.y)
            }
        }
        
        if lastPinchScale == nil {
            var newZoom: CGFloat? = nil
            if worldCamera.zoom < cameraMinZoom {
                newZoom = cameraMinZoom + (worldCamera.zoom - cameraMinZoom) * 0.55
            } else if worldCamera.zoom > cameraMaxZoom {
                newZoom = cameraMaxZoom + (worldCamera.zoom - cameraMaxZoom) * 0.55
            }
            
            if let newZoom = newZoom {
                let scale = newZoom / worldCamera.zoom
                
                let pinchPointInWorld = convertPoint(lastPinchPointInScene, toNode: world)
                let scaledPinchPointInScele = convertPoint(
                    CGPoint(x: pinchPointInWorld.x * scale, y: pinchPointInWorld.y * scale),
                    fromNode: world)
                
                worldCamera.zoom *= scale
                worldCamera.x += scaledPinchPointInScele.x - lastPinchPointInScene.x
                worldCamera.y += scaledPinchPointInScele.y - lastPinchPointInScene.y
            }
        }
        
        world.position.x = -worldCamera.x
        world.position.y = -worldCamera.y
        world.setScale(worldCamera.zoom)
        
        cameraDirty = false

    }
    
    // MARK: UI Events
    
    func handlePinch(pinch: UIPinchGestureRecognizer) {
        switch pinch.state {
        case .Began:
            lastPinchScale = pinch.scale
        case .Changed:
            if let lastScale = lastPinchScale where pinch.scale > 0 {
                var scale = pinch.scale / lastScale
                let newZoom = worldCamera.zoom * scale
                if (newZoom > cameraMaxZoom && scale > 1) || (newZoom < cameraMinZoom && scale < 1) {
                    let fixedZoom = worldCamera.zoom + (newZoom - worldCamera.zoom) * 0.333
                    scale = fixedZoom / worldCamera.zoom
                }
                
                let pinchPoint = pinch.locationInView(pinch.view)
                let pinchPointInScene = convertPointFromView(pinchPoint)
                let pinchPointInWorld = convertPoint(pinchPointInScene, toNode: world)
                let scaledPinchPointInScele = convertPoint(
                    CGPoint(
                        x: pinchPointInWorld.x * scale,
                        y: pinchPointInWorld.y * scale),
                    fromNode: world)
                
                worldCamera.zoom *= scale
                worldCamera.x += scaledPinchPointInScele.x - pinchPointInScene.x
                worldCamera.y += scaledPinchPointInScele.y - pinchPointInScene.y
                lastPinchPointInScene = pinchPointInScene
                
                lastPinchScale = pinch.scale
            }
        case .Ended, .Cancelled, .Failed:
            lastPinchScale = nil
        default:
            lastPinchScale = nil
        }
    }
    
    func handlePan(pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .Began:
            lastPanTranslation = pan.translationInView(pan.view)
            
        case .Changed:
            let translation = pan.translationInView(pan.view)
            var delta = CGPoint.zero
            if let lastPanTranslation = lastPanTranslation {
                delta = CGPoint(
                    x: translation.x - lastPanTranslation.x,
                    y: translation.y - lastPanTranslation.y)
            }
            
            // worldCamera.x -= delta.x
            worldCamera.y += delta.y
            
            let velocityX = (worldCamera.velocity.x - delta.x) * 0.5
            let velocityY = (worldCamera.velocity.y + delta.y) * 0.5
            worldCamera.velocity = CGPoint(
                x: max(-30, min(30, velocityX)),
                y: max(-30, min(30, velocityY)))
            
            lastPanTranslation = translation
            
        case .Ended, .Cancelled, .Failed:
            lastPanTranslation = nil
        default:
            lastPanTranslation = nil
        }
    }
}
