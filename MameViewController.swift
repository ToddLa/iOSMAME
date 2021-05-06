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
    
    let keyboard = MameKeyboard()
    var keyboardConnected = false
    var keyboardHasEscapeKey:Bool?
    
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
        self.view.backgroundColor = .black
        self.view.addSubview(mameView)
        mameView.backgroundColor = .systemOrange
        mameView.showFPS = true

        keyboard.tintColor = .systemYellow
        self.view.addSubview(keyboard)

        NotificationCenter.default.addObserver(self, selector:#selector(keyboardChange), name:.GCKeyboardDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(keyboardChange), name:.GCKeyboardDidDisconnect, object: nil)
        
        Thread(target:self, selector: #selector(backgroundThread), object:nil).start()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        var rect = view.bounds
        if mameScreenSize != .zero {
            rect = rect.inset(by:self.view.safeAreaInsets)
            //rect = AVMakeRect(aspectRatio:mameScreenSize, insideRect:rect)
            let scale = min(rect.width / mameScreenSize.width, rect.height / mameScreenSize.height)
            let w = floor(mameScreenSize.width * scale)
            let h = floor(mameScreenSize.height * scale)
            rect.origin.x = rect.origin.x + floor((rect.width - w) / 2)
            if keyboardConnected {
                rect.origin.y = rect.origin.y + floor((rect.height - h) / 2)
            }
            rect.size = CGSize(width:w, height:h)
        }
        mameView.frame = rect
        mameView.textureCacheFlush()
        
        let h = min(view.bounds.height * 0.333, view.bounds.width * 0.667)
        keyboard.frame = CGRect(x:0, y:view.bounds.height - h, width:view.bounds.width, height:h)
        keyboard.alpha = keyboardConnected ? 0.333 : 0.667
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // MARK: state
    
    var inMenu = false

    // MARK: keyboard input
    
    func mameKey(_ key:myosd_keycode, _ pressed:Bool) {
        NSLog("KEY: \(key.rawValue) \(pressed ? "DOWN" : "UP")")
        mameKeyboard[Int(key.rawValue)] = pressed ? 1 : 0
    }

    func mameKey(_ hid:UIKeyboardHIDUsage?, _ pressed:Bool) {
        if let hid = hid, var key = myosd_keycode(hid) {
            // none of Apples "smart" keyboards have ESC keys, so use TILDE
            if keyboardHasEscapeKey == nil && key == MYOSD_KEY_ESC {
                keyboardHasEscapeKey = true
            }
            if keyboardHasEscapeKey != true && key == MYOSD_KEY_TILDE {
                key = MYOSD_KEY_ESC
            }
            mameKey(key, pressed)
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with:event)
        mameKey(presses.first?.key?.keyCode, true)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with:event)
        mameKey(presses.first?.key?.keyCode, false)
    }
    
    @objc
    func keyboardChange() {
        print("KEYBOARD: \(GCKeyboard.coalesced?.vendorName ?? "None")")
        keyboardConnected = GCKeyboard.coalesced != nil
        //TODO: how to detect a "smart" keyboard without an Escape key?
        //keyboardHasEscapeKey = GCKeyboard.coalesced?.keyboardInput?["Escape"] != nil
        keyboardHasEscapeKey = nil
        view.setNeedsLayout()
    }

    // MARK: MAME background thread

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
        callbacks.set_game_info = set_game_info
        callbacks.game_init = game_info

        callbacks.output_text = {(channel:Int32, text:UnsafePointer<Int8>!) -> Void in
            let chan = ["ERROR", "WARNING", "INFO", "DEBUG", "VERBOSE"]
            print("[\(chan[Int(channel)])]: \(String(cString:text))", terminator:"")
        }
        
        let version_num = myosd_get(Int32(MYOSD_VERSION))
        let version_str = String(cString:UnsafePointer<CChar>(bitPattern:myosd_get(Int32(MYOSD_VERSION_STRING)))!)

        print("MAME VERSION[\(version_num)]: \"\(version_str)\"")

        while true {
            myosd_main(0, nil, &callbacks, MemoryLayout<myosd_callbacks>.size)
        }
    }
}

// MARK: LIBMAME callbacks

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
    MameViewController.shared?.inMenu = input.pointee.input_mode == MYOSD_INPUT_MODE_UI.rawValue
}

func set_game_info(games:UnsafeMutablePointer<myosd_game_info>?, count:Int32) {
    autoreleasepool {
        let games = Array(UnsafeBufferPointer(start:games, count:Int(count)))
            .filter({$0.name != nil && $0.description != nil && $0.type == MYOSD_GAME_TYPE_ARCADE.rawValue})
        for game in games {
            print("\(String(cString:game.name).padding(toLength:16, withPad:" ", startingAt:0)) \(String(cString:game.description))")
        }
    }
}

func game_info(info:UnsafeMutablePointer<myosd_game_info>?) {
    autoreleasepool {
        guard let game = info?.pointee, game.name != nil, game.description != nil else {return}
        print("GAME: \(String(cString:game.name)): \"\(String(cString:game.description))\"")
    }
}


// MARK: AppDelegate

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


