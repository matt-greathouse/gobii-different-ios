import Foundation

// Enum representing the output schema recursively
indirect enum OutputSchema: Codable {
    case number
    case string
    case boolean
    case object(properties: [String: OutputSchema])
    case array(items: OutputSchema)

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case items
    }

    enum OutputType: String, Codable {
        case number
        case string
        case boolean
        case object
        case array
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(OutputType.self, forKey: .type)
        switch type {
        case .number:
            self = .number
        case .string:
            self = .string
        case .boolean:
            self = .boolean
        case .object:
            let properties = try container.decode([String: OutputSchema].self, forKey: .properties)
            self = .object(properties: properties)
        case .array:
            let items = try container.decode(OutputSchema.self, forKey: .items)
            self = .array(items: items)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .number:
            try container.encode(OutputType.number, forKey: .type)
        case .string:
            try container.encode(OutputType.string, forKey: .type)
        case .boolean:
            try container.encode(OutputType.boolean, forKey: .type)
        case .object(let properties):
            try container.encode(OutputType.object, forKey: .type)
            try container.encode(properties, forKey: .properties)
        case .array(let items):
            try container.encode(OutputType.array, forKey: .type)
            try container.encode(items, forKey: .items)
        }
    }

    // Sample default value for UI development
    static var sample: OutputSchema {
        return .object(properties: [
            "name": .string,
            "value": .number
        ])
    }
}

// Struct representing a task
struct AppTask: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var prompt: String
    var outputSchema: OutputSchema

    init(id: UUID = UUID(), name: String = "", prompt: String = "", outputSchema: OutputSchema = OutputSchema.sample) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.outputSchema = outputSchema
    }
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppTask, rhs: AppTask) -> Bool {
        return lhs.id == rhs.id
    }
}
