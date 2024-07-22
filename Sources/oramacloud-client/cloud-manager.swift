import Foundation

@available(macOS 12.0, *)
class CloudManager {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func index<T: Codable>(id: String) -> IndexManager<T> {
        return IndexManager(indexID: id, apiKey: apiKey)
    }

    @available(macOS 12.0, *)
    class IndexManager<T: Codable> {
        enum Endpoint: String {
            case snapshot
            case notify
            case deploy
            case hasData = "has-data"
        }

        enum OramaPayload<D: Codable>: Codable {
            case single(D)
            case array([D])
        }

        struct BooleanResponse: Codable {
            let success: Bool
        }

        struct HasDataBooleanResponse: Codable {
            let hasData: Bool
        }

        struct UpsertPayload<Docs: Codable>: Codable {
            let upsert: OramaPayload<Docs>
        }

        struct DeletePayload<Docs: Codable>: Codable {
            let remove: OramaPayload<Docs>
        }

        private let apiKey: String
        private let indexID: String
        private let APIBaseURL = "https://api.orama.com"
        private let APIVaseURLV1: String

        init(indexID: String, apiKey: String) {
            self.apiKey = apiKey
            self.indexID = indexID
            APIVaseURLV1 = "\(APIBaseURL)/api/v1"
        }

        public func snapshot<Payload: Codable>(documents: Payload) async throws -> Bool {
            let response: BooleanResponse = try await callIndexRESTAPI(endpoint: .snapshot, payload: documents)
            return response.success
        }

        public func empty() async throws -> Bool {
            let response: BooleanResponse = try await callIndexRESTAPI(endpoint: .hasData, payload: [] as [String])
            return response.success
        }

        public func insert<Payload: Codable>(documents: OramaPayload<Payload>) async throws -> Bool {
            let data = switch documents {
            case let .single(doc):
                [doc]
            case let .array(docs):
                docs
            }

            let response: BooleanResponse = try await callIndexRESTAPI(
                endpoint: .notify,
                payload: UpsertPayload(upsert: .array(data))
            )
            return response.success
        }

        public func update<Payload: Codable>(documents: OramaPayload<Payload>) async throws -> Bool {
            let data = switch documents {
            case let .single(doc):
                [doc]
            case let .array(docs):
                docs
            }

            let response: BooleanResponse = try await callIndexRESTAPI(
                endpoint: .notify,
                payload: UpsertPayload(upsert: .array(data))
            )
            return response.success
        }

        public func delete<Payload: Codable>(documents: OramaPayload<Payload>) async throws -> Bool {
            let data = switch documents {
            case let .single(doc):
                [doc]
            case let .array(docs):
                docs
            }

            let response: BooleanResponse = try await callIndexRESTAPI(
                endpoint: .notify,
                payload: DeletePayload(remove: .array(data))
            )
            return response.success
        }

        public func deploy() async throws -> Bool {
            do {
                let _: BooleanResponse = try await callIndexRESTAPI(endpoint: .deploy, payload: nil as [String]?)
                return true
            } catch {
                return false
            }
        }

        public func hasPendingOperations() async throws -> Bool {
            let response: HasDataBooleanResponse = try await callIndexRESTAPI(endpoint: .hasData, payload: nil as [String]?)
            return response.hasData
        }

        private func callIndexRESTAPI<Payload: Codable, Response: Codable>(endpoint: Endpoint, payload: Payload? = nil) async throws -> Response {
            let url = URL(string: "\(APIVaseURLV1)/webhooks/\(indexID)/\(endpoint)")!
            var request = URLRequest(url: url)

            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if payload != nil {
                request.httpBody = try JSONEncoder().encode(payload)
            }

            let (data, _) = try await URLSession.shared.data(for: request)

            return try JSONDecoder().decode(Response.self, from: data)
        }
    }
}
