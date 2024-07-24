struct ClientSearchParams: Codable {
    enum Order: String, Codable {
        case asc
        case desc
    }

    struct SortByDirective: Codable {
        let property: String
        var order: Order = .asc
    }

    enum Facet: Codable {
        case string(limit: Int? = 10, order: Order? = .asc, offset: Int? = 0)
        case number(ranges: [NumberRange])
        case boolean(isTrue: Bool? = true, isFalse: Bool? = false)

        struct NumberRange: Codable {
            let from: Int
            let to: Int
        }

        enum Order: String, Codable {
            case asc, desc
        }

        enum CodingKeys: String, CodingKey {
            case limit, order, offset, ranges, `true`, `false`
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .string(limit, order, offset):
                try container.encodeIfPresent(limit, forKey: .limit)
                try container.encodeIfPresent(order, forKey: .order)
                try container.encodeIfPresent(offset, forKey: .offset)
            case let .number(ranges):
                try container.encode(ranges, forKey: .ranges)
            case let .boolean(isTrue, isFalse):
                try container.encodeIfPresent(isTrue, forKey: .true)
                try container.encodeIfPresent(isFalse, forKey: .false)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.ranges) {
                let ranges = try container.decode([NumberRange].self, forKey: .ranges)
                self = .number(ranges: ranges)
            } else if container.contains(.true) || container.contains(.false) {
                let isTrue = try container.decodeIfPresent(Bool.self, forKey: .true)
                let isFalse = try container.decodeIfPresent(Bool.self, forKey: .false)
                self = .boolean(isTrue: isTrue, isFalse: isFalse)
            } else {
                let limit = try container.decodeIfPresent(Int.self, forKey: .limit)
                let order = try container.decodeIfPresent(Order.self, forKey: .order)
                let offset = try container.decodeIfPresent(Int.self, forKey: .offset)
                self = .string(limit: limit, order: order, offset: offset)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case term, mode, properties, limit, offset, returning, facets, sortBy
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int?
        init?(intValue _: Int) {
            return nil
        }
    }

    let term: String
    var mode: SearchMode = .fulltext
    let properties: [String]?
    let limit: Int?
    let offset: Int?
    let returning: [String]?
    let facets: [String: Facet]?
    let sortBy: [SortByDirective]?

    private init(term: String, mode: SearchMode, properties: [String]?, limit: Int?, offset: Int?, returning: [String]?, facets: [String: Facet]?, sortBy: [SortByDirective]?) {
        self.term = term
        self.mode = mode
        self.properties = properties
        self.limit = limit
        self.offset = offset
        self.returning = returning
        self.facets = facets
        self.sortBy = sortBy
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(term, forKey: .term)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(properties, forKey: .properties)
        try container.encodeIfPresent(limit, forKey: .limit)
        try container.encodeIfPresent(offset, forKey: .offset)
        try container.encodeIfPresent(returning, forKey: .returning)
        try container.encodeIfPresent(sortBy, forKey: .sortBy)

        if let facets = facets {
            var facetsContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .facets)
            for (key, value) in facets {
                try facetsContainer.encode(value, forKey: DynamicCodingKeys(stringValue: key)!)
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        term = try container.decode(String.self, forKey: .term)
        mode = try container.decodeIfPresent(SearchMode.self, forKey: .mode) ?? .fulltext
        properties = try container.decodeIfPresent([String].self, forKey: .properties)
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
        offset = try container.decodeIfPresent(Int.self, forKey: .offset)
        returning = try container.decodeIfPresent([String].self, forKey: .returning)
        sortBy = try container.decodeIfPresent([SortByDirective].self, forKey: .sortBy)

        if container.contains(.facets) {
            let facetsContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .facets)
            var facetsDict = [String: Facet]()
            for key in facetsContainer.allKeys {
                facetsDict[key.stringValue] = try facetsContainer.decode(Facet.self, forKey: key)
            }
            facets = facetsDict
        } else {
            facets = nil
        }
    }

    static func builder(term: String, mode: SearchMode) -> Builder {
        return Builder(term: term, mode: mode)
    }

    class Builder {
        private var term: String
        private var mode: SearchMode
        private var properties: [String]?
        private var limit: Int
        private var offset: Int
        private var returning: [String]?
        private var facets: [String: Facet]?
        private var sortBy: [SortByDirective]?

        init(term: String, mode: SearchMode) {
            self.term = term
            self.mode = mode
            limit = 10
            offset = 0
            returning = nil
            properties = nil
        }

        func properties(_ properties: [String]) -> Self {
            self.properties = properties
            return self
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

        func facets(_ facets: [String: Facet]) -> Self {
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
                properties: properties,
                limit: limit,
                offset: offset,
                returning: returning,
                facets: facets,
                sortBy: sortBy
            )
        }
    }
}
