// Caractère affiché par chaque key code Carbon (0 à 127), sans modificateur, pour les dispositions
// française, américaine et russe. Sortie JSON sur stdout, lue par scripts/check-shortcuts.py.
// Lancement : swift scripts/keyboard-layouts.swift
// Le type de clavier est celui du Mac qui lance le script (ISO ici) : il décide des touches 10 et 50.
import Carbon
import Foundation

let wanted = ["com.apple.keylayout.French", "com.apple.keylayout.US", "com.apple.keylayout.Russian"]
let filter = [kTISPropertyInputSourceType: kTISTypeKeyboardLayout] as CFDictionary
let sources = TISCreateInputSourceList(filter, true).takeRetainedValue() as? [TISInputSource] ?? []

func property(_ source: TISInputSource, _ key: CFString) -> AnyObject? {
    TISGetInputSourceProperty(source, key).map { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() }
}

var layouts: [String: [String: String]] = [:]
for source in sources {
    guard let id = property(source, kTISPropertyInputSourceID) as? String, wanted.contains(id),
          let data = property(source, kTISPropertyUnicodeKeyLayoutData) as? Data else { continue }
    var keys: [String: String] = [:]
    for code in 0..<128 {
        var dead: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { raw in
            UCKeyTranslate(
                raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!, UInt16(code), UInt16(kUCKeyActionDisplay),
                0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &length, &chars
            )
        }
        if status == noErr, length > 0 { keys[String(code)] = String(utf16CodeUnits: chars, count: length) }
    }
    layouts[String(id.split(separator: ".").last!)] = keys
}

FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: layouts, options: [.sortedKeys]))
