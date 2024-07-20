import Foundation

@available(macOS 13.0, *)
struct AnswerParams<Doc: Encodable & Decodable> {
    let initialMessages: [Message]
    let inferenceType: InferenceType
    let oramaClient: OramaClient
    let userContext: UserSpecs?
    let events: Events?

    enum InferenceType: Encodable, Decodable {
        case documentation
    }

    enum RelatedFormat: Encodable, Decodable {
        case question
        case query
    }

    enum Role: Encodable, Decodable {
        case user
        case assistant
    }

    struct Message: Encodable, Decodable {
        let role: Role
        var content: String
    }

    enum UserSpecs: Encodable, Decodable {
        case string
        case JSObject
    }

    struct Related: Encodable, Decodable {
        var howMany: Int? = 3
        var format: RelatedFormat? = .question
    }

    struct AskParams: Encodable, Decodable {
        let query: String
        let userData: UserSpecs?
        let related: Related?
    }

    struct Interaction<T: Decodable & Encodable> {
        var interactionId: String
        var query: String
        var response: String
        var relatedQueries: [String]?
        var sources: SearchResults<T>?
        var translatedQuery: ClientSearchParams?
        var loading: Bool
        var aborted: Bool = false
    }

    struct Events {
        typealias Callback = (Any) -> Void

        var onMessageChange: (([Message]) -> Void)?
        var onMessageLoading: ((Bool) -> Void)?
        var onAnswerAborted: ((Bool) -> Void)?
        var onSourceChange: ((SearchResults<Doc>) -> Void)?
        var onQueryTranslated: ((ClientSearchParams) -> Void)?
        var onRelatedQueries: (([String]) -> Void)?
        var onNewInteractionStarted: ((String) -> Void)?
        var onStateChange: (([Interaction<Doc>]) -> Void)?
    }

    enum Event: String {
        case messageChange
        case messageLoading
        case answerAborted
        case sourceChange
        case queryTranslated
        case relatedQueries
        case newInteractionStarted
        case stateChange
    }
}

@available(macOS 13.0, *)
class AnswerSession<Doc: Encodable & Decodable> {
    struct SSEMessage: Codable {
        let type: String
        let message: String
    }

    private let eventEmitter = EventEmitter()
    private let endpointBaseURL = "https://answer.api.orama.com"
    private var abortController: Task<Void, Error>?
    private var endpoint: String
    private let userContext: AnswerParams<Doc>.UserSpecs
    private var events: AnswerParams<Doc>.Events?
    private let searchEndpoint: String
    private let conversationID = Cuid.generateId()
    private let userID = User().getUserID()
    private var messages: [AnswerParams<Doc>.Message]
    private var inferenceType: AnswerParams<Doc>.InferenceType
    private var state: [AnswerParams<Doc>.Interaction<Doc>] = []

    init(params: AnswerParams<Doc>) {
        userContext = params.userContext ?? .string
        events = params.events
        messages = params.initialMessages
        inferenceType = params.inferenceType
        endpoint = "\(endpointBaseURL)/v1/answer?api-key=\(params.oramaClient.apiKey)"
        searchEndpoint = params.oramaClient.endpoint
    }

    public func on(event: AnswerParams<Doc>.Event, callback: @escaping AnswerParams<Doc>.Events.Callback) -> AnswerSession<Doc> {
        eventEmitter.on(event.rawValue) { data in
            callback(data)
        }
        return self
    }

    public func askStream(params: AnswerParams<Doc>.AskParams) async throws -> String {
        return try await ask(params: params)
    }

    public func ask(params: AnswerParams<Doc>.AskParams) async throws -> String {
        let stream = try await fetchAnswer(params: params)
        var response = ""
        for try await message in stream {
            response += message
        }
        return response
    }

    private func fetchAnswer(params: AnswerParams<Doc>.AskParams) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let interactionId = Cuid.generateId()
            self.abortController = Task {
                do {
                    self.state.append(AnswerParams<Doc>.Interaction(
                        interactionId: interactionId,
                        query: params.query,
                        response: "",
                        relatedQueries: nil,
                        sources: nil,
                        translatedQuery: nil,
                        loading: true
                    ))

                    let currentInteractionIndex = self.state.firstIndex(where: { $0.interactionId == interactionId })!
                    self.events?.onNewInteractionStarted?(interactionId)
                    self.events?.onStateChange?(self.state)

                    guard let url = URL(string: self.endpoint) else {
                        throw URLError(.badURL)
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try self.buildRequestBody(params: params, interactionId: interactionId)

                    let (responseStream, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }

                    self.eventEmitter.emit("messageLoading", data: true)
                    self.addNewEmptyAssistantMessage()

                    var buffer = ""
                    for try await byte in responseStream {
                        if Task.isCancelled { break }

                        buffer += String(bytes: [byte], encoding: .utf8) ?? ""
                        while let endIndex = buffer.firstIndex(of: "\n") {
                            let rawMessage = String(buffer[..<endIndex])
                            buffer = String(buffer[buffer.index(after: endIndex)...])

                            if let event = self.parseSSE(rawMessage),
                               let data = event.data.data(using: .utf8),
                               let parsedMessage = try? JSONDecoder().decode(AnswerSession.SSEMessage.self, from: data)
                            {
                                switch parsedMessage.type {
                                case "sources":
                                    if let sourcesData = parsedMessage.message.data(using: .utf8),
                                       let sources = try? JSONDecoder().decode(SearchResults<Doc>.self, from: sourcesData)
                                    {
                                        self.state[currentInteractionIndex].sources = sources
                                        self.eventEmitter.emit("onSourceChange", data: sources)
                                        self.eventEmitter.emit("onStateChange", data: self.state)
                                    }
                                case "query-translated":
                                    if let queryData = parsedMessage.message.data(using: .utf8),
                                       let query = try? JSONDecoder().decode(ClientSearchParams.self, from: queryData)
                                    {
                                        self.state[currentInteractionIndex].translatedQuery = query
                                        self.eventEmitter.emit("queryTranslated", data: query)
                                        self.eventEmitter.emit("stateChange", data: self.state)
                                    }
                                case "related-queries":
                                    if let queriesData = parsedMessage.message.data(using: .utf8),
                                       let queries = try? JSONDecoder().decode([String].self, from: queriesData)
                                    {
                                        self.state[currentInteractionIndex].relatedQueries = queries
                                        self.eventEmitter.emit("relatedQueries", data: queries)
                                        self.eventEmitter.emit("stateChange", data: self.state)
                                    }
                                case "text":
                                    self.state[currentInteractionIndex].response += parsedMessage.message
                                    self.eventEmitter.emit("messageChange", data: self.messages)
                                    self.eventEmitter.emit("stateChange", data: self.state)

                                    continuation.yield(self.state[currentInteractionIndex].response)
                                default:
                                    break
                                }
                            }
                        }
                    }
                    continuation.finish()

                } catch {
                    if error is CancellationError {
                        let index = self.state.firstIndex(where: { $0.interactionId == interactionId })!
                        self.state[index].loading = false
                        self.state[index].aborted = true

                        self.eventEmitter.emit("messageLoading", data: false)
                        self.eventEmitter.emit("onAnswerAborted", data: true)
                        self.eventEmitter.emit("stateChange", data: self.state)

                        continuation.finish()
                    } else {
                        continuation.finish(throwing: error)
                    }
                }

                let index = self.state.firstIndex(where: { $0.interactionId == interactionId })!
                self.state[index].loading = false
                self.eventEmitter.emit("messageLoading", data: false)
                self.eventEmitter.emit("stateChange", data: self.state)
                continuation.finish()
            }
        }
    }

    private func addNewEmptyAssistantMessage() {
        messages.append(AnswerParams<Doc>.Message(role: .assistant, content: ""))
        events?.onMessageChange?(messages)
    }

    private func buildRequestBody(params: AnswerParams<Doc>.AskParams, interactionId: String) throws -> Data {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "type", value: "documentation"), // @todo: remove hardcoded value here
            URLQueryItem(name: "messages", value: encodeJSON(messages)),
            URLQueryItem(name: "query", value: params.query),
            URLQueryItem(name: "conversationId", value: conversationID),
            URLQueryItem(name: "userId", value: userID),
            URLQueryItem(name: "endpoint", value: searchEndpoint),
            URLQueryItem(name: "searchParams", value: encodeJSON(params)),
            URLQueryItem(name: "interactionId", value: interactionId),
        ]

        if params.userData != nil {
            components.queryItems?.append(URLQueryItem(name: "userData", value: encodeJSON(params.userData)))
        }

        if params.related != nil {
            components.queryItems?.append(URLQueryItem(name: "related", value: encodeJSON(params.related)))
        }

        guard let encodedQuery = components.percentEncodedQuery?.data(using: .utf8) else {
            throw URLError(.badURL)
        }

        return encodedQuery
    }

    private func parseSSE(_ rawMessage: String) -> (event: String, data: String)? {
        let lines = rawMessage.split(separator: "\n")
        var event = ""
        var data = ""

        for line in lines {
            if line.starts(with: "event:") {
                event = String(line.dropFirst(6).trimmingCharacters(in: .whitespaces))
            } else if line.starts(with: "data:") {
                data = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
            }
        }

        return (event, data)
    }

    private func encodeJSON<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(value)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to encode JSON: \(error)")
            return nil
        }
    }
}
