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
        self.view.backgroundColor = .systemOrange
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
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


