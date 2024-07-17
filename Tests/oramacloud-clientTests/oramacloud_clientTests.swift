import XCTest
@testable import oramacloud_client

struct E2ETest1Document: Encodable & Decodable {
    let breed: String
}

@available(macOS 12.0, *)
final class oramacloud_clientTests: XCTestCase {
    func testE2ESearch() async throws {
        let clientParams = OramaClientParams(endpoint: "https://cloud.orama.run/v1/indexes/e2e-index-client-rv4bdd", apiKey: "eaXWAKLxn05lefXAfB3wAhuTq3VaXGqx")
        let oramaClient = OramaClient(params: clientParams)

        let searchParams = ClientSearchParams(
            term: "German",
            mode: SearchMode.fulltext,
            limit: 10,
            offset: nil,
            returning: nil,
            facets: nil
        )

        let expectation = XCTestExpectation(description: "Async search completes")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: URLRequest(url: URL(string: "https://cloud.orama.run/v1/indexes/e2e-index-client-rv4bdd")!))
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Status Code: \(httpResponse.statusCode)")
                }
                let responseData = String(data: data, encoding: .utf8)
                print("Response Data: \(responseData ?? "No response data")")
                
                let searchResults: SearchResults<E2ETest1Document> = try await oramaClient.search(query: searchParams)
                print(searchResults)
                XCTAssertGreaterThan(searchResults.count, 0)
                XCTAssertGreaterThan(searchResults.elapsed.raw, 0)
                XCTAssertNotNil(searchResults.elapsed.raw)
                XCTAssertGreaterThan(searchResults.hits.count, 0)
                expectation.fulfill()
            } catch {
                print("Search failed with error: \(error)")
                XCTFail("Search failed with error: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }
}

@available(macOS 12.0, *)
extension oramacloud_clientTests {
    static var allTests = [
        ("testE2ESearch", testE2ESearch)
    ]
}