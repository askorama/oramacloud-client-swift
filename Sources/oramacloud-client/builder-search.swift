struct ClientSearchParams: Codable {
    enum Order: String, Codable {
        case asc
        case desc
    }

    struct FacetLimitOrder: Codable {
        let limit: Int?
        let order: Order?
        let offset: Int?
    }

    enum FacetsString: Codable {
        case JSObject(FacetLimitOrder)
    }

    struct FacetsNumberRange: Codable {
        let from: Int
        let to: Int
    }

    struct FacetsNumber: Codable {
        let ranges: [FacetsNumberRange]
    }

    struct FacetsBoolean: Codable {
        let isTrue: Bool?
        let isFalse: Bool?
    }

    struct Facets: Codable {
        let string: JSObject<FacetsString>?
        let number: JSObject<FacetsNumber>?
        let boolean: JSObject<FacetsBoolean>?
    }

    struct SortByDirective: Codable {
        let property: String
        var order: Order = .asc
    }

    let term: String
    var mode: SearchMode = .fulltext
    let limit: Int?
    let offset: Int?
    let returning: [String]?
    let facets: Facets?
    let sortBy: [SortByDirective]?

    private init(term: String, mode: SearchMode, limit: Int?, offset: Int?, returning: [String]?, facets: Facets?, sortBy: [SortByDirective]?) {
        self.term = term
        self.mode = mode
        self.limit = limit
        self.offset = offset
        self.returning = returning
        self.facets = facets
        self.sortBy = sortBy
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
        private var sortBy: [SortByDirective]?

        fileprivate init(term: String, mode: SearchMode) {
            self.term = term
            self.mode = mode
            limit = 10
            offset = 0
            returning = nil
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

        func sortBy(_ sortBy: [SortByDirective]) -> Self {
            self.sortBy = sortBy
            return self
        }

        func build() -> ClientSearchParams {
            return ClientSearchParams(
                term: term,
                mode: mode,
                limit: limit,
                offset: offset,
                returning: returning,
                facets: facets,
                sortBy: sortBy
            )
        }
    }
}
