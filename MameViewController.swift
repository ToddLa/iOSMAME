//
//  MameViewController.swift
//  IOSMAME
//
//  Created by ToddLa on 4/9/21.
//

import UIKit
import GameController

class MameViewController: UIViewController, UIDocumentPickerDelegate {
    
    static var shared:MameViewController?
    
    let keyboard = MameKeyboard()
    let menu = MameKey("ellipsis.circle")
    var keyboardConnected = false
    var mouseConnected = false
    
    let mouse_lock = NSLock()
    var mouse_x = Float.zero
    var mouse_y = Float.zero
    var mouse_status:UInt = 0

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
        mameView.showFPS = false

        // touch-keyboard
        keyboard.tintColor = .systemBlue
        self.view.addSubview(keyboard)
        
        // app-menu
        menu.tintColor = .systemBlue
        menu.frame = CGRect(x:0, y:0, width:48, height:48)
        menu.alpha = 0.667
        menu.menu = makeMenu()
        menu.showsMenuAsPrimaryAction = true
        self.view.addSubview(menu)

        NotificationCenter.default.addObserver(self, selector:#selector(deviceChange), name:.GCKeyboardDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(deviceChange), name:.GCKeyboardDidDisconnect, object: nil)
        
        NotificationCenter.default.addObserver(self, selector:#selector(deviceChange), name:.GCMouseDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector:#selector(deviceChange), name:.GCMouseDidDisconnect, object: nil)
        
        Thread(target:self, selector: #selector(backgroundThread), object:nil).start()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.becomeFirstResponder()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        var rect = view.bounds.inset(by:self.view.safeAreaInsets)
        var size = CGSize.zero

        // pin menu to upper-right
        menu.frame.origin.x = rect.maxX - menu.bounds.width - 4.0
        menu.frame.origin.y = rect.minY + 4.0

        // tell MAME our screen size, it might re-set the video mode for hires artwork and fonts
        var screen_w = Int(rect.size.width * UIScreen.main.scale)
        var screen_h = Int(rect.size.height * UIScreen.main.scale)

        if !inGame {
            // use a (small) fixed size for the MAME UX, so we dont get tiny fonts.
            // TODO: maybe use ui.bdf?
            // TODO: maybe force MAME UX to ignore aspect
            screen_w = 640
            screen_h = 480
        }
        myosd_set(Int32(MYOSD_DISPLAY_WIDTH), Int(screen_w));
        myosd_set(Int32(MYOSD_DISPLAY_HEIGHT), Int(screen_h));

        
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
        //let landscape = view.bounds.height < view.bounds.width
        //let h = view.bounds.height * (landscape ? 0.500 : 0.333)

        keyboard.frame = CGRect(x:0, y:view.bounds.height - h, width:view.bounds.width, height:h)
        keyboard.alpha = keyboardConnected ? 0.333 : 0.667
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // MARK: menu
    
    private func makeMenu() -> UIMenu {
        let title = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                    (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? ""
        
        let menu = UIMenu(title:title, children: [
            UIAction(title: "Add ROM...", image: UIImage(systemName: "plus")) { action in
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip])
                picker.modalPresentationStyle = .formSheet
                picker.delegate = self
                picker.allowsMultipleSelection = true
                self.present(picker, animated: true)
            },
            UIAction(title: "Show Files...", image: UIImage(systemName: "folder")) { action in
                let docs = FileManager.default.urls(for:.documentDirectory, in:.userDomainMask).first!
                let roms = docs.appendingPathComponent("roms")
                let url = URL(string: "shareddocuments://" + roms.path)!
                UIApplication.shared.open(url) { success in
                    print("OPEN: \(url) \(success)")
                    if !success {
                        UIApplication.shared.open(roms)
                    }
                }
            },
            UIAction(title: "Info", image: UIImage(systemName: "info.circle")) { action in
                self.showInfo()
            },
        ])
        return menu
    }
    
    // MARK: UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let docs = FileManager.default.urls(for:.documentDirectory, in:.userDomainMask).first!
        let roms = docs.appendingPathComponent("roms")
        for url in urls {
            let dest = roms.appending(path:url.lastPathComponent)
            print("COPY: \(url)")
            print("  TO: \(dest)")
            if url.startAccessingSecurityScopedResource() {
                try? FileManager.default.copyItem(at:url, to:dest)
                url.stopAccessingSecurityScopedResource()
            }
        }
        // force a exit and re-load/scan of ROMs
        mameKey(MYOSD_KEY_EXIT, true)
    }
    
    // MARK: INFO/HELP
    
    func showInfo() {
        let app_name = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                       (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? ""
        
        let app_version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ??
                          (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "Unknown"
        
        let mame_version_num = myosd_get(Int32(MYOSD_VERSION))

         let text = """
                   Version \(app_version) (MAME 0.\(mame_version_num))
                   
                   Simple port of MAME to iOS
                   
                   use `Add ROM...` to add your own custom romsets.
                   
                   use touch contorls ◀ ▶ ▲ ▼ Ⓐ Ⓑ Ⓧ Ⓨ to select romset and play.
                   """
        
        let alert = UIAlertController(title:app_name, message:text, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler:nil))
        self.present(alert, animated: true)
    }

    
    // MARK: state
    
    var inMenu = false
    var inGame = false

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
    
    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else {return}
        mameKey(key.keyCode, true)
    }
    override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else {return}
        mameKey(key.keyCode, false)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else {return}
        mameKey(key.keyCode, false)
        if key.modifierFlags.contains(.command) {
            commandKey(key.characters)
        }
    }
    
    @objc
    func deviceChange() {
        
        if (keyboardConnected != (GCKeyboard.coalesced != nil)) {
            print("KEYBOARD: \(GCKeyboard.coalesced?.vendorName ?? "None")")
            keyboardConnected = GCKeyboard.coalesced != nil
            view.setNeedsLayout()
        }
        
        mouseConnected = (GCMouse.mice().count != 0);
        for mouse in GCMouse.mice() {
            print("MOUSE: \(mouse.vendorName ?? "None")")
            mouse.mouseInput?.mouseMovedHandler = {(_, delta_x:Float, delta_y:Float) -> Void in
                print("MOUSE MOVE: \(delta_x) \(delta_y)")
                self.mouse_lock.lock()
                self.mouse_x += delta_x
                self.mouse_y += delta_y
                self.mouse_lock.unlock()

            }
            mouse.mouseInput?.leftButton.pressedChangedHandler = { (_, _, pressed:Bool) -> Void in
                print("MOUSE LBUTTON: \(pressed)")
                self.mouse_status = UInt(pressed ? MYOSD_A.rawValue : 0)
            }
        }
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
        
        // create a default UI.INI on first run
        let ui_url = docs.appending(path:"ui.ini")
        if !FileManager.default.fileExists(atPath:ui_url.path) {
            let str = """
                      hide_main_panel           3
                      last_used_filter          Available
                      hide_romless              1
                      """
            FileManager.default.createFile(atPath:ui_url.path, contents:str.data(using:.utf8))
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

        callbacks.game_list = set_game_list

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

func video_init(width:Int32, height:Int32, min_width:Int32, min_height:Int32) {
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
    guard let vc = MameViewController.shared else {return}
    memset(&vc.mameKeyboard, 0, 256)
}
func input_poll(input:UnsafeMutablePointer<myosd_input_state>!, size:Int) {
    guard let vc = MameViewController.shared else {return}
    memcpy(&input.pointee.keyboard, &vc.mameKeyboard, 256)
    
    vc.mouse_lock.lock()
    input.pointee.mouse_x.0 = vc.mouse_x * 512.0
    input.pointee.mouse_y.0 = vc.mouse_y * 512.0
    input.pointee.mouse_status.0 = vc.mouse_status
    vc.mouse_x = 0.0
    vc.mouse_y = 0.0
    vc.mouse_lock.unlock()
    
    MameViewController.shared?.inMenu = input.pointee.input_mode == MYOSD_INPUT_MODE_MENU.rawValue
}
func input_exit() {
    print("INPUT EXIT")
}

func set_game_list(games:UnsafeMutablePointer<myosd_game_info>?, count:Int32) {
    autoreleasepool {
        let games = Array(UnsafeBufferPointer(start:games, count:Int(count)))
            .filter({$0.name != nil && $0.description != nil})
        for game in games {
            let game_type = game.type == MYOSD_GAME_TYPE_ARCADE.rawValue ? "Arcade" :
                            game.type == MYOSD_GAME_TYPE_CONSOLE.rawValue ? "Console" :
                            game.type == MYOSD_GAME_TYPE_COMPUTER.rawValue ? "Computer" : "Other"
                print("\(String(cString:game.name).padding(toLength:16, withPad:" ", startingAt:0)) \(game_type.padding(toLength:8, withPad:" ", startingAt:0)) \(String(cString:game.description))")
            if (game.software_list != nil) {
                print("    SOFTWARE: \(String(cString:game.software_list))")
            }
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
        MameViewController.shared?.inGame = true
    }
}
func game_exit() {
    print("GAME EXIT")
    MameViewController.shared?.inGame = false
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


