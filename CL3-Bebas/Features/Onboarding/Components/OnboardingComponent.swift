//
//  OnboardingComponent.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//



import SwiftUI

// MARK: - Primary CTA Button

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isFullWidth: Bool = true

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.whiteSC)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.vertical, 16)
                .padding(.horizontal, isFullWidth ? 0 : 32)
                .background(Color.BluePrimaryBC)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Skip Button

struct SkipButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Skip")
                .font(.system(size: 15))
                .foregroundColor(Color.GreyAccentSC)
        }
    }
}

// MARK: - Back Navigation Button

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Branded App Icon Tile

struct AppIconTile: View {
    let systemName: String
    var size: CGFloat = 60
    var iconSize: CGFloat = 28
    var backgroundColor: Color = Color.BluePrimaryBC

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(backgroundColor)
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(.whiteSC)
        }
    }
}

// MARK: - Feature Row (Welcome screen)

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.whiteSC)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.BluePrimaryBC)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Text.CustomHeadline)
                    .foregroundColor(.primary)
                Text(description)
                    .font(Text.CustomHeadline)
                    .foregroundColor(Color.GreyAccentSC)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Language Selection Row

struct LanguageRow: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.rawValue)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? Color.BluePrimaryBC : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: AppIcon.doneIcon)
                        .foregroundColor(Color.BluePrimaryBC)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.BlueAccentBC : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.BluePrimaryBC.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Waveform Bar Visualizer

struct WaveformVisualizer: View {
    let levels: [CGFloat]
    var barColor: Color = Color.BluePrimaryBC
    var maxHeight: CGFloat = 60

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(barColor)
                    .frame(width: 3, height: max(4, levels[i] * maxHeight))
                    .animation(.easeInOut(duration: 0.1), value: levels[i])
            }
        }
        .frame(height: maxHeight)
    }
}

// MARK: - Pitch Script Text (highlighted bold lead + normal body)

struct PitchScriptText: View {
    var body: some View {
        Text(
            "\(Text("Hello, ").bold())\(Text("I'm practicing my delivery with Spitch to make my next presentation flawless.").foregroundStyle(.secondary))"
        )
        .font(Text.LargeTitleRegular)
        .multilineTextAlignment(.center)
        .lineSpacing(4)
    }
}

struct PitchScriptTextIndonesia: View {
    var body: some View {
        Text(
            "\(Text("Halo, ").bold())\(Text("Saya sedang berlatih penyampaian saya dengan Spitch agar presentasi saya berikutnya berjalan lancar.").foregroundStyle(.secondary))"
        )
        .font(Text.LargeTitleRegular)
        .multilineTextAlignment(.center)
        .lineSpacing(4)
    }
}

// MARK: - Onboarding Top Bar

struct OnboardingTopBar: View {
    var showBack: Bool = true
    let onBack: (() -> Void)?

    var body: some View {
        HStack {
            if showBack, let onBack {
                BackButton(action: onBack)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(height: 44)
    }
}
