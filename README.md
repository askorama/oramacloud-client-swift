# Orama Cloud Swift Client

[![GitHub CI](https://github.com/askorama/oramacloud-client-swift/actions/workflows/swift.yml/badge.svg)](https://github.com/askorama/oramacloud-client-swift/actions/workflows/swift.yml)

## Installing via CocoaPods

To install the Orama Cloud client in your Swift project, you'll need to install [CocoaPods](https://cocoapods.org/)

```sh
$ gem install cocoapods
```

Then specify the Orama Client dependency in your `PodFile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '10.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'OramaCloudClient', '~> 0.0.5'
end
```

Then, run `pod install` to install the Pod:

```sh
pod install
```

## Installing via the Swift Package Manager

Add the Orama Cloud repo URL to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/askorama/oramacloud-client-swift.git", from: "0.0.4")
]
```

## Usage

Performing full-text, vector, or hybrid search:

```swift
import OramaClient

struct MyDoc: Codable {
  let title: String
  let description: String
}

let clientParams = OramaClientParams(endpoint: "<ORAMA CLOUD URL>", apiKey: "<ORAMA CLOUD API KEY>")
let orama = OramaClient(params: clientParams)

let searchParams = ClientSearchParams.builder(term: "What is Orama?", mode: .fulltext) // Mode can be .vector or .hybrid too
  .limit(10) // optional
  .offset(0) // optional
  .returning(["title", "description"]) // optional
  .build()

let searchResults: SearchResults<MyDoc> = try await orama.search(query: searchParams)

print("\(searchResults.count) total results.")
```

Performing an answer session:

```swift
import OramaClient

struct MyDoc: Codable {
  let title: String
  let description: String
}

let clientParams = OramaClientParams(endpoint: "<ORAMA CLOUD URL>", apiKey: "<ORAMA CLOUD API KEY>")
let orama = OramaClient(params: clientParams)
let answerSessionParams = AnswerParams<E2EDoc>(
    initialMessages: [],
    inferenceType: .documentation,
    oramaClient: orama,
    userContext: nil,
    events: nil
  )

let answerSession = AnswerSession(params: answerSessionParams)
  .on(event: .stateChange) { print($0) }
  .on(event: .relatedQueries) { print($0) }

let askParams = AnswerParams<E2EDoc>.AskParams(
    query: "What's the best movie to watch with the family?",
    userData: nil,
    related: nil
  )
let answer = try await answerSession.ask(params: askParams)
```

## License

[Apache 2.0](/LICENSE.md)