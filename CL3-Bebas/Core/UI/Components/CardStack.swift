//
//  CardStack.swift
//  CL3-Bebas
//
//  Created by Pangihutan Sitorus on 08/06/26.
//

import SwiftUI

struct CardStackItem: Identifiable {
    let id = UUID()
    let title: String
    let bodyText: String
    let image: Image
}

struct CardStack: View {
    private enum Dimension {
        static let cardWidth: CGFloat = 230
        static let cardHeight: CGFloat = 320
        static let stackHeight: CGFloat = 350
        static let sideOffset: CGFloat = 54
        static let farSideOffset: CGFloat = 96
        static let dragThreshold: CGFloat = 60
    }
    
    let cards: [CardStackItem]
    
    @State private var selectedIndex = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    init(cards: [CardStackItem] = CardStack.dummyCards) {
        self.cards = cards
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                CardStackCard(card: card)
                    .frame(width: Dimension.cardWidth, height: Dimension.cardHeight)
                    .scaleEffect(scale(for: index))
                    .offset(x: offset(for: index) + activeDragOffset(for: index))
                    .blur(radius: blurRadius(for: index))
                    .zIndex(zIndex(for: index))
                    .opacity(opacity(for: index))
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selectedIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Dimension.stackHeight)
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let translation = value.translation.width
                
                guard abs(translation) > Dimension.dragThreshold else { return }
                
                if translation < 0 {
                    moveToNextCard()
                } else {
                    moveToPreviousCard()
                }
            }
    }
    
    private func moveToNextCard() {
        selectedIndex = wrappedIndex(selectedIndex + 1)
    }
    
    private func moveToPreviousCard() {
        selectedIndex = wrappedIndex(selectedIndex - 1)
    }
    
    private func wrappedIndex(_ index: Int) -> Int {
        guard !cards.isEmpty else { return 0 }
        
        return (index % cards.count + cards.count) % cards.count
    }
    
    private func relativePosition(for index: Int) -> Int {
        guard !cards.isEmpty else { return 0 }
        
        let rawDistance = index - selectedIndex
        let cardCount = cards.count
        let halfCount = cardCount / 2
        
        if rawDistance > halfCount {
            return rawDistance - cardCount
        }
        
        if rawDistance < -halfCount {
            return rawDistance + cardCount
        }
        
        return rawDistance
    }
    
    private func offset(for index: Int) -> CGFloat {
        let position = relativePosition(for: index)
        
        switch position {
        case -1:
            return -Dimension.sideOffset
        case 1:
            return Dimension.sideOffset
        case ...(-2):
            return -Dimension.farSideOffset
        case 2...:
            return Dimension.farSideOffset
        default:
            return 0
        }
    }
    
    private func activeDragOffset(for index: Int) -> CGFloat {
        relativePosition(for: index) == 0 ? dragOffset : dragOffset * 0.16
    }
    
    private func scale(for index: Int) -> CGFloat {
        let distance = abs(relativePosition(for: index))
        
        switch distance {
        case 0:
            return 1.15
        case 1:
            return 0.96
        default:
            return 0.91
        }
    }
    
    private func opacity(for index: Int) -> Double {
        let distance = abs(relativePosition(for: index))
        
        switch distance {
        case 0:
            return 1
        case 1:
            return 0.94
        default:
            return 0.72
        }
    }
    
    private func blurRadius(for index: Int) -> CGFloat {
        let distance = abs(relativePosition(for: index))
        
        switch distance {
        case 0:
            return 0
        case 1:
            return 2
        default:
            return 4
        }
    }
    
    private func zIndex(for index: Int) -> Double {
        Double(cards.count - abs(relativePosition(for: index)))
    }
}

private struct CardStackCard: View {
    let card: CardStackItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(card.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.black)
            
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 20, weight: .regular))
                
                Text(card.bodyText)
                    .font(.system(size: 20, weight: .regular))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.whiteSC)
            .clipShape(RoundedRectangle(cornerRadius: Radius.MainCard, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
            
            Spacer(minLength: 0)
            
            card.image
                .resizable()
                .scaledToFit()
                .foregroundColor(.GreyAccentSC)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .padding(.bottom, 18)
        }
        .padding(.top, 32)
        .padding(.horizontal, 28)
        .background(Color.whiteSC)
        .clipShape(RoundedRectangle(cornerRadius: Radius.MainCard, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

private extension CardStack {
    static let dummyCards: [CardStackItem] = [
        CardStackItem(
            title: "(e)",
            bodyText: "Listen",
            image: Image(systemName: "mouth")
        ),
        CardStackItem(
            title: "(a)",
            bodyText: "Listen",
            image: Image(systemName: "waveform")
        ),
        CardStackItem(
            title: "(i)",
            bodyText: "Listen",
            image: Image(systemName: "speaker.wave.2")
        ),
        CardStackItem(
            title: "(o)",
            bodyText: "Listen",
            image: Image(systemName: "person.wave.2")
        ),
        CardStackItem(
            title: "(u)",
            bodyText: "Listen",
            image: Image(systemName: "textformat.abc")
        )
    ]
}

struct CardStack_Previews: PreviewProvider {
    static var previews: some View {
        CardStack()
            .padding(.vertical, 32)
            .previewLayout(.sizeThatFits)
    }
}
