//
//  QuickPitchView.swift
//  CL3-Bebas
//
//  Created by Theona Arlinton on 08/06/26.
//

import SwiftUI

struct QuickPitchView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: { dismiss() })

            // Title
            VStack(spacing: 6) {
                Text("Try a Quick Pitch")
                    .font(.system(size: 22, weight: .bold))
                Text("Record yourself reading this pitch below")
                    .font(.system(size: 14))
                    .foregroundColor(Color.GreyAccentSC)
            }
            .padding(.top, 8)

            Spacer()

            // Script / transcription area
            ZStack {
                if viewModel.recordingState == .idle || viewModel.recordingState == .playback {
                    PitchScriptText()
                        .padding(.horizontal, 32)
                } else {
                    // Show live transcript while recording
                    VStack(spacing: 16) {
                        PitchScriptText()
                            .opacity(0.25)
                            .padding(.horizontal, 32)

                        if !viewModel.transcribedText.isEmpty {
                            Text(viewModel.transcribedText)
                                .font(.system(size: 16))
                                .foregroundColor(Color.BluePrimaryBC)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.recordingState)

            Spacer()

            // Divider line (mimics the input underline in mockup)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
                .padding(.horizontal, 24)

            Spacer().frame(height: 32)

            // Waveform (only during recording)
            if viewModel.recordingState == .recording {
                WaveformVisualizer(levels: viewModel.audioLevels)
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                Spacer().frame(height: 24)
            }

            // Timer label during recording
            if viewModel.recordingState == .recording {
                Text(viewModel.elapsedTimeFormatted)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.GreyAccentSC)
                    .padding(.bottom, 12)
            }

            // Control buttons
            controlButtons

            Spacer().frame(height: 48)
        }
        .background(Color(.systemBackground))
        .alert("Microphone Access Denied", isPresented: $viewModel.showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow microphone and speech recognition access in Settings to record your pitch.")
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        switch viewModel.recordingState {

        case .idle:
            CircleIconButton(systemName: AppIcon.micIcon, action: {
                Task { await viewModel.handleMicTap() }
            })

        case .recording:
            HStack(spacing: 32) {
                // Done button (text)
                Button {
                    viewModel.submitRecording()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.BluePrimaryBC)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().stroke(Color.BluePrimaryBC, lineWidth: 1.5)
                        )
                }

                // Pause / stop
                CircleIconButton(systemName: AppIcon.pauseIcon, action: {
                    viewModel.stopRecording()
                })
            }

        case .playback:
            HStack(spacing: 32) {
                // Re-record
                CircleIconButton(
                    systemName: AppIcon.micIcon,
                    size: 52,
                    iconSize: 22,
                    backgroundColor: Color(.systemGray5),
                    action: {
                        Task { await viewModel.startRecording() }
                    }
                )
                // Play
                CircleIconButton(systemName: AppIcon.playIcon, action: {
                    // Playback logic (AVAudioPlayer)
                })
                // Submit
                CircleIconButton(
                    systemName: AppIcon.doneIcon,
                    size: 52,
                    iconSize: 22,
                    backgroundColor: Color.BluePrimaryBC,
                    action: {
                        viewModel.submitRecording()
                    }
                )
            }

        case .done:
            EmptyView()
        }
    }
}
