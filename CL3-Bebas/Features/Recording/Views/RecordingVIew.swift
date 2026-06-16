//
//  RecordingView.swift
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
        VStack(spacing: 0) {
            // ── Header ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("RECORD PITCH")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Text("Title Recording 1")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // ── Timer ──────────────────────────────────────────────────
            Text(viewModel.formattedTime)
                .font(.system(size: 56, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

            // ── Waveform ───────────────────────────────────────────────
            WaveformView(bars: viewModel.waveformBars)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .padding(.horizontal, 20)
                .padding(.top, 24)

            Spacer()

            // ── Bottom Controls ────────────────────────────────────────
            if viewModel.isRecording {
                // Recording active: show re-record, pause, stop
                RecordingControlBar(
                    isPaused: viewModel.isPaused,
                    onReRecord: { viewModel.showReRecordAlert = true },
                    onPauseResume: { viewModel.togglePauseResume() },
                    onStop: { viewModel.showFinishAlert = true }
                )
                .padding(.bottom, 48)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                // Not yet recording: show mic button to start
                StartRecordButton {
                    viewModel.beginRecordingSession()
                }
                .padding(.bottom, 48)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onCancel?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .accessibilityLabel("Back")
            }
        }
        // ── Alerts ─────────────────────────────────────────────────────
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
        // Re-record confirmation
        .alert("Are you sure you want to re-record your pitch?",
               isPresented: $viewModel.showReRecordAlert) {
            Button("Yes") {
                viewModel.reRecord()
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("If you re-record, the previously recorded pitch will be lost.")
        }
        // Finish / analyze confirmation
        .alert("Are you sure you want to finish and analyze the recording?",
               isPresented: $viewModel.showFinishAlert) {
            Button("No", role: .cancel) { }
            Button("Finish") {
                viewModel.finishRecording()
                onConfirm?()
            }
        } message: {
            Text("The recording will be processed and analyzed.")
        }
        // Time limit reached
        .alert("Recording time limit reached",
               isPresented: $viewModel.showTimeLimitAlert) {
            Button("Okay") {
                viewModel.confirmRecording()
                onConfirm?()
            }
        } message: {
            Text("The maximum recording limit is 5 minutes. Your current session has been saved and will now be analyzed.")
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isRecording)
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

// MARK: - Start Record Button (mic icon — initial state)
private struct StartRecordButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.12))
                    .frame(width: 88, height: 88)

                Circle()
                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .frame(width: 68, height: 68)
                    .shadow(
                        color: Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.4),
                        radius: 14, x: 0, y: 5
                    )

                Image(systemName: "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.07))  { isPressed = true  } }
                .onEnded   { _ in withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { isPressed = false } }
        )
        .accessibilityLabel("Start recording")
    }
}


// MARK: - Recording Control Bar (re-record, pause, stop)
private struct RecordingControlBar: View {
    let isPaused: Bool
    let onReRecord: () -> Void
    let onPauseResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 40) {
            // Re-record button (circle outline, red)
            RecordingActionButton(
                systemImage: "arrow.trianglehead.counterclockwise",
                color: .red,
                size: 28,
                action: onReRecord,
                label: "Re-record"
            )

            // Pause / Resume button (blue filled circle)
            Button(action: onPauseResume) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.4),
                            radius: 12, x: 0, y: 4
                        )

                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: isPaused)
            .accessibilityLabel(isPaused ? "Resume recording" : "Pause recording")

            // Stop button (red filled square)
            RecordingActionButton(
                systemImage: "square.fill",
                color: .red,
                size: 22,
                action: onStop,
                label: "Stop recording"
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recording Action Button (re-record & stop)
private struct RecordingActionButton: View {
    let systemImage: String
    let color: Color
    let size: CGFloat
    let action: () -> Void
    let label: String

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
                .scaleEffect(isPressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.07))  { isPressed = true  } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { isPressed = false } }
        )
        .accessibilityLabel(label)
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
