import Foundation

typealias JSObject<T: Decodable & Encodable> = [String: T]

extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)

        guard let dictionary = jsonObject as? [String: Any] else {
            throw NSError()
        }

        return dictionary
    }
}

extension Dictionary {
    func percentEscaped() -> String {
        return map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }
}

// ======================== CLIENT TYPES ========================

struct OramaClientParams: Codable {
    let endpoint: String
    let apiKey: String
}

enum SearchMode: String, Codable {
    case fulltext
    case vector
    case hybrid
}

// ======================== SEARCH TYPES ========================

struct Elapsed: Codable {
    let raw: Int
    let formatted: String
}

struct Hit<T>: Codable where T: Codable {
    let id: String
    let score: Float
    let document: T
}

struct SearchResults<T>: Codable where T: Codable {
    let count: Int
    let hits: [Hit<T>]
    var elapsed: Elapsed
    // @todo: add support for facets
}

struct SearchRequestConfig {
    let debounce: Int?
}

struct SearchRequestPayload: Encodable {
    let q: Data
    let version: String
    let id: String

    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)

        guard let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError(domain: "Invalid JSON Object", code: 1, userInfo: nil)
        }
        return jsonObject
    }
}

// ======================== ERRORS ========================

enum OramaClientError: Error {
    case runtimeError(String)
}