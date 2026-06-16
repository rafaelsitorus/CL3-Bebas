//
//  RecordingCoordinatorView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 09/06/26.
//

import SwiftUI

// MARK: - Recording View
struct RecordingView: View {
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
            // ── Timer ───────────────────────────────────────────────────
            Text(viewModel.formattedTime)
                .font(Text.CustomLargeTitle)
                .frame(maxWidth: .infinity)
                .padding(.top, 28)

            // ── Waveform ────────────────────────────────────────────────
            WaveformView(bars: viewModel.waveformBars)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // ── Mic Level Bar ───────────────────────────────────────────
            MicLevelView(level: viewModel.micLevel)
                .padding(.horizontal, 50)
                .padding(.top, 28)

            Spacer()

            // ── Pause / Resume Button ───────────────────────────────────
            PauseResumeButton(isPaused: viewModel.isPaused) {
                viewModel.togglePauseResume()
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 52)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Record Pitch")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Cancel / back — dismisses the cover (one-time form).
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onCancel?()
                } label: {
                    Image(systemName: "checklist")
                }
                .accessibilityLabel("Checklist")
            }

            // Confirm — finishes the recording and pushes ReviewSummary.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.confirmRecording()
                    onConfirm?()
                } label: {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel("Confirm")
            }
        }
        .alert("Microphone Access Denied",
               isPresented: $viewModel.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please allow microphone access in Settings to record your pitch.")
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let bars: [Float]

    private let barWidth:   CGFloat = 2.5
    private let barGap:     CGFloat = 1.5

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height          // e.g. 120 pt

            HStack(alignment: .center, spacing: barGap) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, amp in
                    // Minimum 8 pt so bars are always visible at rest
                    let barH = max(8, h * CGFloat(amp))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.primary)
                        .frame(width: barWidth, height: barH)
                        .animation(.easeOut(duration: 0.06), value: amp)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Mic Level View
private struct MicLevelView: View {
    let level: Float

    private let totalSegments  = 28
    private let activeColor    = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let inactiveColor  = Color(.systemGray4)

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "mic.fill")
                .font(.system(size: 15))
                .foregroundColor(.primary)

            // Fixed-size segments that stretch to fill available width
            HStack(spacing: 3) {
                ForEach(0..<totalSegments, id: \.self) { index in
                    let threshold = Float(index) / Float(totalSegments)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level > threshold ? activeColor : inactiveColor)
                        .frame(height: 22)
                        .animation(.easeOut(duration: 0.07), value: level)
                }
            }

            Text("\(Int(level * 100))%")
                .font(Text.CustomHeadline)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Pause / Resume Button
private struct PauseResumeButton: View {
    let isPaused: Bool
    let action:   () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Soft glow behind the button
                Circle()
                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.18))
                    .frame(width: 92, height: 92)

                Circle()
                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .frame(width: 72, height: 72)
                    .shadow(
                        color: Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.45),
                        radius: 16, x: 0, y: 6
                    )

                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(isPressed ? 0.93 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.07))  { isPressed = true  } }
                .onEnded   { _ in withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { isPressed = false } }
        )
        .animation(.easeInOut(duration: 0.15), value: isPaused)
        .accessibilityLabel(isPaused ? "Resume recording" : "Pause recording")
    }
}

// MARK: - Previews
#Preview("Recording – idle") {
    NavigationStack {
        RecordingView(viewModel: RecordPitchViewModel(isPreview: true))
    }
}

#Preview("Recording – active") {
    let vm = RecordPitchViewModel(isPreview: true)
    vm.isRecording = true
    vm.micLevel    = 0.65
    vm.waveformBars = (0..<60).map { i in
        let t = Float(i) / 60
        return max(0.15, abs(sin(t * .pi * 5)) * 0.85 + Float.random(in: -0.1...0.1))
    }
    return NavigationStack {
        RecordingView(viewModel: vm)
    }
}
