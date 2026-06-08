//
//  SharedComponents.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 09/06/26.
//

import SwiftUI


// MARK: - Back Button
struct RecordingBackButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .scaleEffect(isPressed ? 0.91 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.07))              { isPressed = true  } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false } }
        )
        .accessibilityLabel("Back")
    }
}

// MARK: - Check (Confirm) Button
struct CheckButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.3),
                            radius: 8, x: 0, y: 3)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.91 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.07))              { isPressed = true  } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false } }
        )
        .accessibilityLabel("Confirm")
    }
}
