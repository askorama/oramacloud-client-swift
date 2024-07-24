import Foundation

@available(macOS 13.0, *)
final class OramaClient {
    let apiKey: String
    let endpoint: String
    private let id: String
    private let debouncer = Debouncer()
    private var searchRequestCounter: Int = 0

    init(params: OramaClientParams) {
        id = Cuid.generateId()
        apiKey = params.apiKey
        endpoint = params.endpoint
    }

    public func search<T: Codable>(query: ClientSearchParams, config: SearchRequestConfig? = SearchRequestConfig(debounce: nil)) async throws -> SearchResults<T> {
        let shouldDebounce = (config?.debounce ?? 0) > 0

        if shouldDebounce {
            return try await withCheckedThrowingContinuation { continuation in
                debouncer.debounce(interval: .milliseconds(Int64(config?.debounce ?? 0))) {
                    Task {
                        do {
                            let result = try await self.performSearch(query: query) as SearchResults<T>
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } else {
            return try await performSearch(query: query)
        }
    }

    private func performSearch<T: Codable>(query: ClientSearchParams) async throws -> SearchResults<T> {
        guard let url = URL(string: "\(endpoint)/search?api-key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpBody = try encodeSearchQuery(query: query)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseDataString = String(data: data, encoding: .utf8) ?? "No response data"
            print("HTTP Status Code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            print("Response Data: \(responseDataString)")
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(SearchResults<T>.self, from: data)
    }

    func encodeSearchQuery(query: ClientSearchParams) throws -> Data {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(query)

        guard let jsonString = String(data: jsonData, encoding: .utf8)?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.cannotDecodeRawData)
        }

        let bodyString = "q=\(jsonString)&version=1.0.9&id=\(id)"

        guard let bodyData = bodyString.data(using: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        return bodyData
    }
}
