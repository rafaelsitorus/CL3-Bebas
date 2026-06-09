//
//  HistoryView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 08/06/26.
//

import SwiftUI

struct HistoryView: View {

    @State private var viewModel = HistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let onPaceTap: () -> Void
    
    init(onPaceTap: @escaping () -> Void = {}) {
        self.onPaceTap = onPaceTap
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                
                ForEach(viewModel.recordings) { recording in
                    HistoryCardLink(
                        title: recording.title,
                        date: recording.date,
                        duration: recording.duration,
                        issues: recording.issues,
                        onBackToHome: { dismiss() },
                        onPaceTap: {
                            onPaceTap()
                        }
                    )
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
        }
        // Design Token
        .background(Color(.systemGray6))
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)  
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    
                }label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .glassEffect(.regular, in: Circle())
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    
                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.plain)
                .glassEffect(.regular, in: Circle())
            }
        }
    }
}

#Preview {
    HistoryView()
}
