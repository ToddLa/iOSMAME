//
//  MameViewController.swift
//  IOSMAME
//
//  Created by ToddLa on 4/9/21.
//

import UIKit
import GameController

class MameViewController: UIViewController {
    
    static var shared:MameViewController?
    
    var keyboardConnected = false
    var keyboardHasEscapeKey = false
    
    let mameView = MetalView()
    var mameKeyboard = [UInt8](repeating:0, count:256)
    var mameScreenSize:CGSize = .zero {
        didSet {
            DispatchQueue.main.async {
                self.view.setNeedsLayout()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Self.shared = self
        self.view.backgroundColor = .darkGray
        self.view.addSubview(mameView)
        mameView.backgroundColor = .systemOrange
        mameView.showFPS = true
        
        NotificationCenter.default.addObserver(self, selector:#selector(keyboardChange), name:.GCKeyboardDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(keyboardChange), name:.GCKeyboardDidDisconnect, object: nil)
        
        Thread(target:self, selector: #selector(backgroundThread), object:nil).start()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        var rect = self.view.bounds
        if mameScreenSize != .zero {
            rect = rect.inset(by:self.view.safeAreaInsets)
            //rect = AVMakeRect(aspectRatio:mameScreenSize, insideRect:rect)
            let scale = min(rect.width / mameScreenSize.width, rect.height / mameScreenSize.height)
            let w = floor(mameScreenSize.width * scale)
            let h = floor(mameScreenSize.height * scale)
            rect.origin.x = rect.origin.x + floor((rect.width - w) / 2)
            //rect.origin.y = rect.origin.y + floor((rect.height - h) / 2)
            rect.size = CGSize(width:w, height:h)
        }
        mameView.frame = rect
        mameView.textureCacheFlush()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    func mameKey(_ hid:UIKeyboardHIDUsage) -> myosd_keycode? {
        guard let key = myosd_keycode(hid) else {return nil}
        if key == MYOSD_KEY_TILDE && keyboardConnected && !keyboardHasEscapeKey {
            return MYOSD_KEY_ESC
        }
        return key
    }
    
    // keyboard input
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        NSLog("pressesBegan: \(presses.first?.key?.charactersIgnoringModifiers.replacingOccurrences(of:"\r", with:"⏎") ?? "")")
        if let hid = presses.first?.key?.keyCode, let key = mameKey(hid) {
            NSLog("KEY: \(hid.rawValue) => \(key.rawValue) DOWN ")
            mameKeyboard[Int(key.rawValue)] = 1
        }
        super.pressesBegan(presses, with:event)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        NSLog("pressesEnded: \(presses.first?.key?.charactersIgnoringModifiers.replacingOccurrences(of:"\r", with:"⏎") ?? "")")
        if let hid = presses.first?.key?.keyCode, let key = mameKey(hid) {
            NSLog("KEY: \(hid.rawValue) => \(key.rawValue) UP ")
            mameKeyboard[Int(key.rawValue)] = 0
        }
        super.pressesEnded(presses, with:event)
    }
    
    @objc
    func keyboardChange() {
        print("KEYBOARD: \(GCKeyboard.coalesced?.vendorName ?? "None") \(GCKeyboard.coalesced?.productCategory ?? "")")
        keyboardConnected = GCKeyboard.coalesced != nil
        //TODO: how to detect a "smart" keyboard without an Escape key?
        //keyboardHasEscapeKey = GCKeyboard.coalesced?.keyboardInput?["Escape"] != nil
        keyboardHasEscapeKey = false
    }

    @objc
    func backgroundThread() {
        
        let docs = FileManager.default.urls(for:.documentDirectory, in:.userDomainMask).first!
        FileManager.default.changeCurrentDirectoryPath(docs.path)

        for dir in ["roms", "cfg"] {
            let url = docs.appendingPathComponent(dir, isDirectory:true)
            try? FileManager.default.createDirectory(at:url, withIntermediateDirectories:false)
        }

        var callbacks = myosd_callbacks()
        callbacks.video_init = video_init
        callbacks.video_draw = video_draw
        callbacks.input_poll = input_poll
        
        callbacks.output_text = {(channel:Int32, text:UnsafePointer<Int8>!) -> Void in
            let chan = ["ERROR", "WARNING", "INFO", "DEBUG", "VERBOSE"]
            print("[\(chan[Int(channel)])]: \(String(cString:text))", terminator:"")
        }

        while true {
            myosd_main(0, nil, &callbacks, MemoryLayout<myosd_callbacks>.size)
        }
    }
}

func video_init(width:Int32, height:Int32) {
    MameViewController.shared?.mameScreenSize = CGSize(width:Int(width), height: Int(height))
}

func video_draw(prims:UnsafeMutablePointer<myosd_render_primitive>!, width:Int32, height:Int32) {
    autoreleasepool {
        MameViewController.shared?.mameView.drawMamePrimitives(prims, size: CGSize(width:Int(width), height: Int(height)))
    }
}

func input_poll(input:UnsafeMutablePointer<myosd_input_state>!, size:Int) {
    guard var keyboard = MameViewController.shared?.mameKeyboard else {return}
    memcpy(&input.pointee.keyboard, &keyboard, 256)
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


