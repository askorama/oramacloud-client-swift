import Foundation

class User {
  var userID: String
  private let userIDKey = "orama-user-id" 

  init() {
    self.userID = ""
    self.initUserID()
  }

  public func getUserID() -> String {
    return self.userID
  }

  private func initUserID() {
    guard let id = UserDefaults.standard.string(forKey: self.userIDKey) else {
      self.userID = Cuid.generateId()
      UserDefaults.standard.set(self.userID, forKey: self.userIDKey)
      return
    }

    self.userID = id
  }
}