//
//  Debug.swift
//
//  Created by Todd Laney on 11/5/15.
//

import Foundation

// send all DEBUG outout to nul in a nonDEBUG build.

func NSLog(_ str : @autoclosure () -> String)
{
    return Debug.log(str())
}
func print(_ str : @autoclosure () -> String)
{
    return Debug.log(str())
}
func print(_ x : Any)
{
    fatalError("use a string!")
}
class Debug {
    static let flag = _isDebugAssertConfiguration()
    class func log(_ str : @autoclosure () -> String) {
        if _isDebugAssertConfiguration() {
            Swift.print(str())
        }
    }
}

