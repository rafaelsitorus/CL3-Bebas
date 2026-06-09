//
//  AudioCard.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 09/06/26.
//

import SwiftUI

struct AudioCard: View {
    let title: String
    let description: String
    let icon: String
    let accentColor: Color
    
    // State untuk mengubah icon tombol play/pause
    @State private var isPlaying = false
    
    // Data statis untuk membuat mock waveform
    private let waveformHeights: [CGFloat] = [
        12, 16, 24, 18, 10, 22, 28, 20, 14, 12,
        24, 30, 26, 18, 14, 22, 28, 24, 16, 10,
        18, 24, 20, 14, 12, 22, 26, 18, 16
    ]

    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Bagian Atas (Header & Deskripsi)
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                    .font(.system(size: 34))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                    
                    Text(description)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Spacer(minLength: 0)
            }
            .padding(16)
            
            // MARK: - Garis Pemisah (Separator)
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // MARK: - Bagian Bawah (Player & Waveform)
            HStack(spacing: 16) {
                
                // Tombol Play
                Button(action: {
                    // Animasi sederhana saat state berubah
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPlaying.toggle()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(accentColor)
                        .frame(width: 48, height: 48)
                        .background(Color.white)
                        .clipShape(Circle())
                        // Shadow khusus untuk tombol play
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                
                // Waveform Mockup
                HStack(spacing: 3) {
                    ForEach(0..<waveformHeights.count, id: \.self) { index in
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 3, height: waveformHeights[index])
                            // Menambahkan efek visual saat lagu dimainkan
                            .opacity(isPlaying ? 1.0 : 0.6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        
        // MARK: - Styling Border & Margin
        // 1. Overlay aksen warna kiri
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 8)
        }
        // 2. Pemotongan sudut melengkung yang mulus
        .clipShape(
            RoundedRectangle(cornerRadius: Radius.MainCard, style: .continuous)
        )
        // 3. Garis luar tipis (Stroke)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.MainCard, style: .continuous)
                .stroke(Color.gray.opacity(0.4), lineWidth: 0.6)
        }
        // 4. Pengaturan shadow yang di-copy dari MainCard
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    AudioCard(
        title: "Listen To An Example",
        description: "Listen how a good pace can make key points easier to understand.",
        icon: "headphones",
        accentColor: .red
    )
    .padding(.horizontal, 16)
}
