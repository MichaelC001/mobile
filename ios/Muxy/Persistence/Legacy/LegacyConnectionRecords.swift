import Foundation

nonisolated enum LegacyConnectionRecords {
    struct Envelope<State: Decodable>: Decodable {
        let version: Int
        let state: State
    }

    struct Devices: Decodable {
        let installDeviceID: String?
        let devices: [JSONValue]
    }

    struct SSHConnections: Decodable {
        let connections: [JSONValue]
    }

    struct Device: Decodable {
        let id: UUID
        let label: String
        let host: String
        let port: Int
        let serviceName: String?
        let needsRepair: Bool?

        var isDemo: Bool {
            id == UUID(uuidString: "00000000-0000-0000-0000-0000000000DE")
        }
    }

    struct SSHConnection: Decodable {
        let id: String
        let name: String
        let host: String
        let port: Int
        let username: String
        let authType: SSHAuthMethod
    }

    struct SSHCredential: Decodable {
        let type: SSHAuthMethod
        let password: String?
        let privateKey: String?
        let passphrase: String?

        func secret(for authMethod: SSHAuthMethod) throws -> String {
            guard type == authMethod else { throw LegacyImportError.invalidRecord }
            let value = authMethod == .password ? password : privateKey
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LegacyImportError.missingCredential
            }
            return value
        }
    }

    static func state<State: Decodable>(_ type: State.Type, from data: Data) throws -> State {
        let envelope = try JSONDecoder().decode(Envelope<State>.self, from: data)
        guard envelope.version == 0 else { throw LegacyImportError.unsupportedVersion }
        return envelope.state
    }

    static func record<Record: Decodable>(_ type: Record.Type, from value: JSONValue) throws -> Record {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(value))
    }

    static func hostKey(for id: String, from data: Data) throws -> String? {
        let values = try JSONDecoder().decode([String: JSONValue].self, from: data)
        guard let value = values[id] else { return nil }
        guard case let .string(fingerprint) = value,
              fingerprint.count == 64,
              fingerprint.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw LegacyImportError.invalidRecord
        }
        return fingerprint
    }
}
