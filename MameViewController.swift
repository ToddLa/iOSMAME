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
    
    var dumpFrame = false
    var contentMode = UIView.ContentMode.scaleAspectFill
    var contentScale = 1.0
    
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
        var rect = view.bounds.inset(by:self.view.safeAreaInsets)
        var size = CGSize.zero
        
        if mameScreenSize == .zero || contentMode == .scaleToFill {
            size = rect.size
        }
        else if contentMode == .scaleAspectFill {
            let scale = min(rect.width / mameScreenSize.width, rect.height / mameScreenSize.height)
            size.width = floor(mameScreenSize.width * scale)
            size.height = floor(mameScreenSize.height * scale)
        }
        else if contentMode == .scaleAspectFit {
            // same as .scaleAspectFill, but only integer scale factor
            let scale = floor(min(rect.width * UIScreen.main.scale / mameScreenSize.width, rect.height * UIScreen.main.scale / mameScreenSize.height))
            size.width = floor(mameScreenSize.width * scale) / UIScreen.main.scale
            size.height = floor(mameScreenSize.height * scale) / UIScreen.main.scale
        }
        else {
            let scale = CGFloat(contentScale)
            size.width = floor(mameScreenSize.width * scale) / UIScreen.main.scale
            size.height = floor(mameScreenSize.height * scale) / UIScreen.main.scale
        }
        
        rect.origin.x = rect.origin.x + floor((rect.width - size.width) * UIScreen.main.scale / 2) / UIScreen.main.scale
        if keyboardConnected {
            rect.origin.y = rect.origin.y + floor((rect.height - size.height) * UIScreen.main.scale / 2) / UIScreen.main.scale
        }
        rect.size = size
    
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

    func mameKey(_ hid:UIKeyboardHIDUsage, _ pressed:Bool) {
        if let key = myosd_keycode(hid) {
            mameKey(key, pressed)
        }
    }
    
    func commandKey(_ key:String) {
        switch (key) {
        case "d":
            dumpFrame = true
        case "\r":
            let modes = [UIView.ContentMode.center, .scaleAspectFit, .scaleAspectFill, .scaleToFill]
            let idx = modes.firstIndex(of:contentMode) ?? 0
            contentMode = modes[(idx + 1) % modes.count]
        case "0":
            contentMode = .scaleAspectFit
            contentScale = 1.0
        case "1"..."9":
            contentMode = .center
            contentScale = Double(key) ?? 1.0
        case "=":
            contentMode = .center
            contentScale = min(16.0, contentScale + 1.0)
        case "-":
            contentMode = .center
            contentScale = max(1.0, contentScale - 1.0)
        default:
            return
        }
        view.setNeedsLayout()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with:event)
        guard let key = presses.first?.key else {return}
        mameKey(key.keyCode, true)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with:event)
        guard let key = presses.first?.key else {return}
        mameKey(key.keyCode, false)
        if key.modifierFlags.contains(.command) {
            commandKey(key.characters)
        }
    }
    
    @objc
    func keyboardChange() {
        print("KEYBOARD: \(GCKeyboard.coalesced?.vendorName ?? "None")")
        keyboardConnected = GCKeyboard.coalesced != nil
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
        callbacks.video_exit = video_exit
        
        callbacks.input_init = input_init
        callbacks.input_poll = input_poll
        callbacks.input_exit = input_exit
        
        callbacks.game_init = game_init
        callbacks.game_exit = game_exit

        callbacks.set_game_info = set_game_list

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
    print("VIDEO INIT \(width)x\(height)")
    MameViewController.shared?.mameScreenSize = CGSize(width:Int(width), height: Int(height))
}
func video_draw(prims:UnsafeMutablePointer<myosd_render_primitive>!, width:Int32, height:Int32) {
    autoreleasepool {
        guard let vc = MameViewController.shared else {return}
        if vc.dumpFrame {
            MameViewController.shared?.mameView.dumpMamePrimitives(prims, size: CGSize(width:Int(width), height: Int(height)))
            vc.dumpFrame = false
        }
        vc.mameView.drawMamePrimitives(prims, size: CGSize(width:Int(width), height: Int(height)))
    }
}
func video_exit() {
    print("VIDEO EXIT")
}


func input_init(input:UnsafeMutablePointer<myosd_input_state>!, size:Int) {
    print("INPUT INIT")
}
func input_poll(input:UnsafeMutablePointer<myosd_input_state>!, size:Int) {
    guard var keyboard = MameViewController.shared?.mameKeyboard else {return}
    memcpy(&input.pointee.keyboard, &keyboard, 256)
    MameViewController.shared?.inMenu = input.pointee.input_mode == MYOSD_INPUT_MODE_UI.rawValue
}
func input_exit() {
    print("INPUT EXIT")
}

func set_game_list(games:UnsafeMutablePointer<myosd_game_info>?, count:Int32) {
    autoreleasepool {
        let games = Array(UnsafeBufferPointer(start:games, count:Int(count)))
            .filter({$0.name != nil && $0.description != nil && $0.type == MYOSD_GAME_TYPE_ARCADE.rawValue})
        for game in games {
            print("\(String(cString:game.name).padding(toLength:16, withPad:" ", startingAt:0)) \(String(cString:game.description))")
        }
    }
}

func game_init(info:UnsafeMutablePointer<myosd_game_info>?) {
    autoreleasepool {
        guard let game = info?.pointee, game.name != nil, game.description != nil else {return}
        print("GAME: \(String(cString:game.name)): \"\(String(cString:game.description))\"")
        print("    PARENT: \(String(cString:game.parent))")
        print("    SOURCE: \(String(cString:game.source_file))")
        print("      YEAR: \(String(cString:game.year))")
        print("       MFG: \(String(cString:game.manufacturer))")
    }
}
func game_exit() {
    print("GAME EXIT")
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


