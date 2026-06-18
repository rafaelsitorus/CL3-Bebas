//
//  ArticleCard.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 15/06/26.
//

import SwiftUI

struct ArticleCard: View {
    let imageName: String
    let title: String
    let status: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            
            // Baris Atas: Judul Teks & Ikon Indikator
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 360, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.bottom)
                    
                    Text(title)
                        .font(Text.CustomCondensedSH)
                        .foregroundColor(Color.PrimaryMainBlue)
                        .padding(.bottom)
                        .padding(.horizontal)
                    
                    Text(status)
                        .font(Text.TitleRegular)
                        .foregroundColor(.black)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                
                Spacer()
            }
        }
        .frame(width: 360, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Radius.OverallCard))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.OverallCard)
                .stroke(Color.black.opacity(0.4), lineWidth: 0.3)
        )
    }
}

#Preview {
    ArticleCard(imageName: "GreyImg",title: "PITCHING TIPS", status: "How To Control Your Speaking Pace Under Pressure")
}
