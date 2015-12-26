import UIKit
import SpriteKit

final class ViewController: UIViewController {
    @IBOutlet weak var sceneView: SKView! {
        didSet {
            #if DEBUG
                sceneView.showsFPS = true
                sceneView.showsDrawCount = true
                sceneView.showsNodeCount = true
            #endif
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if sceneView.scene == nil {
            let scene = ScrollViewModokiScene(size: sceneView.frame.size)
            let pinch = UIPinchGestureRecognizer(target: scene, action: "handlePinch:")
            let pan = UIPanGestureRecognizer(target: scene, action: "handlePan:")
            
            sceneView.addGestureRecognizer(pan)
            sceneView.addGestureRecognizer(pinch)
            sceneView.presentScene(scene)
        }
    }
}
