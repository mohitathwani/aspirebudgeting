//
//  AspireMasterView.swift
//  Aspire Budgeting
//

import SwiftUI

struct AspireMasterView: View {
  //TODO: Remove GoogleSheetsManager
  @EnvironmentObject var sheetsManager: GoogleSheetsManager
  @EnvironmentObject var appCoordinator: AppCoordinator

  let tabBarItems = [TabBarItem(imageName: "rectangle.grid.1x2", title: "Dashboard"),
                     TabBarItem(imageName: "creditcard", title: "Accounts"),
                     TabBarItem(imageName: "arrow.up.arrow.down", title: "Transactions"),
                     TabBarItem(imageName: "gear", title: "Settings")]

  @State private var selectedTab = 0
  var body: some View {
    VStack {
      AspireNavigationBar()
        .edgesIgnoringSafeArea(.all)
        .frame(maxHeight: 65)
      //TODO: Remove Segmented View
//      AspireSegmentedView(selectedSegment: $selectedSegment)
        if selectedTab == 0 {
          DashboardView(viewModel: appCoordinator.dashboardVM)
            .frame(height: UIScreen.main.bounds.height - 250)
        } else if selectedTab == 1 {
          AccountBalancesView()
        }



      TabBarView(tabBarItems: tabBarItems,
                 prominentItemImageName: "plus",
                 selectedTab: $selectedTab) {
                  print("Hoogah boogah")
      }
      .frame(height: 95)
      .padding(.horizontal, 5)
    }
  }
}

struct AspireMasterView_Previews: PreviewProvider {
  static var previews: some View {
    AspireMasterView()
  }
}
