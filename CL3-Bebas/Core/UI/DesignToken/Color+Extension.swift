//
//  DesignToken.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 05/06/26.
//

import SwiftUI
import Foundation

extension Color {
    static let BluePrimaryBC = Color("#2992E9")
    static let BlueSecondaryBC = Color("#BFE2FF")
    static let BlueAccentBC = Color("#F6FDFF")
    
    static let RedPrimarySC = Color("#D33838")
    static let RedSecondarySC = Color("#FFE6E6")
    static let GreyAccentSC = Color("#979797")
    
    static let whiteSC = Color("#FFFFFF")
    
    init(_ hex: String) {
            var cleanedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            
            if cleanedHex.hasPrefix("#") {
                cleanedHex.remove(at: cleanedHex.startIndex)
            }
            
            var rgbValue: UInt64 = 0
            
            Scanner(string: cleanedHex).scanHexInt64(&rgbValue)
            
            let r, g, b, a: Double
            
            switch cleanedHex.count {
            case 6:
                r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
                g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
                b = Double(rgbValue & 0x0000FF) / 255.0
                a = 1.0
                
            case 8:
                r = Double((rgbValue & 0xFF000000) >> 24) / 255.0
                g = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
                b = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
                a = Double(rgbValue & 0x000000FF) / 255.0
                
            default:
                r = 0.5
                g = 0.5
                b = 0.5
                a = 1.0
            }
            
            self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
