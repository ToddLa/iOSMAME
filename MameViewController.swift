//
//  MameViewController.swift
//  IOSMAME
//
//  Created by ToddLa on 4/9/21.
//

import UIKit

class MameViewController: UIViewController {
    
    let mameView = MetalView()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBlue
        self.view.addSubview(mameView)
        mameView.backgroundColor = .systemOrange
        
        Thread(target:self, selector: #selector(backgroundThread), object:nil).start()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        mameView.frame = self.view.bounds
    }
    
    override var prefersStatusBarHidden: Bool {
        return true;
    }
    
    @objc
    func backgroundThread() {
        while true {
            var time = CACurrentMediaTime()
            mameView.showFPS = true
            if mameView.drawBegin() {
                let rect = CGRect(origin:.zero, size:mameView.boundsSize)
                mameView.setViewRect(rect)
                for _ in 0...1000 {
                    let color = VertexColor.random
                    let points = [CGPoint.random(in:rect.size), CGPoint.random(in:rect.size), CGPoint.random(in:rect.size)]
                    mameView.drawTriangle(points, color:color)
                }
                mameView.drawEnd()
            }
            time = CACurrentMediaTime() - time
            time = (1.0 / 60.0) - time;
            if (time > 0.0) {
                Thread.sleep(forTimeInterval: time)
            }
        }
    }

}

extension CGPoint {
    static func random(in size:CGSize) -> CGPoint {
        return CGPoint(x: CGFloat.random(in: 0..<size.width), y: CGFloat.random(in: 0..<size.height))
    }
}

extension VertexColor {
    static var random : VertexColor {
        return VertexColor(Float.random(in:0...1), Float.random(in:0...1), Float.random(in:0...1), 1)
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = MameViewController()
        self.window = window
        window.makeKeyAndVisible()
        return true
    }
}


