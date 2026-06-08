//
//  MainCard.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 05/06/26.
//

import SwiftUI

struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 75
    var iconSize: CGFloat = 35
    var backgroundColor: Color = Color.BluePrimaryBC
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0
    var shadowX: CGFloat = 0
    var shadowY: CGFloat = 0
    let action: () -> Void
    
    init(
        systemName: String,
        size: CGFloat = 75,
        iconSize: CGFloat = 35,
        backgroundColor: Color = Color.BluePrimaryBC,
        shadowColor: Color = .clear,
        shadowRadius: CGFloat = 0,
        shadowX: CGFloat = 0,
        shadowY: CGFloat = 0,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.iconSize = iconSize
        self.backgroundColor = backgroundColor
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowX = shadowX
        self.shadowY = shadowY
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
                Image(systemName: systemName)
                    .foregroundColor(.whiteSC)
                    .font(.system(size: iconSize, weight: .medium))
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CircleIconButton(systemName: AppIcon.micIcon, action: {})
}
