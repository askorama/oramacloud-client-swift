@testable import oramacloud_client
import XCTest

struct E2ETest1Document: Encodable & Decodable {
    let breed: String
}

let e2eEndpoint = "https://cloud.orama.run/v1/indexes/e2e-index-client-rv4bdd"
let e2eApiKey = "eaXWAKLxn05lefXAfB3wAhuTq3VaXGqx"

func testE2EAnswerSession() async throws {
    struct E2EDoc: Codable {
        let breed: String
    }

    let clientParams = OramaClientParams(endpoint: e2eEndpoint, apiKey: e2eApiKey)
    let orama = OramaClient(params: clientParams)
    let answerSessionParams = AnswerParams<E2EDoc>(
        initialMessages: [],
        inferenceType: .documentation,
        oramaClient: orama,
        userContext: nil,
        events: nil
    )

    let answerSession = AnswerSession(params: answerSessionParams)

    let askParams = AnswerParams<E2EDoc>.AskParams(query: "german", userData: nil, related: nil)

    do {
        let response = try await answerSession.ask(params: askParams)
        XCTAssertFalse(response.isEmpty, "Response should not be empty")
    } catch {
        XCTFail("AnswerSession failed with error: \(error)")
    }
}

@available(macOS 12.0, *)
final class oramacloud_clientTests: XCTestCase {
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
                fflush(stdout)
                XCTFail("Search failed with error: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testAsyncE2EAnswerSession() throws {
        let expectation = XCTestExpectation(description: "Async answer session completes")

        Task {
            do {
                try await testE2EAnswerSession()
                expectation.fulfill()
            } catch {
                XCTFail("Test failed with error: \(error)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 60.0)
    }
}

@available(macOS 12.0, *)
extension oramacloud_clientTests {
    static var allTests = [
        ("testE2ESearch", testE2ESearch),
    ]
}
