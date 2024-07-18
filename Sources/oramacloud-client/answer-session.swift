import Foundation

@available(macOS 13.0, *)
struct AnswerParams<Doc: Encodable & Decodable> {
  let initialMessages: [Message]
  let inferenceType: InferenceType
  let oramaClient: OramaClient
  let userContext: UserSpecs
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

  struct Events {
    var onMessageChange: (([Message]) -> Void)?
    var onMessageLoading: ((Bool) -> Void)?
    var onAnswerAborted: ((Bool) -> Void)?
    var onSourceChange: ((SearchResults<Doc>) -> Void)?
    var onQueryTranslated: ((ClientSearchParams) -> Void)?
    var onRelatedQueries: (([String]) -> Void)?
  }
}

@available(macOS 13.0, *)
class AnswerSession<Doc: Encodable & Decodable> {

  struct SSEMessage: Codable {
    let type: String
    let message: String
  }

  private let endpointBaseURL = "https://answer.api.orama.com"
  private var abortController: Task<Void, Error>?
  private var endpoint: String
  private let userContext: AnswerParams<Doc>.UserSpecs
  private let events: AnswerParams<Doc>.Events?
  private let searchEndpoint: String
  private var messages: [AnswerParams<Doc>.Message]
  private var inferenceType: AnswerParams<Doc>.InferenceType

  init(params: AnswerParams<Doc>) {
    self.userContext = params.userContext
    self.events = params.events
    self.messages = params.initialMessages
    self.inferenceType = params.inferenceType
    self.endpoint = "\(self.endpointBaseURL)/v1/answer?api-key=\(params.oramaClient.apiKey)"
    self.searchEndpoint = params.oramaClient.endpoint
  }

  func fetchAnswer(params: AnswerParams<Doc>.AskParams) async throws -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      self.abortController = Task {
        do {
          guard let oramaAnswerEndpointURL = URL(string: self.endpoint) else {
            throw URLError(.badURL)
          }

          var request = URLRequest(url: oramaAnswerEndpointURL)
          
          request.httpMethod = "POST"
          request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
          request.httpBody = try self.buildRequestBody(params: params)

          let (responseStream, response) = try await URLSession.shared.bytes(for: request)

          guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
          }

          self.events?.onMessageLoading?(true)
          self.addNewEmptyAssistantMessage()

          guard var lastMessage = self.messages.last else {
            throw NSError(domain: "MessageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No messages available"])
          }

          var buffer = ""
          for try await byte in responseStream {
            if Task.isCancelled { break }

            buffer += String(bytes: [byte], encoding: .utf8) ?? ""

            while let endIndex = buffer.firstIndex(of: "\n") {
              let rawMessage = String(buffer[..<endIndex])
              buffer = String(buffer[buffer.index(after: endIndex)...])

              if let event = self.parseSSE(rawMessage),
                let data = event.data.data(using: .utf8),
                let parsedMessage = try? JSONDecoder().decode(AnswerSession.SSEMessage.self, from: data) {

                switch parsedMessage.type {
                case "sources":
                    if let sourcesData = parsedMessage.message.data(using: .utf8),
                      let sources = try? JSONDecoder().decode(SearchResults<Doc>.self, from: sourcesData) {
                      self.events?.onSourceChange?(sources)
                    }
                case "query-translated":
                    if let queryData = parsedMessage.message.data(using: .utf8),
                      let query = try? JSONDecoder().decode(ClientSearchParams.self, from: queryData) {
                      self.events?.onQueryTranslated?(query)
                    }
                case "related-queries":
                    if let queriesData = parsedMessage.message.data(using: .utf8),
                      let queries = try? JSONDecoder().decode([String].self, from: queriesData) {
                      self.events?.onRelatedQueries?(queries)
                    }
                case "text":
                  lastMessage.content += parsedMessage.message
                  self.events?.onMessageChange?(self.messages)
                  continuation.yield(lastMessage.content)
                default:
                    break
              }
            }
          }
        }
        continuation.finish()

        } catch {
          if error is CancellationError {
            self.events?.onAnswerAborted?(true)
          } else {
            continuation.finish(throwing: error)
          }
        }

        self.events?.onMessageLoading?(false)
      }
    }
  }

  private func addNewEmptyAssistantMessage() {
    self.messages.append(AnswerParams<Doc>.Message(role: .assistant, content: ""))
    self.events?.onMessageChange?(self.messages)
  }

  private func buildRequestBody(params: AnswerParams<Doc>.AskParams) throws -> Data {
    var components = URLComponents()
    components.queryItems = [
      URLQueryItem(name: "type", value: "documentation"), // @todo: remove hardcoded value here
      URLQueryItem(name: "messages", value: encodeJSON(self.messages)),
      URLQueryItem(name: "query", value: params.query ?? ""),
      // URLQueryItem(name: "conversationId", value: self.conversationID),
      // URLQueryItem(name: "userId", value: self.userID),
      URLQueryItem(name: "endpoint", value: self.searchEndpoint),
      URLQueryItem(name: "searchParams", value: encodeJSON(params))
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
