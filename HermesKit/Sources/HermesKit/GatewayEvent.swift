import Foundation

public struct GatewayEvent: Sendable, Equatable {
    public let type: String
    public let payload: [String: JSONValue]

    public init?(json: JSONValue) {
        guard let type = json["type"]?.stringValue, case .object(let object) = json else { return nil }
        self.type = type
        if case .object(let wrapped)? = object["payload"] {
            payload = wrapped
        } else {
            payload = object.filter { $0.key != "type" }
        }
    }

    public init?(line: String) {
        guard let json = JSONValue.parse(line) else { return nil }
        self.init(json: json)
    }

    public func payload<T: Decodable>(_ type: T.Type) -> T? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    public func text(_ key: String) -> String? {
        payload[key]?.stringValue
    }
}
