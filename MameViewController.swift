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
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        mameView.frame = self.view.bounds
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


