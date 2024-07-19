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

struct OramaClientParams: Encodable, Decodable {
    let endpoint: String
    let apiKey: String
}

enum SearchMode: String, Encodable, Decodable {
    case fulltext
    case vector
    case hybrid
}

// ======================== SEARCH TYPES ========================

struct Elapsed: Encodable, Decodable {
    let raw: Int
    let formatted: String
}

struct Hit<T>: Encodable, Decodable where T: Encodable & Decodable {
    let id: String
    let score: Float
    let document: T
}

struct SearchResults<T>: Encodable, Decodable where T: Encodable & Decodable {
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

// ======================== FACETS TYPES ========================

enum Order: String, Decodable, Encodable {
    case asc
    case desc
}

struct FacetLimitOrder: Encodable, Decodable {
    let limit: Int?
    let order: Order?
    let offset: Int?
}

enum FacetsString: Encodable, Decodable {
    case JSObject(FacetLimitOrder)
}

struct FacetsNumberRange: Encodable, Decodable {
    let from: Int
    let to: Int
}

struct FacetsNumber: Encodable, Decodable {
    let ranges: [FacetsNumberRange]
}

struct FacetsBoolean: Encodable, Decodable {
    let isTrue: Bool?
    let isFalse: Bool?
}

struct Facets: Encodable, Decodable {
    let string: JSObject<FacetsString>?
    let number: JSObject<FacetsNumber>?
    let boolean: JSObject<FacetsBoolean>?
}
