import Foundation
import MuxyMobile
import Testing
@testable import Muxy

@MainActor
struct EditConnectionViewModelTests {
    @Test func prefillsDetailsWithoutDisplayingSavedSecrets() throws {
        let fixture = Fixture(kind: .ssh)
        try fixture.keychain.setSecret("saved-password", .sshPassword, for: fixture.original.id)

        #expect(fixture.model.name == fixture.original.name)
        #expect(fixture.model.host == fixture.original.host)
        #expect(fixture.model.portText == String(fixture.original.port))
        #expect(fixture.model.username == "alice")
        #expect(fixture.model.authMethod == .password)
        #expect(!fixture.model.replacesCredentials)
        #expect(fixture.model.password.isEmpty)
        #expect(fixture.model.privateKey.isEmpty)
        #expect(fixture.model.passphrase.isEmpty)
        #expect(fixture.model.canSave)
    }

    @Test func anUnsavedDraftDoesNotChangeStorage() throws {
        let fixture = Fixture(kind: .ssh)
        try fixture.keychain.setSecret("old", .sshPassword, for: fixture.original.id)
        fixture.model.name = "Draft"
        fixture.model.host = "other.local"
        fixture.model.replacesCredentials = true
        fixture.model.password = "new"

        #expect(fixture.connections.load() == [fixture.original])
        #expect(try fixture.keychain.secret(.sshPassword, for: fixture.original.id) == "old")
        #expect(try fixture.keychain.secret(.sshCredentials, for: fixture.original.id) == nil)
    }

    @Test(arguments: ["", "0", "65536", "abc", "-1"])
    func invalidPortsCannotSave(port: String) {
        let fixture = Fixture()
        fixture.model.portText = port
        #expect(!fixture.model.canSave)
        #expect(!fixture.model.save())
        #expect(fixture.connections.load() == [fixture.original])
    }

    @Test(arguments: ["1", "65535"])
    func validPortBoundariesCanSave(port: String) {
        let fixture = Fixture()
        fixture.model.portText = port
        #expect(fixture.model.save())
        #expect(fixture.connections.load().first?.port == Int(port))
    }

    @Test func blankDetailsAndInvalidHostsCannotSave() {
        let fixture = Fixture(kind: .ssh)
        fixture.model.name = "  "
        #expect(!fixture.model.canSave)
        fixture.model.name = "Studio"
        fixture.model.host = "https://studio.local"
        #expect(!fixture.model.canSave)
        fixture.model.host = "studio.local"
        fixture.model.username = " \n"
        #expect(!fixture.model.canSave)
    }

    @Test func savesDeviceDetailsInPlaceAndPreservesPairingIdentity() throws {
        let fixture = Fixture()
        try fixture.keychain.setToken("paired-token", for: fixture.original.id)
        fixture.model.name = " Renamed "
        fixture.model.host = " 10.0.0.20 "
        fixture.model.portText = " 5000 "

        #expect(fixture.model.save())
        let saved = try #require(fixture.connections.load().first)
        #expect(fixture.connections.load().count == 1)
        #expect(saved.id == fixture.original.id)
        #expect(saved.kind == .device)
        #expect(saved.name == "Renamed")
        #expect(saved.host == "10.0.0.20")
        #expect(saved.port == 5000)
        #expect(saved.pairingState == .paired)
        #expect(saved.authenticationDeviceID == fixture.original.authenticationDeviceID)
        #expect(saved.serviceName == nil)
        #expect(saved.discoverySource == .manual)
        #expect(try fixture.keychain.token(for: saved.id) == "paired-token")
        #expect(!fixture.model.save())
        #expect(fixture.connector.connectCount == 0)
    }

    @Test func renamingKeepsDiscoveryMetadata() {
        let fixture = Fixture()
        fixture.model.name = "Renamed"
        #expect(fixture.model.save())
        #expect(fixture.connections.load().first?.serviceName == fixture.original.serviceName)
        #expect(fixture.connections.load().first?.discoverySource == .bonjour)
    }

    @Test(arguments: [false, true])
    func aChangedOrDeletedConnectionIsNotOverwritten(deleted: Bool) {
        let fixture = Fixture()
        if deleted {
            fixture.connections.delete(id: fixture.original.id)
        } else {
            var changed = fixture.original
            changed.name = "Changed elsewhere"
            fixture.connections.upsert(changed)
        }
        let current = fixture.connections.load()
        fixture.model.name = "Stale draft"

        #expect(!fixture.model.save())
        #expect(fixture.model.failure != nil)
        #expect(fixture.connections.load() == current)
    }

    @Test func demoCannotBeSaved() {
        let connection = Connection(id: DemoConnection.id, name: "Demo", host: "demo.local", port: 4865)
        let store = InMemoryConnectionStore(connections: [connection])
        let credentials = InMemoryCredentialStore()
        let model = EditConnectionViewModel(
            connection: connection,
            store: store,
            keychain: InMemoryKeychainStore(),
            credentials: credentials,
            directory: ServerDirectory(credentials: credentials, connector: FakeServerConnector(outcomes: [])),
            validator: ConnectionInputValidator()
        )
        #expect(!model.canSave)
        #expect(!model.save())
        #expect(store.load() == [connection])
    }

    @Test(arguments: [false, true])
    func serverEditsKeepTrustAndUpdateTheActualEndpoint(endpointChanged: Bool) throws {
        let fixture = Fixture(kind: .server)
        let original = Fixtures.credential()
        try fixture.credentials.save(original)
        let controller = try #require(fixture.directory.controller(for: original.serverId))
        fixture.model.name = "Renamed"
        if endpointChanged {
            fixture.model.host = "100.64.0.2"
            fixture.model.portText = "8000"
        }

        #expect(fixture.model.save())
        let saved = try #require(try fixture.credentials.credential(serverId: original.serverId))
        #expect(saved.serverName == "Renamed")
        #expect(saved.hosts == (endpointChanged ? ["100.64.0.2"] : original.hosts))
        #expect(saved.port == (endpointChanged ? 8000 : original.port))
        #expect(saved.serverId == original.serverId)
        #expect(saved.deviceId == original.deviceId)
        #expect(saved.token == original.token)
        #expect(saved.fingerprint == original.fingerprint)
        #expect(controller.serverName == "Renamed")
        #expect(fixture.connector.connectCount == 0)
        #expect(fixture.connections.load().first?.id == fixture.original.id)
    }

    @Test func missingServerCredentialsDoNotSaveMetadata() {
        let fixture = Fixture(kind: .server)
        fixture.model.host = "other.local"
        #expect(!fixture.model.save())
        #expect(fixture.model.failure != nil)
        #expect(fixture.connections.load() == [fixture.original])
    }

    @Test func secureServerSaveFailurePreservesMetadataAndCredentials() throws {
        let credentials = RejectingCredentialStore()
        let fixture = Fixture(kind: .server, credentials: credentials)
        fixture.model.host = "other.local"
        #expect(!fixture.model.save())
        #expect(!fixture.model.hasSaved)
        #expect(fixture.connections.load() == [fixture.original])
        #expect(try credentials.credential(serverId: "server-1") == Fixtures.credential())
    }

    @Test func sshDetailsKeepSavedSecretsAndHostTrust() throws {
        let fixture = Fixture(kind: .ssh)
        try fixture.keychain.setSecret("old", .sshPassword, for: fixture.original.id)
        try fixture.keychain.setSecret("fingerprint", .sshHostKey, for: fixture.original.id)
        fixture.model.username = " bob "
        fixture.model.host = "other.local"

        #expect(fixture.model.save())
        #expect(fixture.connections.load().first?.sshConfig == SSHConfig(username: "bob", authMethod: .password))
        #expect(try fixture.keychain.sshCredentials(for: fixture.original.id, authMethod: .password).secret == "old")
        #expect(try fixture.keychain.secret(.sshHostKey, for: fixture.original.id) == "fingerprint")
    }

    @Test func replacingCredentialsRequiresASecretAndCanBeCancelled() {
        let fixture = Fixture(kind: .ssh)
        fixture.model.replacesCredentials = true
        #expect(!fixture.model.canSave)
        fixture.model.password = "new"
        #expect(fixture.model.canSave)
        fixture.model.authMethod = .privateKey
        #expect(!fixture.model.canSave)
        fixture.model.privateKey = "new-key"
        fixture.model.passphrase = "phrase"
        #expect(fixture.model.canSave)
        fixture.model.replacesCredentials = false
        #expect(fixture.model.authMethod == .password)
        #expect(fixture.model.canSave)
        #expect(fixture.model.password.isEmpty)
        #expect(fixture.model.privateKey.isEmpty)
        #expect(fixture.model.passphrase.isEmpty)
    }

    @Test(arguments: [SSHAuthMethod.password, .privateKey])
    func replacementSavesTheSelectedSecretAndKeepsHostTrust(method: SSHAuthMethod) throws {
        let fixture = Fixture(kind: .ssh)
        try fixture.keychain.setSecret("fingerprint", .sshHostKey, for: fixture.original.id)
        try fixture.keychain.setSecret("old-phrase", .sshPassphrase, for: fixture.original.id)
        fixture.model.replacesCredentials = true
        fixture.model.authMethod = method
        fixture.model.password = "new-password"
        fixture.model.privateKey = "new-key"

        #expect(fixture.model.save())
        let saved = try fixture.keychain.sshCredentials(for: fixture.original.id, authMethod: method)
        #expect(saved.secret == (method == .password ? "new-password" : "new-key"))
        #expect(saved.passphrase == nil)
        #expect(fixture.connections.load().first?.sshConfig?.authMethod == method)
        #expect(try fixture.keychain.secret(.sshHostKey, for: fixture.original.id) == "fingerprint")
        #expect(fixture.model.password.isEmpty)
        #expect(fixture.model.privateKey.isEmpty)
    }

    @Test func failedSSHReplacementKeepsThePreviousSecretAndMethod() throws {
        let keychain = RejectingSSHReplacementStore()
        let fixture = Fixture(kind: .ssh, keychain: keychain)
        try keychain.setSecret("old", .sshPassword, for: fixture.original.id)
        fixture.model.replacesCredentials = true
        fixture.model.authMethod = .privateKey
        fixture.model.privateKey = "replacement"

        #expect(!fixture.model.save())
        #expect(fixture.model.failure != nil)
        #expect(fixture.connections.load() == [fixture.original])
        #expect(try keychain.sshCredentials(for: fixture.original.id, authMethod: .password).secret == "old")
    }

    @MainActor
    private final class Fixture {
        let original: Muxy.Connection
        let connections: InMemoryConnectionStore
        let keychain: any KeychainStore
        let credentials: any CredentialStore
        let connector = FakeServerConnector(outcomes: [])
        let directory: ServerDirectory
        let model: EditConnectionViewModel

        init(
            kind: ConnectionKind = .device,
            keychain: any KeychainStore = InMemoryKeychainStore(),
            credentials: any CredentialStore = InMemoryCredentialStore()
        ) {
            original = Connection(
                id: UUID(), name: "Studio", host: "192.168.1.20", port: 7419,
                kind: kind, pairingState: .paired, serviceName: "Studio", discoverySource: .bonjour,
                sshConfig: kind == .ssh ? SSHConfig(username: "alice", authMethod: .password) : nil,
                serverID: kind == .server ? "server-1" : nil,
                authenticationDeviceID: "legacy-device"
            )
            connections = InMemoryConnectionStore(connections: [original])
            self.keychain = keychain
            self.credentials = credentials
            directory = ServerDirectory(credentials: credentials, connector: connector)
            model = EditConnectionViewModel(
                connection: original, store: connections, keychain: keychain,
                credentials: credentials, directory: directory, validator: ConnectionInputValidator()
            )
        }
    }
}

private struct RejectingSSHReplacementStore: KeychainStore {
    let storage = InMemoryKeychainStore()

    func setSecret(_ value: String, _ secret: KeychainSecret, for connectionID: UUID) throws {
        guard secret != .sshCredentials else { throw KeychainError.unexpectedStatus(-1) }
        try storage.setSecret(value, secret, for: connectionID)
    }

    func secret(_ secret: KeychainSecret, for connectionID: UUID) throws -> String? {
        try storage.secret(secret, for: connectionID)
    }

    func deleteSecrets(for connectionID: UUID) throws {
        try storage.deleteSecrets(for: connectionID)
    }
}

private struct RejectingCredentialStore: CredentialStore {
    func all() throws -> [ServerCredential] { [Fixtures.credential()] }
    func credential(serverId: String) throws -> ServerCredential? { Fixtures.credential() }
    func save(_ credential: ServerCredential) throws { throw KeychainError.unexpectedStatus(-1) }
    func delete(serverId: String) throws {}
}
