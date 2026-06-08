//
//  MetricCard.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//



import SwiftUI

struct MetricCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let labelText: String
    let labelColor: Color
    let progress: Double  // 0.0 to 1.0
    let onTap: () -> Void
   
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                

                // Title + subtitle + progress
                VStack(alignment: .leading, spacing: 15) {
                    
                    HStack {
                        // Icon
                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(accentColor)
                            .frame(width: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(Text.CustomHeadline)
                                .foregroundColor(.primary)
                            Text(subtitle)
                                .font(Text.CustomFootnote)
                                .foregroundColor(Color.GreyAccentSC)
                        }
                        Spacer()

                        // Colored label badge
                        LabelBadge(
                            text: labelText,
                            textColor: labelColor,
                            backgroundColor: labelColor.opacity(0.15)
                        )

        
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accentColor)
                                .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.leading, 44)
                    
                }
                
                Image(systemName: AppIcon.chevronRightIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.GreyAccentSC)
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: 367, height: 110)
            .background(Color.whiteSC)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.MainCard, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}



