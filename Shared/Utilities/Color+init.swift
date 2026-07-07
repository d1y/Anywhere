//
//  Color+init.swift
//  Anywhere
//
//  Created by NodePassProject on 6/19/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static let connectedBackgroundStart = Color(hex: 0xFBEFD2)
    static let connectedBackgroundEnd = Color(hex: 0xE7C98D)
    static let disconnectedBackgroundStart = Color(hex: 0x05081A)
    static let disconnectedBackgroundEnd = Color(hex: 0x0A0E27)

    #if canImport(UIKit)
    var archivedData: Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: UIColor(self), requiringSecureCoding: true)
    }
    
    init?(archivedData data: Data) {
        guard let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
            return nil
        }
        self.init(uiColor: uiColor)
    }
    #endif
}

#if canImport(UIKit)
extension UIColor {
    static let connectedBackgroundStart = UIColor(Color.connectedBackgroundStart)
    static let connectedBackgroundEnd = UIColor(Color.connectedBackgroundEnd)
    static let disconnectedBackgroundStart = UIColor(Color.disconnectedBackgroundStart)
    static let disconnectedBackgroundEnd = UIColor(Color.disconnectedBackgroundEnd)
}
#endif
