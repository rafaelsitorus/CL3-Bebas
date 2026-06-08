//
//  HistoryView.swift
//  CL3-Bebas
//
//  Created by Danendra Darmawansyah on 08/06/26.
//

import SwiftUI

struct HistoryView: View {

    @State private var viewModel = HistoryViewModel()

    var body: some View {
            NavigationStack{
                ScrollView {
                    LazyVStack(spacing: 10) {
                        
                        ForEach(viewModel.recordings) { recording in
                            HistoryCard(
                                title: recording.title,
                                date: recording.date,
                                duration: recording.duration,
                                issues: recording.issues
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
}

#Preview {
    HistoryView()
}
