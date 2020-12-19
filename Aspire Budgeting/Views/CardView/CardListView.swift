//
//  CardListView.swift
//  Aspire Budgeting
//

import SwiftUI

struct DasboardCardsListView: View {

  let cardViewItems: [BaseCardView<DashboardCardView>.CardViewItem]

  var body: some View {
    GeometryReader {g in
      ScrollView {
        VStack {
          ForEach(0..<self.cardViewItems.count) { idx in
            GeometryReader { geo in
              BaseCardView<DashboardCardView>(
//                       cardViewItem: self.cardViewItems[idx],
                       minY: g.frame(in: .global).minY,
                       curY: geo.frame(in: .global).minY,
                baseColor: DasboardCardsListView.baseColors[idx % DasboardCardsListView.baseColors.count]) {
                DashboardCardView(cardViewItem: self.cardViewItems[idx],
                                  baseColor: DasboardCardsListView.baseColors[idx % DasboardCardsListView.baseColors.count])
              }
                .padding(.horizontal)
            }.frame(maxWidth: .infinity)
              .frame(height: 125)
          }
        }
      }.background(Color.primaryBackgroundColor)
    }
  }
}

//MARK:- Internal Types
extension DasboardCardsListView {
  static let baseColors: [Color] =
    [.materialRed800,
     .materialPink800,
     .materialPurple800,
     .materialDeepPurple800,
     .materialIndigo800,
     .materialBlue800,
     .materialLightBlue800,
     .materialTeal800,
     .materialGreen800,
     .materialBrown800,
     .materialGrey800,
    ].shuffled()

  struct CardViewItem {
    let title: String
    let availableTotal: AspireNumber
    let budgetedTotal: AspireNumber
    let spentTotal: AspireNumber
    let progressFactor: Double
    let categories: [Category]
  }
}

struct CardListView_Previews: PreviewProvider {
  static var previews: some View {
    DasboardCardsListView(cardViewItems: MockProvider.cardViewItems)
  }
}
