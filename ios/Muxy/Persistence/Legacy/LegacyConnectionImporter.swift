import Foundation
import OSLog

@MainActor
struct LegacyConnectionImporter {
    private let storage: LegacyStorage
    private let connections: ConnectionStore
    private let keychain: KeychainStore
    private let defaults: UserDefaults
    private let validator = ConnectionInputValidator()

    private enum Key {
        static let completed = "muxy.legacyConnections.completed"
        static let importedIDs = "muxy.legacyConnections.importedIDs"
    }

    init(storage: LegacyStorage, connections: ConnectionStore, keychain: KeychainStore, defaults: UserDefaults = .standard) {
        self.storage = storage
        self.connections = connections
        self.keychain = keychain
        self.defaults = defaults
    }

    func run() {
        guard !defaults.bool(forKey: Key.completed) else { return }
        let devicesImported = importing("devices") { try importDevices() }
        let sshImported = importing("SSH connections") { try importSSHConnections() }
        guard devicesImported && sshImported else { return }
        defaults.set(true, forKey: Key.completed)
        Log.persistence.info("Legacy connection import completed")
    }

    private func importDevices() throws -> Bool {
        guard let data = try storage.value(for: "muxy.devices.v1") else { return true }
        let state = try LegacyConnectionRecords.state(LegacyConnectionRecords.Devices.self, from: data)
        var completed = true
        for value in state.devices {
            let imported = importing("device") {
                try importDevice(value, installDeviceID: state.installDeviceID)
                return true
            }
            completed = imported && completed
        }
        return completed
    }

    private func importDevice(_ value: JSONValue, installDeviceID: String?) throws {
        let device = try LegacyConnectionRecords.record(LegacyConnectionRecords.Device.self, from: value)
        guard !device.isDemo, shouldImport(device.id) else { return }
        guard !device.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...65535).contains(device.port),
              Endpoint(host: device.host, port: device.port).webSocketURL != nil else {
            throw LegacyImportError.invalidRecord
        }
        var connection = Connection(
            id: device.id,
            name: device.label,
            host: device.host,
            port: device.port,
            serviceName: device.serviceName
        )
        if device.needsRepair != true {
            guard let installDeviceID, UUID(uuidString: installDeviceID) != nil,
                  let token = try storage.secret(for: "muxy.installToken"),
                  !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LegacyImportError.missingCredential
            }
            connection.authenticationDeviceID = installDeviceID
            connection.pairingState = .paired
            try keychain.setToken(token, for: connection.id)
        }
        try save(connection)
    }

    private func importSSHConnections() throws -> Bool {
        guard let data = try storage.value(for: "muxy.ssh.connections.v1") else { return true }
        let state = try LegacyConnectionRecords.state(LegacyConnectionRecords.SSHConnections.self, from: data)
        var completed = true
        for value in state.connections {
            let imported = importing("SSH connection") {
                try importSSHConnection(value)
                return true
            }
            completed = imported && completed
        }
        return completed
    }

    private func importSSHConnection(_ value: JSONValue) throws {
        let record = try LegacyConnectionRecords.record(LegacyConnectionRecords.SSHConnection.self, from: value)
        guard let id = UUID(uuidString: record.id) else { throw LegacyImportError.invalidRecord }
        guard shouldImport(id) else { return }
        guard let encoded = try storage.secret(for: "muxy.ssh.credentials.\(record.id)") else {
            throw LegacyImportError.missingCredential
        }
        let credential = try JSONDecoder().decode(LegacyConnectionRecords.SSHCredential.self, from: Data(encoded.utf8))
        let input = try validator.validateSSH(
            name: record.name,
            host: record.host,
            portText: String(record.port),
            username: record.username,
            authMethod: record.authType,
            secret: credential.secret(for: record.authType),
            passphrase: credential.passphrase ?? ""
        ).get()
        let connection = Connection(
            id: id,
            name: input.name,
            host: input.host,
            port: input.port,
            kind: .ssh,
            sshConfig: SSHConfig(username: input.username, authMethod: input.authMethod)
        )
        if let data = try storage.value(for: "muxy.ssh.knownHosts.v1"),
           let fingerprint = try LegacyConnectionRecords.hostKey(for: record.id, from: data) {
            try keychain.setSecret(fingerprint, .sshHostKey, for: id)
        }
        let secretKind: KeychainSecret = input.authMethod == .password ? .sshPassword : .sshPrivateKey
        try keychain.setSecret(input.secret, secretKind, for: id)
        if let passphrase = credential.passphrase, record.authType == .privateKey {
            try keychain.setSecret(passphrase, .sshPassphrase, for: id)
        }
        try save(connection)
    }

    private func shouldImport(_ id: UUID) -> Bool {
        let importedIDs = defaults.stringArray(forKey: Key.importedIDs) ?? []
        guard !importedIDs.contains(id.uuidString) else { return false }
        guard connections.load().contains(where: { $0.id == id }) else { return true }
        markImported(id)
        return false
    }

    private func save(_ connection: Connection) throws {
        connections.upsert(connection)
        guard connections.load().contains(connection) else { throw LegacyImportError.saveFailed }
        markImported(connection.id)
        Log.persistence.info("Imported a legacy connection")
    }

    private func markImported(_ id: UUID) {
        var importedIDs = defaults.stringArray(forKey: Key.importedIDs) ?? []
        guard !importedIDs.contains(id.uuidString) else { return }
        importedIDs.append(id.uuidString)
        defaults.set(importedIDs, forKey: Key.importedIDs)
    }

    private func importing(_ category: String, operation: () throws -> Bool) -> Bool {
        do {
            return try operation()
        } catch {
            let failure = error as NSError
            Log.persistence.error("Legacy \(category, privacy: .public) import failed: \(failure.domain, privacy: .public) (\(failure.code))")
            return false
        }
    }
}
