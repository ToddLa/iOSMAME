//
//  MameKeyCode - map a HID key code to a MAME/MYOSD key code
//  IOSMAME
//
//  Created by ToddLa on 4/9/21.
//
import UIKit

extension myosd_keycode {
    
    static let key_map:[UIKeyboardHIDUsage: myosd_keycode] = [
        .keyboard0: MYOSD_KEY_0, .keyboard1: MYOSD_KEY_1, .keyboard2: MYOSD_KEY_2, .keyboard3: MYOSD_KEY_3, .keyboard4: MYOSD_KEY_4,
        .keyboard5: MYOSD_KEY_5, .keyboard6: MYOSD_KEY_6, .keyboard7: MYOSD_KEY_7, .keyboard8: MYOSD_KEY_8, .keyboard9: MYOSD_KEY_9,

        .keypad0: MYOSD_KEY_0_PAD, .keypad1: MYOSD_KEY_1_PAD, .keypad2: MYOSD_KEY_2_PAD, .keypad3: MYOSD_KEY_3_PAD, .keypad4: MYOSD_KEY_4_PAD,
        .keypad5: MYOSD_KEY_5_PAD, .keypad6: MYOSD_KEY_6_PAD, .keypad7: MYOSD_KEY_7_PAD, .keypad8: MYOSD_KEY_8_PAD, .keypad9: MYOSD_KEY_9_PAD,

        .keyboardA: MYOSD_KEY_A, .keyboardB: MYOSD_KEY_B, .keyboardC: MYOSD_KEY_C, .keyboardD: MYOSD_KEY_D, .keyboardE: MYOSD_KEY_E,
        .keyboardF: MYOSD_KEY_F, .keyboardG: MYOSD_KEY_G, .keyboardH: MYOSD_KEY_H, .keyboardI: MYOSD_KEY_I, .keyboardJ: MYOSD_KEY_J,
        .keyboardK: MYOSD_KEY_K, .keyboardL: MYOSD_KEY_L, .keyboardM: MYOSD_KEY_M, .keyboardN: MYOSD_KEY_N, .keyboardO: MYOSD_KEY_O,
        .keyboardP: MYOSD_KEY_P, .keyboardQ: MYOSD_KEY_Q, .keyboardR: MYOSD_KEY_R, .keyboardS: MYOSD_KEY_S, .keyboardT: MYOSD_KEY_T,
        .keyboardU: MYOSD_KEY_U, .keyboardV: MYOSD_KEY_V, .keyboardW: MYOSD_KEY_W, .keyboardX: MYOSD_KEY_X, .keyboardY: MYOSD_KEY_Y, .keyboardZ: MYOSD_KEY_Z,
        
        .keyboardF1: MYOSD_KEY_F1, .keyboardF2: MYOSD_KEY_F2, .keyboardF3: MYOSD_KEY_F3, .keyboardF4: MYOSD_KEY_F4, .keyboardF5: MYOSD_KEY_F5,  .keyboardF6: MYOSD_KEY_F6,
        .keyboardF7: MYOSD_KEY_F7, .keyboardF8: MYOSD_KEY_F8, .keyboardF9: MYOSD_KEY_F9, .keyboardF10: MYOSD_KEY_F10, .keyboardF11: MYOSD_KEY_F11,  .keyboardF12: MYOSD_KEY_F12,
        .keyboardF13: MYOSD_KEY_F13, .keyboardF14: MYOSD_KEY_F14, .keyboardF15: MYOSD_KEY_F15,

        .keyboardRightArrow:        MYOSD_KEY_RIGHT,
        .keyboardLeftArrow:         MYOSD_KEY_LEFT,
        .keyboardDownArrow:         MYOSD_KEY_DOWN,
        .keyboardUpArrow:           MYOSD_KEY_UP,

        .keyboardLeftControl:       MYOSD_KEY_LCONTROL,
        .keyboardLeftShift:         MYOSD_KEY_LSHIFT,
        .keyboardLeftAlt:           MYOSD_KEY_LALT,
        .keyboardLeftGUI:           MYOSD_KEY_LCMD,
        .keyboardRightControl:      MYOSD_KEY_RCONTROL,
        .keyboardRightShift:        MYOSD_KEY_RSHIFT,
        .keyboardRightAlt:          MYOSD_KEY_RALT,
        .keyboardRightGUI:          MYOSD_KEY_RCMD,
        
        .keyboardReturn:            MYOSD_KEY_ENTER,
        .keyboardReturnOrEnter:     MYOSD_KEY_ENTER,
        .keyboardEscape:            MYOSD_KEY_ESC,
        .keyboardDeleteOrBackspace: MYOSD_KEY_BACKSPACE,
        .keyboardTab:               MYOSD_KEY_TAB,
        .keyboardSpacebar:          MYOSD_KEY_SPACE,
        .keyboardHyphen:            MYOSD_KEY_MINUS,
        .keyboardEqualSign:         MYOSD_KEY_EQUALS,
        .keyboardOpenBracket:       MYOSD_KEY_OPENBRACE,
        .keyboardCloseBracket:      MYOSD_KEY_CLOSEBRACE,
        .keyboardBackslash:         MYOSD_KEY_BACKSLASH,
        
        .keyboardNonUSPound:        MYOSD_KEY_BACKSLASH2,
        .keyboardSemicolon:         MYOSD_KEY_COLON,
        .keyboardQuote:             MYOSD_KEY_QUOTE,
        .keyboardGraveAccentAndTilde: MYOSD_KEY_TILDE,
        .keyboardComma:             MYOSD_KEY_COMMA,
        .keyboardPeriod:            MYOSD_KEY_STOP,
        .keyboardSlash:             MYOSD_KEY_SLASH,
        .keyboardCapsLock:          MYOSD_KEY_CAPSLOCK,
        .keyboardPrintScreen:       MYOSD_KEY_PRTSCR,
        .keyboardScrollLock:        MYOSD_KEY_SCRLOCK,
        .keyboardPause:             MYOSD_KEY_PAUSE,
        .keyboardInsert:            MYOSD_KEY_INSERT,
        .keyboardHome:              MYOSD_KEY_HOME,
        .keyboardPageUp:            MYOSD_KEY_PGUP,
        .keyboardDeleteForward:     MYOSD_KEY_DEL_PAD,
        .keyboardEnd:               MYOSD_KEY_END,
        .keyboardPageDown:          MYOSD_KEY_PGDN,

        .keypadNumLock:             MYOSD_KEY_NUMLOCK,
        .keypadSlash:               MYOSD_KEY_SLASH_PAD,
        .keypadAsterisk:            MYOSD_KEY_ASTERISK,
        .keypadHyphen:              MYOSD_KEY_MINUS_PAD,
        .keypadPlus:                MYOSD_KEY_PLUS_PAD,
        .keypadEnter:               MYOSD_KEY_ENTER_PAD,

        .keypadPeriod:              MYOSD_KEY_STOP,
        .keyboardNonUSBackslash:    MYOSD_KEY_BACKSLASH2,

        .keypadEqualSign:           MYOSD_KEY_EQUALS,
        .keypadComma:               MYOSD_KEY_COMMA,
        .keypadEqualSignAS400:      MYOSD_KEY_EQUALS,

        .keyboardCancel:            MYOSD_KEY_CANCEL,
        .keyboardSeparator:         MYOSD_KEY_INVALID,
    ]

    init?(_ hid:UIKeyboardHIDUsage) {
        guard let key = Self.key_map[hid] else {return nil}
        self = key
    }
}
