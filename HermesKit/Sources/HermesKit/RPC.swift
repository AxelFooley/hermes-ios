import Foundation

public struct RPCRequest: Encodable, Sendable {
    public let jsonrpc: String
    public let id: Int
    public let method: String
    public let params: [String: JSONValue]?

    public init(id: Int, method: String, params: [String: JSONValue]? = nil) {
        jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }

    public func encoded() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self), let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }
}

public struct RPCError: Decodable, Error, Sendable, Equatable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

public struct RPCResponse: Decodable, Sendable, Equatable {
    public let id: Int
    public let result: JSONValue?
    public let error: RPCError?

    public init?(json: JSONValue) {
        guard case .object(let object) = json, let idValue = object["id"]?.doubleValue else { return nil }
        id = Int(idValue)
        result = object["result"]
        if let errorObject = object["error"]?.objectValue {
            error = RPCError(
                code: Int(errorObject["code"]?.doubleValue ?? -1),
                message: errorObject["message"]?.stringValue ?? "unknown error"
            )
        } else {
            error = nil
        }
    }

    public init?(line: String) {
        guard let json = JSONValue.parse(line) else { return nil }
        self.init(json: json)
    }
}
