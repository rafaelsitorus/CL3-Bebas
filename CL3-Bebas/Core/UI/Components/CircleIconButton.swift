//
//  MainCard.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 05/06/26.
//

import SwiftUI

struct CircleIconButton: View {
    var body : some View {
        ZStack {
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color.BluePrimaryBC)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: AppIcon.micIcon)
                        .foregroundColor(Color.whiteSC)
                        .font(.system(size: 34, weight: .regular))
                }
            }
        }
    }
}

#Preview {
    CircleIconButton()
}
