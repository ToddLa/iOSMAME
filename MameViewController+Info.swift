//
//  MameViewController+Info.swift
//  iOSMAME
//
//  Created by Todd Laney on 6/11/24.
//

import UIKit


// MARK: INFO/HELP

extension MameViewController {
    
    var app_name:String {
        return  (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? ""
    }

    var app_version:String {
        return  (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ??
                (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "Unknown"
    }

    // show app info, called from app menu
    func showInfo() {
        let mame_version_num = myosd_get(Int32(MYOSD_VERSION))

        let text = """
                   Simple port of MAME to iOS
                   Version \(app_version) (MAME 0.\(mame_version_num))

                   use touch contorls ◀ ▶ ▲ ▼ Ⓐ Ⓑ Ⓧ Ⓨ to select romset and play.

                   use `Add ROM...` to add your own custom romsets.
                   
                   you can find free to play romsets at mamedev.org/roms
                   """
        
        let alert = UIAlertController(title:app_name, message:text, preferredStyle:.alert)
        alert.addAction(UIAlertAction(title: "Visit mamedev.org/roms", style:.default) {_ in
            let url = URL(string: "https://www.mamedev.org/roms/")!
            UIApplication.shared.open(url)
        })
        alert.addAction(UIAlertAction(title: "Done", style:.default, handler:nil))
        alert.preferredAction = alert.actions.last
        
        self.present(alert, animated: true)
    }
    
    // show app help, called from app menu
    // ...for now we just call showInfo
    func showHelp() {
        self.showInfo()
    }
    
    // show info about getting ROMs, called when `roms` is empty
    // ...for now we just call showInfo
    func showFirstRunHelp() {
        self.showInfo()
    }
}
