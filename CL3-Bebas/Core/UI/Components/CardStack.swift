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
    let bodyIcon: String
    
    init(
        title: String,
        bodyText: String,
        image: Image,
        bodyIcon: String = AppIcon.speaker
    ) {
        self.title = title
        self.bodyText = bodyText
        self.image = image
        self.bodyIcon = bodyIcon
    }
}

struct CardStack: View {
    let cards: [CardStackItem]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let stackHeight: CGFloat
    let sideOffset: CGFloat
    let farSideOffset: CGFloat
    let dragThreshold: CGFloat
    
    @State private var selectedIndex = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    init(
        cards: [CardStackItem] = CardStack.dummyCards,
        cardWidth: CGFloat = 230,
        cardHeight: CGFloat = 320,
        stackHeight: CGFloat? = nil,
        sideOffset: CGFloat? = nil,
        farSideOffset: CGFloat? = nil,
        dragThreshold: CGFloat? = nil
    ) {
        self.cards = cards
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.stackHeight = stackHeight ?? cardHeight * 1.16
        self.sideOffset = sideOffset ?? cardWidth * 0.30
        self.farSideOffset = farSideOffset ?? cardWidth * 0.52
        self.dragThreshold = dragThreshold ?? cardWidth * 0.24
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                CardStackCard(
                    card: card,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(scale(for: index))
                    .offset(x: offset(for: index) + activeDragOffset(for: index))
                    .blur(radius: blurRadius(for: index))
                    .zIndex(zIndex(for: index))
                    .opacity(opacity(for: index))
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selectedIndex)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: stackHeight)
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
                
                guard abs(translation) > dragThreshold else { return }
                
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
            return -sideOffset
        case 1:
            return sideOffset
        case ...(-2):
            return -farSideOffset
        case 2...:
            return farSideOffset
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
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    private var horizontalPadding: CGFloat {
        cardWidth * 0.12
    }
    
    private var topPadding: CGFloat {
        cardHeight * 0.10
    }
    
    private var imageHeight: CGFloat {
        cardHeight * 0.47
    }
    
    private var imageBottomPadding: CGFloat {
        cardHeight * 0.06
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(card.title)
                .font(Text.CustomLargeTitle)
                .foregroundColor(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            HStack(spacing: 8) {
                Image(systemName: card.bodyIcon)
                    .font(Text.CustomHeadline)
                
                Text(card.bodyText)
                    .font(Text.CustomHeadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                .frame(height: imageHeight)
                .padding(.bottom, imageBottomPadding)
        }
        .padding(.top, topPadding)
        .padding(.horizontal, horizontalPadding)
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
        CardStack(
            cards: CardStack.dummyCards,
            cardWidth: 145,
            cardHeight: 150
        )
            .padding(.vertical, 32)
            .previewLayout(.sizeThatFits)
    }
}
