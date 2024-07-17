import Foundation

@available(macOS 12.0, *)
class OramaClient {
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
    let startTime = Date()

    guard let oramaEndpointURL = URL(string: "\(self.endpoint)/v1/search") else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: oramaEndpointURL)
    let encoder = JSONEncoder()
    let data = try encoder.encode(query)

    request.httpBody = data
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let (responseData, _) = try await URLSession.shared.data(for: request)

    let decoder = JSONDecoder()
    var searchResults = try decoder.decode(SearchResults<T>.self, from: responseData)

    let endTime = Date()
    let elapsed = Int(endTime.timeIntervalSince(startTime))

    searchResults.elapsed = Elapsed(raw: elapsed, formatted: "\(elapsed)ms")

    return searchResults
  }
}
