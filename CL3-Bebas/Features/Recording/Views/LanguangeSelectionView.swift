//
//  LanguageSelectionView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 09/06/26.
//

import SwiftUI

// MARK: - Language Selection View
struct RecordingLanguageSelectionView: View {
    @ObservedObject var viewModel: RecordPitchViewModel
    let onConfirm: (() -> Void)?
    let onCancel: (() -> Void)?

    init(
        viewModel: RecordPitchViewModel,
        onConfirm: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Section label ────────────────────────────────────────────
            Text("RECORD PITCH")
                .font(Text.CustomExpandedSH)
                .foregroundStyle(.secondary)
                .tracking(1.2)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)

            // ── Editable title ───────────────────────────────────────────
            EditableTitleRow(title: $viewModel.recordingTitle)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            // ── Helper text ──────────────────────────────────────────────
            Text("Please select the language you will use for your pitch before starting.")
                .font(Text.CustomHeadlineTextRegular)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)

            // ── Language picker ──────────────────────────────────────────
            LanguagePickerCard(selectedLanguage: $viewModel.selectedLanguage)
                .padding(.horizontal, 24)

            // ── Info banner ──────────────────────────────────────────────
            InfoBanner(text: "Pitch recordings are limited to 5 minutes.")
                .padding(.horizontal, 24)
                .padding(.top, 45)
                

            Spacer()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // ── Toolbar ────────────────────────────────────────────────
        // The coordinator exposes the back chevron (top-leading)
        // and the "Continue" checkmark (top-trailing) from this
        // root view. Both items are part of `LanguageSelectionView`
        // itself so they ride along with the root whenever it is
        // visible — they do not re-appear on the pushed
        // recording destination (where we want the system back
        // chevron instead).
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onCancel?()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Cancel recording")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Dismiss the keyboard first so it does not
                    // linger on the recording page after the push.
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                    onConfirm?()
                } label: {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel("Continue")
            }
        }
    }
}

// MARK: - Editable Title Row

private struct EditableTitleRow: View {
    @Binding var title: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("Untitled", text: $title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { isFocused = false }
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
                .truncationMode(.tail)

            Button {
                isFocused = true
            } label: {
                Image(systemName: AppIcon.editPencil.description)
                    .font(Text.CustomHeadlineTextRegular)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }
}
// MARK: - Language Picker Card

private struct LanguagePickerCard: View {
    @Binding var selectedLanguage: PitchLanguage

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(PitchLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                LanguagePickerRow(
                    language: language,
                    isSelected: selectedLanguage == language,
                    action: { selectedLanguage = language }
                )

                if index < PitchLanguage.allCases.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Language Picker Row

private struct LanguagePickerRow: View {
    let language: PitchLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.rawValue)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - Info Banner

private struct InfoBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 15))
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Previews

#Preview("English selected") {
    NavigationStack {
        RecordingLanguageSelectionView(viewModel: RecordPitchViewModel(isPreview: true))
    }
}

#Preview("Bahasa selected") {
    NavigationStack {
        RecordingLanguageSelectionView(viewModel: {
            let vm = RecordPitchViewModel(isPreview: true)
            vm.selectedLanguage = .bahasaIndonesia
            return vm
        }())
    }
}
