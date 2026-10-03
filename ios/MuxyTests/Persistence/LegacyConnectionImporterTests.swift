import Foundation
import Testing
@testable import Muxy

@MainActor
struct LegacyConnectionImporterTests {
    @Test func importsDevicesWithTheOriginalSharedIdentityAndToken() throws {
        let context = LegacyImportContext()
        try context.setDevices([context.device(), context.device(id: LegacyImportContext.secondID)])
        context.storage.secrets["muxy.installToken"] = "install-token"
        let sourceValues = context.storage.values
        let sourceSecrets = context.storage.secrets

        context.run()

        let connections = context.connections.load()
        #expect(connections.map(\.id) == [LegacyImportContext.firstID, LegacyImportContext.secondID])
        for connection in connections {
            #expect(connection.authenticationDeviceID == LegacyImportContext.installID)
            #expect(connection.authenticationDeviceID != connection.id.uuidString)
            #expect(connection.name == "Studio")
            #expect(connection.host == "studio.local")
            #expect(connection.port == 4865)
            #expect(connection.serviceName == "Studio")
            #expect(connection.kind == .device)
            #expect(connection.pairingState == .paired)
            #expect(try context.keychain.token(for: connection.id) == "install-token")
        }
        #expect(UserDefaultsConnectionStore(defaults: context.defaults).load() == connections)
        #expect(context.isComplete)
        #expect(context.storage.values == sourceValues)
        #expect(context.storage.secrets == sourceSecrets)
        let stored = try #require(context.defaults.data(forKey: "muxy.devices"))
        #expect(!String(decoding: stored, as: UTF8.self).contains("install-token"))
    }

    @Test func preservesBracketedIPv6Addresses() throws {
        let context = LegacyImportContext()
        var device = context.device()
        device["host"] = "[fd12:3456::10]"
        try context.setDevices([device])
        context.storage.secrets["muxy.installToken"] = "install-token"

        context.run()

        let connection = try #require(context.connections.load().first)
        #expect(connection.host == "[fd12:3456::10]")
        #expect(connection.endpoint.webSocketURL?.absoluteString == "ws://[fd12:3456::10]:4865")
        #expect(context.isComplete)
    }

    @Test func importsSSHCredentialsAndTrustedHostKeys() throws {
        let context = LegacyImportContext()
        let passwordID = LegacyImportContext.firstID
        let privateKeyID = LegacyImportContext.secondID
        try context.setSSHConnections([
            context.sshConnection(id: passwordID, authType: "password"),
            context.sshConnection(id: privateKeyID, authType: "privateKey"),
        ])
        let privateKey = "-----BEGIN OPENSSH PRIVATE KEY-----\nfixture-key\n-----END OPENSSH PRIVATE KEY-----\n"
        try context.setSSHCredential(["type": "password", "password": " password "], id: passwordID)
        try context.setSSHCredential(["type": "privateKey", "privateKey": privateKey, "passphrase": " passphrase "], id: privateKeyID)
        let passwordFingerprint = String(repeating: "ab", count: 32)
        let privateKeyFingerprint = String(repeating: "cd", count: 32)
        context.storage.values["muxy.ssh.knownHosts.v1"] = try JSONSerialization.data(withJSONObject: [
            passwordID.uuidString.lowercased(): passwordFingerprint,
            privateKeyID.uuidString.lowercased(): privateKeyFingerprint,
        ])

        context.run()

        let connections = context.connections.load()
        #expect(connections.map(\.id) == [passwordID, privateKeyID])
        #expect(connections.allSatisfy { $0.kind == .ssh && $0.host == "ssh.local" && $0.port == 22 })
        #expect(connections.first?.sshConfig == SSHConfig(username: "developer", authMethod: .password))
        #expect(connections.last?.sshConfig == SSHConfig(username: "developer", authMethod: .privateKey))
        #expect(try context.keychain.secret(.sshPassword, for: passwordID) == " password ")
        #expect(try context.keychain.secret(.sshPrivateKey, for: privateKeyID) == privateKey)
        #expect(try context.keychain.secret(.sshPassphrase, for: privateKeyID) == " passphrase ")
        #expect(try context.keychain.secret(.sshHostKey, for: passwordID) == passwordFingerprint)
        #expect(try context.keychain.secret(.sshHostKey, for: privateKeyID) == privateKeyFingerprint)
        #expect(context.isComplete)
    }

    @Test func completedImportDoesNotReadLegacyStorageAgain() throws {
        let context = LegacyImportContext()
        try context.setDevices([context.device(), context.device()])
        context.storage.secrets["muxy.installToken"] = "install-token"
        context.run()
        #expect(context.connections.load().count == 1)
        #expect(context.isComplete)
        let reads = context.storage.valueReads
        context.connections.delete(id: LegacyImportContext.firstID)
        try context.keychain.deleteSecrets(for: LegacyImportContext.firstID)

        context.run()

        #expect(context.connections.load().isEmpty)
        #expect(try context.keychain.token(for: LegacyImportContext.firstID) == nil)
        #expect(context.storage.valueReads == reads)
    }

    @Test func neverOverwritesAnExistingNativeConnectionOrCredential() throws {
        let context = LegacyImportContext()
        let native = Connection(id: LegacyImportContext.firstID, name: "Native", host: "native.local", port: 1234)
        context.connections.upsert(native)
        try context.keychain.setToken("native-token", for: native.id)
        try context.setDevices([context.device()])
        context.storage.unreadableSecrets.insert("muxy.installToken")

        context.run()

        #expect(context.connections.load() == [native])
        #expect(try context.keychain.token(for: native.id) == "native-token")
        #expect(context.isComplete)
    }

    @Test func skipsDemoAndRetainsRevokedConnectionsWithoutCredentials() throws {
        let context = LegacyImportContext()
        var revoked = context.device()
        revoked["needsRepair"] = true
        let demo = context.device(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000DE")!)
        try context.setDevices([demo, revoked], installID: nil)

        context.run()

        let connection = try #require(context.connections.load().first)
        #expect(context.connections.load().count == 1)
        #expect(connection.id == LegacyImportContext.firstID)
        #expect(connection.pairingState == .notPaired)
        #expect(connection.authenticationDeviceID == nil)
        #expect(try context.keychain.token(for: connection.id) == nil)
        #expect(context.isComplete)
    }

    @Test func malformedRecordDoesNotPreventOtherDevicesFromImporting() throws {
        let context = LegacyImportContext()
        try context.setDevices([context.device(), ["id": "invalid"], context.device(id: LegacyImportContext.secondID)])
        context.storage.secrets["muxy.installToken"] = "install-token"

        context.run()

        #expect(context.connections.load().map(\.id) == [LegacyImportContext.firstID, LegacyImportContext.secondID])
        #expect(!context.isComplete)
    }

    @Test func unavailableKeychainIsRetriedOnTheNextRun() throws {
        let context = LegacyImportContext()
        try context.setDevices([context.device()])
        context.storage.secrets["muxy.installToken"] = "install-token"
        context.storage.unreadableSecrets.insert("muxy.installToken")

        context.run()

        #expect(context.connections.load().isEmpty)
        #expect(!context.isComplete)
        context.storage.unreadableSecrets.removeAll()
        context.run()
        #expect(context.connections.load().count == 1)
        #expect(try context.keychain.token(for: LegacyImportContext.firstID) == "install-token")
        #expect(context.isComplete)
    }

    @Test func missingTokenDoesNotCompleteMigration() throws {
        let context = LegacyImportContext()
        try context.setDevices([context.device()])

        context.run()

        #expect(context.connections.load().isEmpty)
        #expect(!context.isComplete)
        context.storage.secrets["muxy.installToken"] = "recovered-token"
        context.run()
        #expect(try context.keychain.token(for: LegacyImportContext.firstID) == "recovered-token")
        #expect(context.isComplete)
    }

    @Test(arguments: [nil, "invalid"] as [String?])
    func missingOrInvalidInstallIdentityDoesNotCompleteMigration(installID: String?) throws {
        let context = LegacyImportContext()
        try context.setDevices([context.device()], installID: installID)
        context.storage.secrets["muxy.installToken"] = "install-token"

        context.run()

        #expect(context.connections.load().isEmpty)
        #expect(try context.keychain.token(for: LegacyImportContext.firstID) == nil)
        #expect(!context.isComplete)
    }

    @Test func failedRecordRetriesWithoutRestoringDeletedSuccessfulImports() throws {
        let context = LegacyImportContext()
        let nativeID = UUID()
        context.connections.upsert(Connection(id: nativeID, name: "Native", host: "native.local", port: 4865))
        try context.setDevices([context.device(), context.device(id: LegacyImportContext.secondID), context.device(id: nativeID)])
        context.storage.secrets["muxy.installToken"] = "install-token"
        context.keychain.failingIDs.insert(LegacyImportContext.secondID)

        context.run()

        #expect(context.connections.load().map(\.id) == [nativeID, LegacyImportContext.firstID])
        #expect(!context.isComplete)
        context.connections.delete(id: LegacyImportContext.firstID)
        context.connections.delete(id: nativeID)
        try context.keychain.deleteSecrets(for: LegacyImportContext.firstID)
        context.keychain.failingIDs.removeAll()
        context.run()
        #expect(context.connections.load().map(\.id) == [LegacyImportContext.secondID])
        #expect(try context.keychain.token(for: LegacyImportContext.firstID) == nil)
        #expect(try context.keychain.token(for: LegacyImportContext.secondID) == "install-token")
        #expect(context.isComplete)
    }

    @Test func connectionWriteMustSucceedBeforeImportIsMarkedComplete() throws {
        let context = LegacyImportContext()
        try context.setDevices([context.device()])
        context.storage.secrets["muxy.installToken"] = "install-token"
        let connections = DiscardingMigrationConnectionStore()
        let importer = LegacyConnectionImporter(storage: context.storage, connections: connections, keychain: context.keychain, defaults: context.defaults)

        importer.run()

        #expect(connections.load().isEmpty)
        #expect(!context.isComplete)
        connections.discardsWrites = false
        importer.run()
        #expect(connections.load().map(\.id) == [LegacyImportContext.firstID])
        #expect(context.isComplete)
    }

    @Test func unreadableStoreDoesNotPreventOtherStoresFromImporting() throws {
        let context = LegacyImportContext()
        try context.setDevices([context.device()])
        context.storage.secrets["muxy.installToken"] = "install-token"
        context.storage.unreadableValues.insert("muxy.ssh.connections.v1")

        context.run()

        #expect(context.connections.load().count == 1)
        #expect(!context.isComplete)
        context.storage.unreadableValues.removeAll()
        context.run()
        #expect(context.connections.load().count == 1)
        #expect(context.isComplete)
    }

    @Test(arguments: ["{", #"{"version":1,"state":{"devices":[]}}"#])
    func invalidOrUnsupportedStateDoesNotCompleteMigration(encoded: String) {
        let context = LegacyImportContext()
        context.storage.values["muxy.devices.v1"] = Data(encoded.utf8)

        context.run()

        #expect(context.connections.load().isEmpty)
        #expect(!context.isComplete)
    }

    @Test func invalidSSHHostFingerprintIsNotSilentlyDropped() throws {
        let context = LegacyImportContext()
        let id = LegacyImportContext.firstID
        try context.setSSHConnections([context.sshConnection(id: id, authType: "password")])
        try context.setSSHCredential(["type": "password", "password": "password"], id: id)
        context.storage.values["muxy.ssh.knownHosts.v1"] = try JSONSerialization.data(withJSONObject: [id.uuidString.lowercased(): "invalid"])

        context.run()

        #expect(context.connections.load().isEmpty)
        #expect(try context.keychain.secret(.sshPassword, for: id) == nil)
        #expect(!context.isComplete)
        let fingerprint = String(repeating: "ab", count: 32)
        context.storage.values["muxy.ssh.knownHosts.v1"] = try JSONSerialization.data(withJSONObject: [id.uuidString.lowercased(): fingerprint])
        context.run()
        #expect(context.connections.load().count == 1)
        #expect(try context.keychain.secret(.sshHostKey, for: id) == fingerprint)
        #expect(context.isComplete)
    }

    @Test func freshInstallCompletesWithoutCreatingConnections() {
        let context = LegacyImportContext()

        context.run()

        #expect(context.connections.load().isEmpty)
        #expect(context.isComplete)
    }
}

@MainActor
private final class LegacyImportContext {
    nonisolated static let firstID = UUID(uuidString: "a1234567-89ab-4cde-8fab-0123456789ab")!
    nonisolated static let secondID = UUID(uuidString: "b1234567-89ab-4cde-8fab-0123456789ab")!
    nonisolated static let installID = "dEADBEEF-1234-4aBc-8dEf-0123456789ab"

    let storage = StubLegacyStorage()
    let keychain = FailingMigrationKeychainStore()
    let defaults: UserDefaults
    let connections: UserDefaultsConnectionStore
    private let suiteName = "muxy.tests.legacy.\(UUID().uuidString)"

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        connections = UserDefaultsConnectionStore(defaults: defaults)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    var isComplete: Bool {
        defaults.bool(forKey: "muxy.legacyConnections.completed")
    }

    func run() {
        LegacyConnectionImporter(storage: storage, connections: connections, keychain: keychain, defaults: defaults).run()
    }

    func device(id: UUID = LegacyImportContext.firstID) -> [String: Any] {
        [
            "id": id.uuidString.lowercased(),
            "label": "Studio",
            "host": "studio.local",
            "port": 4865,
            "serviceName": "Studio",
            "pairedAt": "2026-01-01T00:00:00.000Z",
            "pairing": ["clientID": "client", "deviceName": "iPhone"],
        ]
    }

    func setDevices(_ devices: [Any], installID: String? = LegacyImportContext.installID) throws {
        var state: [String: Any] = ["devices": devices]
        state["installDeviceID"] = installID
        storage.values["muxy.devices.v1"] = try JSONSerialization.data(withJSONObject: ["version": 0, "state": state])
    }

    func sshConnection(id: UUID, authType: String) -> [String: Any] {
        ["id": id.uuidString.lowercased(), "name": "Server", "host": "ssh.local", "port": 22,
         "username": "developer", "authType": authType, "createdAt": "2026-01-01T00:00:00.000Z", "updatedAt": "2026-01-01T00:00:00.000Z"]
    }

    func setSSHConnections(_ connections: [[String: Any]]) throws {
        storage.values["muxy.ssh.connections.v1"] = try JSONSerialization.data(withJSONObject: ["version": 0, "state": ["connections": connections]])
    }

    func setSSHCredential(_ credential: [String: String], id: UUID) throws {
        let data = try JSONSerialization.data(withJSONObject: credential)
        storage.secrets["muxy.ssh.credentials.\(id.uuidString.lowercased())"] = String(decoding: data, as: UTF8.self)
    }
}

@MainActor
private final class StubLegacyStorage: LegacyStorage {
    var values: [String: Data] = [:]
    var secrets: [String: String] = [:]
    var unreadableValues: Set<String> = []
    var unreadableSecrets: Set<String> = []
    private(set) var valueReads = 0

    func value(for key: String) throws -> Data? {
        valueReads += 1
        guard !unreadableValues.contains(key) else { throw CocoaError(.fileReadNoPermission) }
        return values[key]
    }

    func secret(for key: String) throws -> String? {
        guard !unreadableSecrets.contains(key) else { throw KeychainError.unexpectedStatus(-25308) }
        return secrets[key]
    }
}

@MainActor
private final class FailingMigrationKeychainStore: KeychainStore {
    var failingIDs: Set<UUID> = []
    private let backing = InMemoryKeychainStore()

    func setSecret(_ value: String, _ secret: KeychainSecret, for connectionID: Connection.ID) throws {
        guard !failingIDs.contains(connectionID) else { throw KeychainError.unexpectedStatus(-25308) }
        try backing.setSecret(value, secret, for: connectionID)
    }

    func secret(_ secret: KeychainSecret, for connectionID: Connection.ID) throws -> String? {
        try backing.secret(secret, for: connectionID)
    }

    func deleteSecrets(for connectionID: Connection.ID) throws {
        try backing.deleteSecrets(for: connectionID)
    }
}

@MainActor
private final class DiscardingMigrationConnectionStore: ConnectionStore {
    var discardsWrites = true
    private let backing = InMemoryConnectionStore()

    func load() -> [Connection] { backing.load() }
    func save(_ connections: [Connection]) {
        guard !discardsWrites else { return }
        backing.save(connections)
    }
    func upsert(_ connection: Connection) {
        guard !discardsWrites else { return }
        backing.upsert(connection)
    }
    func delete(id: Connection.ID) { backing.delete(id: id) }
}
