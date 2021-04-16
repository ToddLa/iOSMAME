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
            func Button(_ text:String = "", _ key:myosd_keycode? = nil) -> UIView {
                if text == "" {
                    return UIView().setConstraint(.width, equalTo:.height)
                }

                let btn = UIButton(type: .system)
                if let key = key {
                    btn.addAction(UIAction() { _ in
                        MameViewController.shared?.mameKey(translate(key), true)
                     }, for:.touchDown)
                    btn.addAction(UIAction() { _ in
                        MameViewController.shared?.mameKey(translate(key), false)
                    }, for:[.touchUpInside, .touchUpOutside])
                }

                if let img = UIImage(systemName:text) {
                    btn.setImage(img, for:.normal)
                    if let img = UIImage(systemName:"\(text).fill") {
                        btn.setImage(img, for:.highlighted)
                    }
                    btn.setConstraint(.width, equalTo:.height)
                }
                else {
                    btn.setTitle(" \(text) ", for:.normal)
                    btn.titleLabel?.adjustsFontSizeToFitWidth = true
                    btn.layer.borderColor = self.tintColor.cgColor
                    btn.layer.borderWidth = 4
                    btn.layer.cornerRadius = 4
                }
                return btn
            }
            addSubview(UIStackView(axis:.vertical,
                UIView(),
                UIStackView(spacing:16.0,
                    Button("ESC", MYOSD_KEY_ESC),
                    Button("SELECT", MYOSD_KEY_5),
                    UIView(),
                    Button("START", MYOSD_KEY_1),
                    Button("MENU", MYOSD_KEY_TAB)
                ),
                UIStackView(
                    Button(),
                    Button("arrowtriangle.up.circle", MYOSD_KEY_UP),
                    Button(),
                    UIView(),
                    Button(),
                    Button("y.circle", MYOSD_KEY_SPACE),
                    Button()
                ),
                UIStackView(
                    Button("arrowtriangle.left.circle", MYOSD_KEY_LEFT),
                    Button(),
                    Button("arrowtriangle.right.circle", MYOSD_KEY_RIGHT),
                    UIView(),
                    Button("x.circle", MYOSD_KEY_LSHIFT),
                    Button(),
                    Button("b.circle", MYOSD_KEY_LALT)
                ),
                UIStackView(
                    Button(),
                    Button("arrowtriangle.down.circle", MYOSD_KEY_DOWN),
                    Button(),
                    UIView(),
                    Button(),
                    Button("a.circle", MYOSD_KEY_LCONTROL),
                    Button()
                )
            ))
        }
        subviews.first!.frame = bounds
        
        let h = UITraitCollection.current.horizontalSizeClass == .compact ? (bounds.height / 6) : (bounds.height / 4)
        let cfg = UIImage.SymbolConfiguration(font:UIFont.boldSystemFont(ofSize:h))
        for view in subviews.first!.subviews {
            for view in view.subviews {
                if let btn = view as? UIButton {
                    if btn.currentImage == nil {
                        btn.titleLabel?.font = .boldSystemFont(ofSize:h/2)
                    }
                    else {
                        btn.setConstraint(.height, equalTo:h)
                        for state in [UIControl.State.normal, .highlighted] {
                            if let img = btn.image(for:state) {
                                btn.setImage(img.applyingSymbolConfiguration(cfg), for:state)
                            }
                        }
                    }
                }
            }
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
        //view.layer.borderWidth = 0.333
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


