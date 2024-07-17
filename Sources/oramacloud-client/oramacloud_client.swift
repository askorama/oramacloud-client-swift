import Foundation

@available(macOS 12.0, *)
final class OramaClient {
  private let id: String
  private let apiKey: String
  private let endpoint: String

  private var searchDebounceTimer: Timer?
  private var searchRequestCounter: Int = 0 

  init(params: OramaClientParams) {
    self.id = UUID().uuidString // @todo: make it a CUID
    self.apiKey = params.apiKey
    self.endpoint = params.endpoint
  }

  public func search<T: Encodable & Decodable>(query: ClientSearchParams) async throws -> SearchResults<T> {
    // let concurrentRequestNumber = (self.searchRequestCounter += 1)

    guard let oramaEndpointURL = URL(string: "\(self.endpoint)/search?api-key=\(self.apiKey)") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: oramaEndpointURL)
    let httpBody = try self.encodeSearchQuery(query: query, version: "1.0.9", id: self.id) // @todo: use actual version

    request.httpBody = httpBody
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    let (responseData, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
      let responseDataString = String(data: responseData, encoding: .utf8) ?? "No response data"
      print("HTTP Status Code: \(httpResponse.statusCode)")
      print("Response Data: \(responseDataString)")
      throw URLError(.badServerResponse)
    }

    let decoder = JSONDecoder()
    let searchResults = try decoder.decode(SearchResults<T>.self, from: responseData)

    return searchResults
  }

  public func encodeSearchQuery(query: ClientSearchParams, version: String, id: String) throws -> Data {
    let encoder = JSONEncoder()
    guard let jsonData = try? encoder.encode(query),
      let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw URLError(.cannotDecodeRawData)
    }

    guard let encodedJSON = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      throw URLError(.cannotDecodeRawData)
    }

    let bodyString = "q=\(encodedJSON)&version=\(version)&id=\(id)"

    guard let bodyData = bodyString.data(using: .utf8) else {
      throw URLError(.cannotDecodeRawData)
    }

    return bodyData
  }
}
