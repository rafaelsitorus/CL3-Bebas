//
//  LanguangeSelectionView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 09/06/26.
//

import SwiftUI

// MARK: - Language Selection View
struct RecordingLanguageSelectionView: View {
    @ObservedObject var viewModel: RecordPitchViewModel
    let onConfirm: (() -> Void)?
    
    init(
        viewModel: RecordPitchViewModel,
        onConfirm: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onConfirm = onConfirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Language Picker ─────────────────────────────────────────
            LanguagePickerCard(selectedLanguage: $viewModel.selectedLanguage)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            // ── Helper Text ─────────────────────────────────────────────
            Text("Please select the language you wish to use for your pitch, and record your pitch no more than 5 minutes.")
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Record Pitch")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.confirmLanguageSelection()
                    onConfirm?()
                } label: {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

// MARK: - Language Picker Card
private struct LanguagePickerCard: View {
    @Binding var selectedLanguage: PitchLanguage

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(PitchLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedLanguage = language
                    }
                } label: {
                    HStack {
                        Text(language.rawValue)
                            .font(.system(size: 16))
                            .foregroundColor(
                                selectedLanguage == language
                                    ? Color(red: 0.0, green: 0.48, blue: 1.0)
                                    : .primary
                            )
                        Spacer()
                        if selectedLanguage == language {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                                .font(.system(size: 14, weight: .semibold))
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)

                if index < PitchLanguage.allCases.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Previews (isPreview: true → no AVFoundation, no crash)
#Preview("English selected") {
    RecordingLanguageSelectionView(viewModel: RecordPitchViewModel(isPreview: true))
}

#Preview("Bahasa selected") {
    RecordingLanguageSelectionView(viewModel: {
        let vm = RecordPitchViewModel(isPreview: true)
        vm.selectedLanguage = .bahasaIndonesia
        return vm
    }())
}
