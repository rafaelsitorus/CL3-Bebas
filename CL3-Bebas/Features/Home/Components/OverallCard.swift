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
    let iconName: String
    var pillLabel: String? = nil

    private var description: String {
        switch (title, status) {
        case ("Pace", "Too Slow"), ("Pace", "Slow"):
            return "You're speaking too slowly. Pick up your pace to keep listeners engaged and energized."
        case ("Pace", "Ideal"), ("Pace", "Normal"):
            return "Your pace is spot on. Listeners can follow your ideas comfortably without feeling rushed."
        case ("Pace", _): // Too Fast / Fast
            return "You're speaking too fast. Pause between key ideas to give listeners time to process words."
        case ("Articulation", "Clear"):
            return "Your words are coming through clearly. Keep articulating with confidence and precision."
        case ("Articulation", _): // Unclear / Fair
            return "Some words are unclear. Open your mouth fully and slow down on complex words."
        case ("Intonation", "Flat"):
            return "Your delivery sounds monotone. Exaggerate your pitch on key words to hold attention."
        case ("Intonation", _): 
            return "Your vocal tone is engaging. Natural pitch variation keeps your audience locked in."
        default:
            return "Keep practising to improve your speaking confidence and clarity."
        }
    }
    
    var body: some View {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(Text.CustomHeadlineCard)
                            .foregroundColor(Color(.black))
                        Text(status)
                            .font(Text.TitleRegular)
                            .foregroundColor(Color(.black))
                    }
                    Spacer()
                    Image(systemName: iconName)
                        .font(.system(size: 33))
                        .foregroundColor(Color.PrimaryMainBlue)
                        .padding(.top, 4)
                }

                Text(description)
                    .font(Text.CustomBody)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

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
            .padding(20)
            .frame(width: 300, height: 240, alignment: .leading)
            .background(Color(.systemBackground))
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
            iconName: AppIcon.paceGauge,
            pillLabel: "Average: 168 WPM"
        )
        OverallCard(
            title: "Intonation",
            status: "Expressive",
            iconName: AppIcon.intonation,
            pillLabel: "Average: 0.07 PDQ"
        )
        OverallCard(
            title: "Articulation",
            status: "Unclear",
            iconName: AppIcon.articulation
        )
    }
    .padding()
}
