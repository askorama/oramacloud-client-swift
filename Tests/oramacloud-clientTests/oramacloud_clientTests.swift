import XCTest
@testable import oramacloud_client

struct E2ETest1Document: Encodable & Decodable {
    let breed: String
}

final class oramacloud_clientTests: XCTestCase {
    func e2eTestSearch() throws {
        let clientParams = OramaClientParams(apiKey: "your-api-key", endpoint: "https://your-api-endpoint.com")
        let oramaClient = OramaClient(params: clientParams)

        let searchParams = ClientSearchParams(
            term: "German",
            mode: .fulltext,
            limit: 10,
            offset: nil,
            returning: nil,
            facets: nil
        )

        Task {
            do {
                let searchResults: SearchResults<E2ETest1Document> = try await oramaClient.search(query: searchParams)
                XCTAssertGreaterThan(searchResults.count, 0)
                XCTAssertGreaterThan(searchResults.elapsed.raw, 0)
                XCTAssertNotNil(searchResults.elapsed.raw)
                XCTAssertGreaterThan(searchResults.hits.count, 0)

            } catch {
                print("Search failed with error: \(error)")
            }
        }

    }
}
