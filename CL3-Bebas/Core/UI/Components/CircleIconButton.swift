//
//  MainCard.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 05/06/26.
//

import SwiftUI

struct CircleIconButton: View {
    let systemName: String
    var size: CGFloat = 70
    var iconSize: CGFloat = 30
    var backgroundColor: Color = Color.BluePrimaryBC
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .shadow(color: backgroundColor.opacity(0.3), radius: 8, x: 0, y: 4)
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
