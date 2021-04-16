//
//  MameKeyboard - simple UIView for a onscreen keyboard
//  IOSMAME
//
//  Created by ToddLa on 4/9/21.
//
import UIKit

// create this simple keyboard using UIStackViews and duct-tape
// +-----+--------+-----------------------------+-------+------+
// + ESC | SELECT |                             | START | MENU |
// +---+---+---+--+                             +--+---+---+---+
// |   | U |   |                                   |   | Y |   |
// +---+---+---+                                   +---+---+---+
// | L |   | R |                                   | X |   | B |
// +---+---+---+                                   +---+---+---+
// |   | D |   |                                   |   | A |   |
// +---+---+---+-----------------------------------+---+---+---+

class MameKeyboard : UIView {
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if (subviews.count == 0) {
            addSubview(UIStackView(axis:.vertical, distribution:.fillEqually,
                UIStackView(axis:.vertical, distribution:.fillEqually,
                    UIView(),
                    UIStackView(spacing:4.0,
                        MameKey("ESC", MYOSD_KEY_ESC),
                        MameKey("SELECT", MYOSD_KEY_5),
                        UIView(),
                        MameKey("START", MYOSD_KEY_1),
                        MameKey("MENU", MYOSD_KEY_TAB)
                    )
                ),
                UIStackView(
                    MameKey(""),
                    MameKey("arrowtriangle.up.circle", MYOSD_KEY_UP),
                    MameKey(""),
                    UIView(),
                    MameKey(""),
                    MameKey("y.circle", MYOSD_KEY_SPACE),
                    MameKey("")
                ),
                UIStackView(
                    MameKey("arrowtriangle.left.circle", MYOSD_KEY_LEFT),
                    MameKey(""),
                    MameKey("arrowtriangle.right.circle", MYOSD_KEY_RIGHT),
                    UIView(),
                    MameKey("x.circle", MYOSD_KEY_LSHIFT),
                    MameKey(""),
                    MameKey("b.circle", MYOSD_KEY_LALT)
                ),
                UIStackView(
                    MameKey(""),
                    MameKey("arrowtriangle.down.circle", MYOSD_KEY_DOWN),
                    MameKey(""),
                    UIView(),
                    MameKey(""),
                    MameKey("a.circle", MYOSD_KEY_LCONTROL),
                    MameKey("")
                )
            ))
        }
        subviews.first!.frame = bounds
    }
}

class MameKey : UIButton {
    
    convenience init(_ text:String, _ key:myosd_keycode? = nil) {
        self.init(type:.system)
        
        if let key = key {
            addAction(UIAction() { _ in
                MameViewController.shared?.mameKey(translate(key), true)
             }, for:.touchDown)
            addAction(UIAction() { _ in
                MameViewController.shared?.mameKey(translate(key), false)
            }, for:[.touchUpInside, .touchUpOutside])
        }

        if text == "" {
            // blank square button
            setConstraint(.width, equalTo:.height)
        }
        else if let img = UIImage(systemName:text) {
            // square button with system image
            setImage(img, for:.normal)
            if let img = UIImage(systemName:"\(text).fill") {
                setImage(img, for:.highlighted)
            }
            setConstraint(.width, equalTo:.height)
        }
        else {
            // button with text
            setTitle(" \(text) ", for:.normal)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if currentImage != nil {
            let cfg = UIImage.SymbolConfiguration(pointSize:bounds.height, weight:.bold, scale:.large)
            setImage(image(for:.normal)?.applyingSymbolConfiguration(cfg), for:.normal)
            setImage(image(for:.highlighted)?.applyingSymbolConfiguration(cfg), for:.highlighted)
        }
        else if currentTitle != nil {
            titleLabel?.font = .boldSystemFont(ofSize:bounds.height * 0.8)
            layer.borderColor = tintColor.cgColor
            layer.borderWidth = 4
            layer.cornerRadius = 4
        }
    }
}

// map keys when we are in a menu
private func translate(_ key:myosd_keycode) -> myosd_keycode {
    if MameViewController.shared?.inGame == true {
        return key
    }
    switch key {
    case MYOSD_KEY_5: return MYOSD_KEY_ENTER
    case MYOSD_KEY_1: return MYOSD_KEY_ENTER
    case MYOSD_KEY_LCONTROL: return MYOSD_KEY_ENTER
    case MYOSD_KEY_LALT: return MYOSD_KEY_ESC
    default: return key
    }
}

private extension UIStackView {
    convenience init(axis:NSLayoutConstraint.Axis = .horizontal,
                     distribution:UIStackView.Distribution = .fill,
                     alignment:UIStackView.Alignment = .fill,
                     spacing:CGFloat = 0.0,
                     _ views:UIView...) {
        self.init()
        self.axis = axis
        self.distribution = distribution
        self.alignment = alignment
        self.spacing = spacing
        self += views
    }
    static func += (stack:UIStackView, view:UIView) {
//        view.layer.borderWidth = 0.333
//        view.layer.borderColor = UIColor.systemGreen.cgColor
        stack.addArrangedSubview(view)
    }
    static func += (stack:UIStackView, views:[UIView]) {
        views.forEach {stack += $0}
    }
}

// self.setConstraint(.width, equalTo:42.0)
// self.setConstraint(.width, equalTo:.height)
// self.setConstraint(.width, equalTo:.height, multipliedBy:2.0)
private extension UIView {
    @discardableResult
    func setConstraint(_ constraint:NSLayoutConstraint, withPriority priority:UILayoutPriority = .required) -> Self {
        constraints.filter({$0.firstAttribute == constraint.firstAttribute}).forEach {
            removeConstraint($0)
        }
        constraint.priority = priority
        self.addConstraint(constraint)
        return self
    }
    @discardableResult
    func setConstraint(_ attribute:NSLayoutConstraint.Attribute, equalTo constant:CGFloat,
                       withPriority priority:UILayoutPriority = .required) -> Self {
        setConstraint(NSLayoutConstraint(item:self, attribute:attribute, relatedBy:.equal,
                                         toItem:nil, attribute:.notAnAttribute, multiplier:0.0, constant:constant))
    }
    @discardableResult
    func setConstraint(_ attribute:NSLayoutConstraint.Attribute, equalTo other:NSLayoutConstraint.Attribute,
                       multipliedBy multiplier:CGFloat = 1.0, withPriority priority:UILayoutPriority = .required) -> Self {
        setConstraint(NSLayoutConstraint(item:self, attribute:attribute, relatedBy:.equal,
                                         toItem:self, attribute:other, multiplier:multiplier, constant:0.0))
    }
}


