import XCTest
@testable import oramacloud_client

struct E2ETest1Document: Encodable & Decodable {
    let breed: String
}

let e2eEndpoint = "https://cloud.orama.run/v1/indexes/e2e-index-client-rv4bdd"
let e2eApiKey = "eaXWAKLxn05lefXAfB3wAhuTq3VaXGqx"

@available(macOS 12.0, *)
final class oramacloud_clientTests: XCTestCase {
    func testEncodeSearchQuery() throws {
        let clientParams = OramaClientParams(endpoint: e2eEndpoint, apiKey: e2eApiKey)
        let orama = OramaClient(params: clientParams)

        let params = ClientSearchParams.builder(term: "German", mode: .fulltext)
            .limit(10)
            .offset(20)
            .returning(["title", "description"])
            .build()
        
        let encodedSearchQuery = try orama.encodeSearchQuery(query: params, version: "123", id: "456")

        XCTAssertNotNil(encodedSearchQuery)
    }

    func testE2ESearch() async throws {
        let expectation = XCTestExpectation(description: "Async search completes")
        let clientParams = OramaClientParams(endpoint: e2eEndpoint, apiKey: e2eApiKey)
        let orama = OramaClient(params: clientParams)

        let params = ClientSearchParams.builder(term: "German", mode: .fulltext)
            .limit(10)
            .build()

        Task {
            do {
                let searchResults: SearchResults<E2ETest1Document> = try await orama.search(query: params)

                XCTAssertGreaterThan(searchResults.count, 0)
                XCTAssertNotNil(searchResults.elapsed.raw)
                XCTAssertNotNil(searchResults.elapsed.formatted)
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
