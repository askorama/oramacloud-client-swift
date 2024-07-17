struct ClientSearchParams: Encodable, Decodable {
  let term: String
  let mode: SearchMode
  let limit: Int?
  let offset: Int?
  let returning: [String]?
  let facets: Facets?

  private init(term: String, mode: SearchMode, limit: Int?, offset: Int?, returning: [String]?, facets: Facets?) {
    self.term = term
    self.mode = mode
    self.limit = limit
    self.offset = offset
    self.returning = returning
    self.facets = facets
  }

  static func builder(term: String, mode: SearchMode) -> Builder {
    return Builder(term: term, mode: mode)
  }

  class Builder {
    private var term: String
    private var mode: SearchMode
    private var limit: Int
    private var offset: Int
    private var returning: [String]?
    private var facets: Facets?

    fileprivate init(term: String, mode: SearchMode) {
      self.term = term
      self.mode = mode
      self.limit = 10
      self.offset = 0
      self.returning = nil
    }

    func limit(_ limit: Int) -> Self {
      self.limit = limit
      return self
    }

    func offset(_ offset: Int) -> Self {
      self.offset = offset
      return self
    }

    func returning(_ returning: [String]) -> Self {
      self.returning = returning
      return self
    }

    func facets(_ facets: Facets) -> Self {
      self.facets = facets
      return self
    }

    func build() -> ClientSearchParams {
      return ClientSearchParams(
        term: term,
        mode: mode,
        limit: limit,
        offset: offset,
        returning: returning,
        facets: facets
      )
    }
  }
}