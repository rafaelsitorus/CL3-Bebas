//
//  OverallCard.swift
//  CL3-Bebas
//
//  Card used on the Home "Overall Analysis" carousel. One card per
//  paralinguistic metric (Pace, Articulation, Intonation) — each
//  renders:
//    - title (e.g. "Pace")
//    - status (e.g. "Too Fast") — the metric's *current* label
//    - icon (SF Symbol)
//    - description (one randomly-chosen improvement tip)
//    - optional pillLabel rendered as a small capsule at the bottom
//      of the description, used to show the average value across
//      the last N recordings (e.g. "Average: 168 WPM").
//

import SwiftUI

struct OverallCard: View {
    let title: String
    let status: String
    let description: String
    let iconName: String

    /// Small capsule rendered at the bottom of the card showing the
    /// averaged value (e.g. "Average: 168 WPM"). Pass `nil` to hide.
    var pillLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {

            // Baris Atas: Judul Teks & Ikon Indikator
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Text.CustomHeadlineCard) // Menggunakan token Headline Semibold Anda
                        .foregroundColor(Color(.black))

                    Text(status)
                        .font(Text.TitleRegular)
                        .foregroundColor(Color(.black))
                }

                Spacer()

                // Ikon Indikator (Menggunakan SF Symbols)
                Image(systemName: iconName)
                    .font(.system(size: 33)) // Ukuran ikon yang proporsional
                    .foregroundColor(Color.PrimaryMainBlue)
                    .padding(.top, 4)
                    
            }

            // Baris Bawah: Deskripsi Analisis
            Text(description)
                .font(Text.CustomBody) // Menggunakan token Body Regular Anda
                .foregroundColor(.secondary)
                .lineLimit(nil) // Mengizinkan teks baris tak terbatas jika font membesar (HIG Compliant)
                .fixedSize(horizontal: false, vertical: true) // Mencegah teks terpotong secara vertikal

            // Optional pill — same visual treatment as
            // `SpeechIssueBadge` on the history card, so the
            // paralinguistic metric summary on Home reads as a
            // sibling of the per-recording badges on History.
            if let pillLabel {
                Text(pillLabel)
                    .font(Text.CustomFootnote)
                    .foregroundStyle(Color.SemanticMainRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.SemanticTintRed)
                    .clipShape(Capsule())
            }
        }
        .padding(20) // Padding bagian dalam kartu (sesuai Figma padding 10-20)
        .frame(width: 300, alignment: .leading) // Kartu mengambil lebar maksimal layar
        .background(Color(.systemBackground)) // Mengikuti Light/Dark mode secara native
        .clipShape(RoundedRectangle(cornerRadius: Radius.OverallCard))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.OverallCard)
                .stroke(Color.black.opacity(0.4), lineWidth: 0.3)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        OverallCard(
            title: "Pace",
            status: "Too Fast",
            description: "You're speaking too quickly. Focus on pausing between sentences and key ideas to improve clarity.",
            iconName: AppIcon.paceGauge,
            pillLabel: "Average: 168 WPM"
        )
        OverallCard(
            title: "Intonation",
            status: "Flat",
            description: "Read aloud daily and exaggerate your pitch up and down.",
            iconName: AppIcon.intonation,
            pillLabel: "Average: 0.07 PDQ"
        )
        OverallCard(
            title: "Articulation",
            status: "Fair",
            description: "Open your mouth clearly when speaking to improve word clarity.",
            iconName: AppIcon.articulation
        )
    }
    .padding()
}
