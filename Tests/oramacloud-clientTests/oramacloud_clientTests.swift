@testable import oramacloud_client
import XCTest

struct E2ETest1Document: Codable {
    let breed: String
}

let e2eEndpoint = "https://cloud.orama.run/v1/indexes/e2e-index-client-rv4bdd"
let e2eApiKey = "eaXWAKLxn05lefXAfB3wAhuTq3VaXGqx"

let privateE2eAPIKey = ProcessInfo.processInfo.environment["ORAMA_PRIVATE_API_KEY"] ?? ""
let privateE2eIndexID = ProcessInfo.processInfo.environment["ORAMA_INDEX_ID"] ?? ""

@available(macOS 12.0, *)
final class oramacloud_clientTests: XCTestCase {
    struct E2EDoc: Codable {
        let breed: String
    }

    var oramaClient: OramaClient!
    var answerSession: AnswerSession<E2EDoc>!

    override func setUp() {
        super.setUp()
        let clientParams = OramaClientParams(endpoint: e2eEndpoint, apiKey: e2eApiKey)
        oramaClient = OramaClient(params: clientParams)

        let answerParams = AnswerParams<E2EDoc>(
            initialMessages: [],
            inferenceType: .documentation,
            oramaClient: oramaClient,
            userContext: nil,
            events: nil
        )
        answerSession = AnswerSession(params: answerParams)
    }

    func testE2ESearch() async throws {
        let expectation = XCTestExpectation(description: "Async search completes")

        Task {
            do {
                let params = ClientSearchParams.builder(term: "German", mode: .fulltext)
                    .limit(10)
                    .offset(0)
                    .build()
                let searchResults: SearchResults<E2ETest1Document> = try await oramaClient.search(query: params)

                XCTAssertGreaterThan(searchResults.count, 0)
                XCTAssertNotNil(searchResults.elapsed.raw)
                XCTAssertNotNil(searchResults.elapsed.formatted)
                XCTAssertGreaterThan(searchResults.hits.count, 0)
                expectation.fulfill()
            } catch {
                debugPrint("Search failed with error: \(error)")
                fflush(stdout)
                XCTFail("Search failed with error: \(error)")
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    func testE2EAnswerSession() async throws {
        let answerSessionParams = AnswerParams<E2EDoc>(
            initialMessages: [],
            inferenceType: .documentation,
            oramaClient: oramaClient,
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

    func testOnMessageLoading() async throws {
        let expectation = XCTestExpectation(description: "Message loading event called")
        var events: [Bool] = []

        _ = answerSession.on(event: .messageLoading) {
            events.append($0 as! Bool)
            if events.count == 2 { // Expecting two events: true and false
                expectation.fulfill()
            }
        }

        let _ = try await answerSession.ask(params: AnswerParams.AskParams(query: "german", userData: nil, related: nil))

        await fulfillment(of: [expectation], timeout: 10.0)

        XCTAssertEqual(events, [true, false], "Expected two message loading events: true followed by false")
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

    func testE2ERegenerateLastAnswer() async throws {
        let expectation = XCTestExpectation(description: "Can correctly regenerate the last answer")
        var state: [AnswerParams<E2EDoc>.Interaction<E2EDoc>] = []

        do {
            _ = answerSession.on(event: .stateChange) {
                state = $0 as! [AnswerParams<E2EDoc>.Interaction<E2EDoc>]
            }

            let _ = try await answerSession.ask(params: AnswerParams.AskParams(query: "german", userData: nil, related: nil))
            let _ = try await answerSession.ask(params: AnswerParams.AskParams(query: "labrador", userData: nil, related: nil))
            let _ = try await answerSession.regenerateLast(stream: false)

            expectation.fulfill()
            XCTAssertEqual(state.count, 2, "Should contain 2 interactions")
            XCTAssertEqual(state.last!.query, "labrador", "Second query should be 'labrador'")

            await fulfillment(of: [expectation], timeout: 120.0)

        } catch {
            XCTFail("Test failed with error: \(error)")
            expectation.fulfill()
        }
    }

    func testE2EIndexManager() throws {
        struct DocumentStruct: Codable {
            let breed: String
        }

        func readLocalJSONFile(filename: String) -> Data? {
            do {
                if let bundlePath = Bundle(for: type(of: self)).path(forResource: filename, ofType: "json"),
                   let jsonData = try String(contentsOfFile: bundlePath).data(using: .utf8)
                {
                    return jsonData
                }
            } catch {
                print(error)
            }

            return nil
        }

        func parseLocalJSON(jsonData: Data) -> [DocumentStruct]? {
            do {
                let decodedData = try JSONDecoder().decode([DocumentStruct].self, from: jsonData)
                return decodedData
            } catch {
                print("decode error")
                return nil
            }
        }

        if !privateE2eAPIKey.isEmpty && !privateE2eIndexID.isEmpty {
            let cloudManager = CloudManager(apiKey: privateE2eAPIKey)
            let index: CloudManager.IndexManager<DocumentStruct> = cloudManager.index(id: privateE2eIndexID)

            if let localMockFile = readLocalJSONFile(filename: "./mocks/dataset.json"),
               let documents = parseLocalJSON(jsonData: localMockFile)
            {
                Task {
                    do {
                        let wasEmptied = try await index.empty()
                        let wasSnapshotUploaded = try await index.snapshot(documents: documents)
                        let wasDeploymentTriggered = try await index.deploy()

                        XCTAssertTrue(wasEmptied)
                        XCTAssertTrue(wasSnapshotUploaded)
                        XCTAssertTrue(wasDeploymentTriggered)
                    } catch {
                        XCTFail("Snapshot failed with error: \(error)")
                    }
                }
            }

        } else {
            debugPrint("Skipping testE2EIndexManager: ORAMA_PRIVATE_API_KEY and ORAMA_INDEX_ID not set")
        }
    }
}

@available(macOS 12.0, *)
extension oramacloud_clientTests {
    static var allTests = [
        ("testE2ESearch", testE2ESearch),
        ("testE2EAnswerSession", testE2EAnswerSession),
        ("testOnMessageLoading", testOnMessageLoading),
        ("testAsyncE2EAnswerSession", testAsyncE2EAnswerSession),
        ("testE2ERegenerateLastAnswer", testE2ERegenerateLastAnswer),
        ("testE2EIndexManager", testE2EIndexManager)
    ]
}
