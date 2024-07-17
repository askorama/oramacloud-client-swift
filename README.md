# Orama Cloud Swift Client

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
    pod 'OramaCloud', '~> 0.0.1'
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
    .package(url: "https://github.com/askorama/oramacloud-client-swift.git", from: "0.0.1")
]
```

## Usage

```swift
import OramaClient

struct MyDoc: Encodable & Decodable {
  let title: String
  let description: String
}

func performSearch() async throws -> SearchResults<MyDoc> {
 let clientParams = OramaClientParams(endpoint: "<ORAMA CLOUD URL>", apiKey: "<ORAMA CLOUD API KEY>")
  let orama = OramaClient(params: clientParams)

  let searchParams = ClientSearchParams(
    term: "My search query",
    mode: SearchMode.fulltext,
    limit: 10,
    offset: nil,
    returning: nil,
    facets: nil
  )

  let searchResults: SearchResults<E2ETest1Document> = try await orama.search(query: searchParams)

  return searchResults
}

```