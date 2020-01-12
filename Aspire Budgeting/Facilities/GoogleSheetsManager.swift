//
//  GoogleSheetsManager.swift
//  Aspire Budgeting
//
//  Created by TeraMo Labs on 11/1/19.
//  Copyright © 2019 TeraMo Labs. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST
import GTMSessionFetcher
import os.log

extension Notification.Name {
  static let hasSheetInDefaults = Notification.Name("hasSheetInDefaults")
}

protocol AspireUserDefaults {
  func data(forKey defaultName: String) -> Data?
}

extension UserDefaults: AspireUserDefaults {}

final class GoogleSheetsManager: ObservableObject {
  enum SupportedAspireVersions: String {
    case twoEight = "2.8"
    case three = "3.0"
  }
  
  static let defaultsSheetsKey = "Aspire_Sheet"
  
  private let sheetsService: GTLRService
  private let getSpreadsheetsQuery: GTLRSheetsQuery_SpreadsheetsValuesGet
  
  private var authorizer: GTMFetcherAuthorizationProtocol?
  private var authorizerNotificationObserver: NSObjectProtocol?
  
  private var ticket: GTLRServiceTicket?
  
  private var userDefaults: AspireUserDefaults
  
  public var defaultFile: File?
  
  @Published public private(set) var aspireVersion: SupportedAspireVersions?
  @Published public private(set) var error: GoogleDriveManagerError?
  @Published public private(set) var dashboardMetadata: DashboardMetadata?
  @Published public private(set) var transactionCategories: [String]?
  @Published public private(set) var transactionAccounts: [String]?
  
  init(sheetsService: GTLRService = GTLRSheetsService(),
       getSpreadsheetsQuery: GTLRSheetsQuery_SpreadsheetsValuesGet = GTLRSheetsQuery_SpreadsheetsValuesGet.query(withSpreadsheetId: "", range: ""),
       userDefaults: AspireUserDefaults = UserDefaults.standard) {
    self.sheetsService = sheetsService
    self.getSpreadsheetsQuery = getSpreadsheetsQuery
    self.userDefaults = userDefaults
    
    subscribeToAuthorizerNotification()
  }
  
  private func subscribeToAuthorizerNotification() {
    os_log("Subscribing to Authorizer notification",
           log: .sheetsManager, type: .default)
    authorizerNotificationObserver = NotificationCenter.default.addObserver(forName: .authorizerUpdated, object: nil, queue: nil) { [weak self] (notification) in
      guard let weakSelf = self else {
        return
      }
      
      os_log("Received authorizer from notification",
             log: .default, type: .default)
      weakSelf.assignAuthorizer(from: notification)
    }
  }
  
  private func assignAuthorizer(from notification: Notification) {
    guard let userInfo = notification.userInfo,
      let authorizer = userInfo[Notification.Name.authorizerUpdated] as? GTMFetcherAuthorizationProtocol else {
        os_log("No authorizer found in notification",
               log: .sheetsManager, type: .error)
        return
    }
    
    os_log("Assigning authorizer",
           log: .sheetsManager, type: .default)
    self.authorizer = authorizer
  }
  
  private func fetchData(spreadsheet: File, spreadsheetRange: String, completion: @escaping (GTLRSheets_ValueRange) -> Void) {
    guard let authorizer = self.authorizer else {
      os_log("Nil authorizer while trying to fetch data",
             log: .sheetsManager, type: .error)
      self.error = GoogleDriveManagerError.nilAuthorizer
      return
    }
    
    sheetsService.authorizer = authorizer
    getSpreadsheetsQuery.isQueryInvalid = false
    
    getSpreadsheetsQuery.spreadsheetId = spreadsheet.id
    getSpreadsheetsQuery.range = spreadsheetRange
    
    ticket = sheetsService.executeQuery(getSpreadsheetsQuery, completionHandler: { (_, data, error) in
      if let valueRange = data as? GTLRSheets_ValueRange {
        os_log("Received GTLRSheets_ValueRange from Google Sheets",
               log: .sheetsManager, type: .default)
        self.error = nil
        completion(valueRange)
      }
      
      if let error = error as NSError? {
        if error.domain == kGTLRErrorObjectDomain {
          os_log("Encountered kGTLRErrorObjectDomain: %{public}s",
                 log: .sheetsManager, type: .error,
                 error.localizedDescription)
          self.error = GoogleDriveManagerError.inconsistentSheet
        } else {
          os_log("No internet connection",
                 log: .sheetsManager, type: .error)
          self.error = GoogleDriveManagerError.noInternet
        }
      }
    })
  }
  
  func persistSheetID(spreadsheet: File) {
    do {
      let data = try JSONEncoder().encode(spreadsheet)
      UserDefaults.standard.set(data, forKey: GoogleSheetsManager.defaultsSheetsKey)
    } catch {
      fatalError("This should've never happened!!")
    }
  }
  
  func checkDefaultsForSpreadsheet() {
    guard let data = userDefaults.data(forKey: GoogleSheetsManager.defaultsSheetsKey),
      let file = try? JSONDecoder().decode(File.self, from: data) else {
        os_log("No default Google Sheet found",
               log: .sheetsManager, type: .default)
        return
    }
    
    os_log("Default Google Sheet found.",
           log: .sheetsManager, type: .default)
    defaultFile = file
    NotificationCenter.default.post(name: .hasSheetInDefaults, object: nil, userInfo: [Notification.Name.hasSheetInDefaults: file])
  }
  
  func getTransactionCategories(spreadsheet: File) {
    os_log("Fetching transaction categories",
           log: .sheetsManager, type: .default)
    
    guard let version = self.aspireVersion else {
      os_log("Aspire version is nil",
             log: .sheetsManager, type: .error)
      fatalError("Aspire Version is nil")
    }
    
    let range: String
    switch version {
    case .twoEight:
      range = "BackendData!B2:B"
    case .three:
      range = "BackendData!F2:F"
    }
    
    fetchData(spreadsheet: spreadsheet, spreadsheetRange: range) { (valueRange) in
      guard let values = valueRange.values as? [[String]] else {
        fatalError("Values from Google sheet is nil")
      }
      
      os_log("Received transaction categories",
             log: .sheetsManager, type: .default)
      self.transactionCategories = values.map {$0.first!}
      
    }
  }
  
  func getTransactionAccounts(spreadsheet: File) {
    os_log("Fetching transaction accounts",
           log: .sheetsManager, type: .default)
    
    guard let version = self.aspireVersion else {
      os_log("Aspire version is nil",
             log: .sheetsManager, type: .error)
      fatalError("Aspire Version is nil")
    }
    
    let range: String
    switch version {
    case .twoEight:
      range = "BackendData!E2:E"
    case .three:
      range = "BackendData!H2:H"
    }
    
    fetchData(spreadsheet: spreadsheet, spreadsheetRange: range) { (valueRange) in
      guard let values = valueRange.values as? [[String]] else {
        fatalError("Values from Google sheet is nil")
      }
      
      os_log("Received transaction accounts",
             log: .sheetsManager, type: .default)
      
      self.transactionAccounts = values.map {$0.first!}
    }
  }
  
  func verifySheet(spreadsheet: File) {
    os_log("Verifying selected Google Sheet",
           log: .sheetsManager, type: .default)
    
    fetchData(spreadsheet: spreadsheet, spreadsheetRange: "BackendData!2:2") { (valueRange) in
      if let version = valueRange.values?.first?.last as? String {
        self.aspireVersion = SupportedAspireVersions(rawValue: version)
        self.persistSheetID(spreadsheet: spreadsheet)
        self.getTransactionCategories(spreadsheet: spreadsheet)
        self.getTransactionAccounts(spreadsheet: spreadsheet)
      }
    }
  }
  
  func fetchCategoriesAndGroups(spreadsheet: File) {
    os_log("Fetching Categories and groups",
           log: .sheetsManager, type: .default)
    
    fetchData(spreadsheet: spreadsheet, spreadsheetRange: "Dashboard!H4:O") { (valueRange) in
      if let values = valueRange.values as? [[String]] {
        self.dashboardMetadata = DashboardMetadata(rows: values)
      }
    }
  }
  
  private func createSheetsValueRangeFrom(amount: String,
                                          date: Date,
                                          category: Int,
                                          account: Int,
                                          transactionType: Int,
                                          approvalType: Int) -> GTLRSheets_ValueRange {
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    
    let sheetsValueRange = GTLRSheets_ValueRange()
    sheetsValueRange.majorDimension = kGTLRSheets_ValueRange_MajorDimension_Rows
    sheetsValueRange.range = "Transactions!B:H"
    
    var valuesToInsert = [String]()
    valuesToInsert.append(dateFormatter.string(from: date))
    
    if transactionType == 0 {
      valuesToInsert.append("")
      valuesToInsert.append(amount)
    } else {
      valuesToInsert.append(amount)
      valuesToInsert.append("")
    }
    
    valuesToInsert.append(transactionCategories![category])
    valuesToInsert.append(transactionAccounts![account])
    valuesToInsert.append("Added from Aspire iOS app")
    
    guard let version = self.aspireVersion else {
      fatalError("Aspire Version is nil")
    }
    
    switch version {
    case .twoEight:
      if approvalType == 0 {
        valuesToInsert.append("🆗")
      } else {
        valuesToInsert.append("⏺")
      }
      
    case .three:
      if approvalType == 0 {
        valuesToInsert.append("✅")
      } else {
        valuesToInsert.append("🅿️")
      }
    }
    
    sheetsValueRange.values = [valuesToInsert]
    return sheetsValueRange
  }
  
  func addTransaction(amount: String, date: Date, category: Int, account: Int, transactionType: Int, approvalType: Int, completion: @escaping (Bool) -> Void) {
    
    os_log("Adding transaction",
           log: .sheetsManager, type: .default)
    
    let valuesToInsert = createSheetsValueRangeFrom(amount: amount, date: date, category: category, account: account, transactionType: transactionType, approvalType: approvalType)
    
    guard let authorizer = self.authorizer else {
      os_log("Aspire version is nil",
      log: .sheetsManager, type: .error)
      self.error = GoogleDriveManagerError.nilAuthorizer
      return
    }
    
    sheetsService.authorizer = authorizer
  
    let appendQuery = GTLRSheetsQuery_SpreadsheetsValuesAppend.query(withObject: valuesToInsert, spreadsheetId: defaultFile!.id, range: valuesToInsert.range!)
    
    appendQuery.valueInputOption = kGTLRSheetsValueInputOptionUserEntered
    
    ticket = sheetsService.executeQuery(appendQuery, completionHandler: { (_, _, error) in
      if let error = error as NSError? {
        if error.domain == kGTLRErrorObjectDomain {
          os_log("Encountered kGTLRErrorObjectDomain: %{public}s",
          log: .sheetsManager, type: .error,
          error.localizedDescription)
          self.error = GoogleDriveManagerError.inconsistentSheet
        } else {
          os_log("No internet connection",
          log: .sheetsManager, type: .error)
          self.error = GoogleDriveManagerError.noInternet
        }
      }
      completion(error == nil)
    })
  }
}
