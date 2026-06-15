//
//  Text+Extension.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 05/06/26.
//

import SwiftUI

extension Text {
    static let LargeTitleRegular = Font.system(size: 28, weight: .regular, design: .default)
    static let OnboardingCaption = Font.system(size: 17, weight: .regular, design: .default)
    
    static let TitleHome        = Font.system(size: 34, weight: .regular, design: .default)
    
    static let CustomLargeTitle = Font.system(size: 34, weight: .semibold, design: .default)
    static let CustomHeadline   = Font.system(size: 17, weight: .semibold, design: .default)
    static let CustomBody       = Font.system(.body).weight(.regular)
    
    // Expanded Label
    static let CustomExpandedSH = Font.system(.footnote).weight(.semibold).width(.expanded)
    
    // Expanded Title2
    static let CustomExpandedT2 = Font.system(.title2).weight(.bold)
    
    // Title 1
    static let TitleRegular = Font.system(.title).weight(.bold)
    
    // Title 2
    static let Title2Regular = Font.system(.title2).weight(.regular)
    
    // SubHead
    static let CustomCondensedSH = Font.system(.subheadline).weight(.semibold).width(.condensed)
    
    // Footnote
    static let CustomFootnote    = Font.system(.footnote).weight(.regular)
}

struct CustomExpandedBT: ViewModifier {
    @ScaledMetric var size: CGFloat
    
    init(size: CGFloat) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size).weight(.semibold).width(.expanded))
    }
}

extension View {
    func customExpandedBT(size: CGFloat) -> some View {
        self.modifier(CustomExpandedBT(size: size))
    }
}
