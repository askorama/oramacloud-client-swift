import Foundation

class User {
    var userID: String
    private let userIDKey = "orama-user-id"

    init() {
        userID = ""
        initUserID()
    }

    public func getUserID() -> String {
        return userID
    }

    private func initUserID() {
        guard let id = UserDefaults.standard.string(forKey: userIDKey) else {
            userID = Cuid.generateId()
            UserDefaults.standard.set(userID, forKey: userIDKey)
            return
        }

        userID = id
    }
}
