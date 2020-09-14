//
//  AspireNavigationBar.swift
//  Aspire Budgeting
//

import SwiftUI

struct AspireNavigationBar: View {

  @Binding var title: String

  var body: some View {
    ZStack {
      Color.primaryBackgroundColor
      VStack {
        Text(title)
          .font(.nunitoRegular(size: 20))
          .foregroundColor(.primaryTextColor)
      }
    }.padding(.bottom, 5)
  }
}

struct AspireNavigationBar_Previews: PreviewProvider {
  static var previews: some View {
    AspireNavigationBar(title: .constant("Dashboard"))
  }
}
