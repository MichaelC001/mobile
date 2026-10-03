import Foundation
import Security
import Testing
@testable import Muxy

@MainActor
struct IOSLegacyStorageTests {
    @Test func readsInlineValuesWithoutChangingTheManifest() throws {
        let fixture = try LegacyStorageFixture()
        let value = #"{"state":{"label":"工作 Mac"},"version":0}"#
        try fixture.writeManifest(["muxy.devices.v1": value, "empty": ""])
        let manifest = try Data(contentsOf: fixture.directory.appendingPathComponent("manifest.json"))

        #expect(try fixture.storage.value(for: "muxy.devices.v1") == Data(value.utf8))
        #expect(try fixture.storage.value(for: "empty") == Data())
        #expect(try Data(contentsOf: fixture.directory.appendingPathComponent("manifest.json")) == manifest)
    }

    @Test func readsValuesFromTheAsyncStorageMD5Filename() throws {
        let fixture = try LegacyStorageFixture()
        let data = Data(String(repeating: "large-value", count: 200).utf8)
        try fixture.writeManifest(["muxy.devices.v1": NSNull()])
        let file = fixture.directory.appendingPathComponent("9e068f00bd7284fd7c679e333aa9330d")
        try data.write(to: file)

        #expect(try fixture.storage.value(for: "muxy.devices.v1") == data)
        #expect(try Data(contentsOf: file) == data)
    }

    @Test func missingManifestOrEntryReturnsNil() throws {
        let fixture = try LegacyStorageFixture()
        #expect(try fixture.storage.value(for: "muxy.devices.v1") == nil)
        try fixture.writeManifest([:])
        #expect(try fixture.storage.value(for: "muxy.devices.v1") == nil)
    }

    @Test func missingExternalValueThrowsRatherThanTreatingTheStoreAsEmpty() throws {
        let fixture = try LegacyStorageFixture()
        try fixture.writeManifest(["muxy.devices.v1": NSNull()])

        #expect(throws: CocoaError.self) {
            try fixture.storage.value(for: "muxy.devices.v1")
        }
    }

    @Test(arguments: ["{", #"{"muxy.devices.v1":3}"#])
    func invalidManifestThrows(encoded: String) throws {
        let fixture = try LegacyStorageFixture()
        try Data(encoded.utf8).write(to: fixture.directory.appendingPathComponent("manifest.json"))

        #expect(throws: DecodingError.self) {
            try fixture.storage.value(for: "muxy.devices.v1")
        }
    }

    @Test(arguments: [":no-auth", ""])
    func readsExpoKeychainServiceAliases(suffix: String) throws {
        let fixture = try LegacyStorageFixture()
        try fixture.storeSecret(Data("saved-token".utf8), suffix: suffix)

        #expect(try fixture.storage.secret(for: "muxy.installToken") == "saved-token")
        #expect(try fixture.storage.secret(for: "muxy.installToken") == "saved-token")
    }

    @Test func noAuthServiceTakesPrecedenceOverTheLegacyAlias() throws {
        let fixture = try LegacyStorageFixture()
        try fixture.storeSecret(Data("older-token".utf8), suffix: "")
        try fixture.storeSecret(Data("current-token".utf8))

        #expect(try fixture.storage.secret(for: "muxy.installToken") == "current-token")
    }

    @Test func missingSecretReturnsNil() throws {
        let fixture = try LegacyStorageFixture()
        #expect(try fixture.storage.secret(for: "muxy.installToken") == nil)
    }

    @Test func invalidUTF8ThrowsWithoutFallingBackToAnOlderCredential() throws {
        let fixture = try LegacyStorageFixture()
        try fixture.storeSecret(Data([0xff]))
        try fixture.storeSecret(Data("older-token".utf8), suffix: "")

        #expect(throws: KeychainError.encodingFailed) {
            try fixture.storage.secret(for: "muxy.installToken")
        }
    }

    @Test func importsFromLegacyFilesAndKeychainIntoNativeStores() throws {
        let fixture = try LegacyStorageFixture()
        let id = UUID(uuidString: "a1234567-89ab-4cde-8fab-0123456789ab")!
        let installID = "dEADBEEF-1234-4aBc-8dEf-0123456789ab"
        let data = Data("""
        {"version":0,"state":{"installDeviceID":"\(installID)","devices":[
          {"id":"\(id.uuidString.lowercased())","label":"Studio","host":"studio.local","port":4865,
           "pairedAt":"2026-01-01T00:00:00.000Z"}
        ]}}
        """.utf8)
        try fixture.writeManifest(["muxy.devices.v1": NSNull()])
        let file = fixture.directory.appendingPathComponent("9e068f00bd7284fd7c679e333aa9330d")
        try data.write(to: file)
        try fixture.storeSecret(Data("saved-token".utf8))
        let connections = UserDefaultsConnectionStore(defaults: fixture.defaults)
        let keychain = KeychainTokenStore(service: "\(fixture.keychainService).native")

        LegacyConnectionImporter(storage: fixture.storage, connections: connections, keychain: keychain, defaults: fixture.defaults).run()

        let connection = try #require(UserDefaultsConnectionStore(defaults: fixture.defaults).load().first)
        #expect(connection.id == id)
        #expect(connection.authenticationDeviceID == installID)
        #expect(connection.pairingState == .paired)
        #expect(try keychain.token(for: id) == "saved-token")
        #expect(try fixture.storage.secret(for: "muxy.installToken") == "saved-token")
        #expect(try fixture.storage.value(for: "muxy.devices.v1") == data)
        #expect(fixture.defaults.bool(forKey: "muxy.legacyConnections.completed"))
    }
}

@MainActor
private final class LegacyStorageFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("muxy-legacy-\(UUID().uuidString)")
    let keychainService = "com.muxy.app.tests.legacy.\(UUID().uuidString)"
    let defaults: UserDefaults
    private let suiteName = "muxy.tests.legacyStorage.\(UUID().uuidString)"

    init() throws {
        defaults = UserDefaults(suiteName: suiteName)!
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        for service in [keychainService, "\(keychainService):no-auth", "\(keychainService).native"] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    var storage: IOSLegacyStorage {
        IOSLegacyStorage(directory: directory, keychainService: keychainService)
    }

    func writeManifest(_ values: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: values)
        try data.write(to: directory.appendingPathComponent("manifest.json"))
    }

    func storeSecret(_ data: Data, suffix: String = ":no-auth") throws {
        let key = Data("muxy.installToken".utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(keychainService)\(suffix)",
            kSecAttrAccount as String: key,
            kSecAttrGeneric as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        try #require(SecItemAdd(query as CFDictionary, nil) == errSecSuccess)
    }
}
