@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.muxy.app.features.editconnection

import com.muxy.app.core.validation.ConnectionInputValidator
import com.muxy.app.features.demo.DemoConnection
import com.muxy.app.features.server.ServerDirectory
import com.muxy.app.models.Connection
import com.muxy.app.models.ConnectionKind
import com.muxy.app.models.DiscoverySource
import com.muxy.app.models.SshAuthMethod
import com.muxy.app.models.SshConfig
import com.muxy.app.persistence.connections.ConnectionStore
import com.muxy.app.persistence.credentials.SecretCredentialStore
import com.muxy.app.persistence.preferencesDataStore
import com.muxy.app.persistence.secrets.ConnectionSecret
import com.muxy.app.persistence.secrets.EncryptedSecretStore
import com.muxy.app.persistence.secrets.SecretCipher
import com.muxy.app.testing.FailingSecretCipher
import com.muxy.app.testing.FakeServerConnector
import com.muxy.app.testing.InMemoryConnectionStore
import com.muxy.app.testing.MainDispatcherRule
import com.muxy.app.testing.XorSecretCipher
import com.muxy.app.testing.device
import com.muxy.app.testing.serverCredential
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException

class EditConnectionViewModelTest {
    @get:Rule
    val mainDispatcher = MainDispatcherRule(StandardTestDispatcher())

    @get:Rule
    val folder = TemporaryFolder()

    @Test
    fun prefillsDetailsWithoutDisplayingSavedSecrets() =
        runTest {
            val fixture = Fixture(this, ssh())
            fixture.secret(ConnectionSecret.SSH_PASSWORD, "saved")
            advanceUntilIdle()
            val model = fixture.model
            assertEquals(fixture.original.name, model.name)
            assertEquals(fixture.original.host, model.host)
            assertEquals("22", model.portText)
            assertEquals("alice", model.username)
            assertEquals(SshAuthMethod.PASSWORD, model.authMethod)
            assertFalse(model.replaceCredentials)
            assertEquals("", model.password)
            assertEquals("", model.privateKey)
            assertEquals("", model.passphrase)
            assertTrue(model.canSave)
        }

    @Test
    fun anUnsavedDraftDoesNotChangeStorage() =
        runTest {
            val fixture = Fixture(this, ssh())
            fixture.secret(ConnectionSecret.SSH_PASSWORD, "old")
            advanceUntilIdle()
            fixture.model.name = "Draft"
            fixture.model.host = "other.local"
            fixture.model.changeCredentialReplacement(true)
            fixture.model.password = "new"
            assertEquals(listOf(fixture.original), fixture.connections.load())
            assertEquals("old", fixture.secret(ConnectionSecret.SSH_PASSWORD))
        }

    @Test
    fun invalidFieldsCannotSaveAndPortBoundariesAreAccepted() =
        runTest {
            val fixture = Fixture(this, ssh())
            advanceUntilIdle()
            for (port in listOf("", "0", "65536", "abc", "-1")) {
                fixture.model.portText = port
                assertFalse(fixture.model.canSave)
                fixture.model.save()
            }
            for (port in listOf("1", "65535")) {
                fixture.model.portText = port
                assertTrue(fixture.model.canSave)
            }
            fixture.model.name = " "
            assertFalse(fixture.model.canSave)
            fixture.model.name = "Studio"
            fixture.model.host = "https://studio.local"
            assertFalse(fixture.model.canSave)
            fixture.model.host = "studio.local"
            fixture.model.username = " "
            assertFalse(fixture.model.canSave)
            assertEquals(listOf(fixture.original), fixture.connections.load())
        }

    @Test
    fun savesDeviceDetailsInPlaceAndPreservesPairing() =
        runTest {
            val original = device(serviceName = "Studio").copy(discoverySource = DiscoverySource.BONJOUR)
            val fixture = Fixture(this, original)
            fixture.secret(ConnectionSecret.TOKEN, "paired-credential")
            advanceUntilIdle()
            fixture.model.name = " Renamed "
            fixture.model.host = " 10.0.0.20 "
            fixture.model.portText = " 5000 "
            fixture.model.save()
            assertTrue(fixture.model.isSaving)
            fixture.model.save()
            advanceUntilIdle()
            val saved = fixture.connections.load().single()
            assertEquals(original.id, saved.id)
            assertEquals(original.kind, saved.kind)
            assertEquals(original.pairingState, saved.pairingState)
            assertEquals("Renamed", saved.name)
            assertEquals("10.0.0.20", saved.host)
            assertEquals(5000, saved.port)
            assertNull(saved.serviceName)
            assertEquals(DiscoverySource.MANUAL, saved.discoverySource)
            assertEquals("paired-credential", fixture.secret(ConnectionSecret.TOKEN))
            assertTrue(fixture.model.saved)
            assertFalse(fixture.model.canSave)
            assertFalse(fixture.model.isSaving)
            assertEquals(0, fixture.connector.connectCount)
        }

    @Test
    fun renamingKeepsDiscoveryMetadata() =
        runTest {
            val original = device(serviceName = "Studio").copy(discoverySource = DiscoverySource.BONJOUR)
            val fixture = Fixture(this, original)
            advanceUntilIdle()
            fixture.model.name = "Renamed"
            fixture.model.save()
            advanceUntilIdle()
            assertEquals(original.copy(name = "Renamed"), fixture.connections.load().single())
        }

    @Test
    fun aChangedOrDeletedConnectionIsNotOverwritten() =
        runTest {
            for (deleted in listOf(false, true)) {
                val fixture = Fixture(this)
                advanceUntilIdle()
                if (deleted) {
                    fixture.connections.delete(fixture.original.id)
                } else {
                    fixture.connections.upsert(fixture.original.copy(name = "Changed elsewhere"))
                }
                val current = fixture.connections.load()
                fixture.model.name = "Stale draft"
                fixture.model.save()
                advanceUntilIdle()
                assertFalse(fixture.model.saved)
                assertNotNull(fixture.model.failure)
                assertEquals(current, fixture.connections.load())
            }
        }

    @Test
    fun demoConnectionsCannotBeEdited() =
        runTest {
            val fixture = Fixture(this, device(id = DemoConnection.id))
            advanceUntilIdle()
            assertNull(fixture.model.connection)
            assertFalse(fixture.model.canSave)
            assertNotNull(fixture.model.failure)
        }

    @Test
    fun serverEditsUpdateSecureEndpointsWithoutChangingTrust() =
        runTest {
            for (endpointChanged in listOf(false, true)) {
                val credential = serverCredential()
                val connection =
                    device(host = credential.hosts.first(), port = credential.port.toInt())
                        .copy(kind = ConnectionKind.SERVER, serverId = credential.serverId)
                val fixture = Fixture(this, connection)
                fixture.credentials.save(credential)
                fixture.directory.controller(credential.serverId)
                advanceUntilIdle()
                fixture.model.name = "Renamed"
                if (endpointChanged) {
                    fixture.model.host = "100.64.0.2"
                    fixture.model.portText = "8000"
                }
                fixture.model.save()
                advanceUntilIdle()
                val saved = fixture.credentials.credential(credential.serverId)!!
                assertEquals("Renamed", saved.serverName)
                assertEquals(if (endpointChanged) listOf("100.64.0.2") else credential.hosts, saved.hosts)
                assertEquals(if (endpointChanged) 8000 else credential.port.toInt(), saved.port.toInt())
                assertEquals(credential.serverId, saved.serverId)
                assertEquals(credential.deviceId, saved.deviceId)
                assertArrayEquals(credential.token, saved.token)
                assertArrayEquals(credential.fingerprint, saved.fingerprint)
                assertEquals(
                    connection.id,
                    fixture.connections
                        .load()
                        .single()
                        .id,
                )
                assertEquals(0, fixture.connector.connectCount)
                assertTrue(fixture.model.saved)
            }
        }

    @Test
    fun missingServerCredentialsDoNotSaveMetadata() =
        runTest {
            val fixture = Fixture(this, device().copy(kind = ConnectionKind.SERVER, serverId = "server-1"))
            advanceUntilIdle()
            fixture.model.host = "other.local"
            fixture.model.save()
            advanceUntilIdle()
            assertFalse(fixture.model.saved)
            assertNotNull(fixture.model.failure)
            assertEquals(listOf(fixture.original), fixture.connections.load())
        }

    @Test
    fun sshDetailsPreserveCredentialsAndHostTrust() =
        runTest {
            val fixture = Fixture(this, ssh())
            fixture.secret(ConnectionSecret.SSH_PASSWORD, "saved")
            fixture.secret(ConnectionSecret.SSH_HOST_KEY, "fingerprint")
            advanceUntilIdle()
            fixture.model.username = " bob "
            fixture.model.host = "other.local"
            fixture.model.save()
            advanceUntilIdle()
            assertEquals(
                SshConfig("bob", SshAuthMethod.PASSWORD),
                fixture.connections
                    .load()
                    .single()
                    .sshConfig,
            )
            assertEquals("saved", fixture.secret(ConnectionSecret.SSH_PASSWORD))
            assertEquals("fingerprint", fixture.secret(ConnectionSecret.SSH_HOST_KEY))
        }

    @Test
    fun replacingCredentialsRequiresASecretAndCanBeCancelled() =
        runTest {
            val fixture = Fixture(this, ssh())
            advanceUntilIdle()
            val model = fixture.model
            model.selectAuthMethod(SshAuthMethod.PRIVATE_KEY)
            assertEquals(SshAuthMethod.PASSWORD, model.authMethod)
            model.changeCredentialReplacement(true)
            assertFalse(model.canSave)
            model.password = "new"
            assertTrue(model.canSave)
            model.selectAuthMethod(SshAuthMethod.PRIVATE_KEY)
            assertFalse(model.canSave)
            assertEquals("", model.password)
            model.privateKey = "new-key"
            model.passphrase = "phrase"
            assertTrue(model.canSave)
            model.changeCredentialReplacement(false)
            assertEquals(SshAuthMethod.PASSWORD, model.authMethod)
            assertEquals("", model.privateKey)
            assertEquals("", model.passphrase)
            assertTrue(model.canSave)
        }

    @Test
    fun replacingSshCredentialsSwitchesMethodsAndKeepsHostTrust() =
        runTest {
            for (method in SshAuthMethod.entries) {
                val fixture = Fixture(this, ssh())
                fixture.secret(ConnectionSecret.SSH_PASSWORD, "old-password")
                fixture.secret(ConnectionSecret.SSH_PRIVATE_KEY, "old-key")
                fixture.secret(ConnectionSecret.SSH_PASSPHRASE, "old-phrase")
                fixture.secret(ConnectionSecret.SSH_HOST_KEY, "fingerprint")
                advanceUntilIdle()
                fixture.model.changeCredentialReplacement(true)
                fixture.model.selectAuthMethod(method)
                fixture.model.password = "new-password"
                fixture.model.privateKey = "new-key"
                fixture.model.save()
                advanceUntilIdle()
                assertTrue(fixture.model.saved)
                assertEquals(
                    method,
                    fixture.connections
                        .load()
                        .single()
                        .sshConfig!!
                        .authMethod,
                )
                assertEquals(if (method == SshAuthMethod.PASSWORD) "new-password" else null, fixture.secret(ConnectionSecret.SSH_PASSWORD))
                assertEquals(if (method == SshAuthMethod.PRIVATE_KEY) "new-key" else null, fixture.secret(ConnectionSecret.SSH_PRIVATE_KEY))
                assertNull(fixture.secret(ConnectionSecret.SSH_PASSPHRASE))
                assertEquals("fingerprint", fixture.secret(ConnectionSecret.SSH_HOST_KEY))
                assertEquals("", fixture.model.password)
                assertEquals("", fixture.model.privateKey)
            }
        }

    @Test
    fun metadataFailureRollsBackSshCredentialReplacement() =
        runTest {
            val fixture = Fixture(this, ssh(), failsMetadata = true)
            fixture.secret(ConnectionSecret.SSH_PASSWORD, "old-password")
            fixture.secret(ConnectionSecret.SSH_HOST_KEY, "fingerprint")
            advanceUntilIdle()
            fixture.model.changeCredentialReplacement(true)
            fixture.model.selectAuthMethod(SshAuthMethod.PRIVATE_KEY)
            fixture.model.privateKey = "new-key"
            fixture.model.passphrase = "new-phrase"
            fixture.model.save()
            advanceUntilIdle()
            assertFalse(fixture.model.saved)
            assertNotNull(fixture.model.failure)
            assertEquals(listOf(fixture.original), fixture.connections.load())
            assertEquals("old-password", fixture.secret(ConnectionSecret.SSH_PASSWORD))
            assertNull(fixture.secret(ConnectionSecret.SSH_PRIVATE_KEY))
            assertNull(fixture.secret(ConnectionSecret.SSH_PASSPHRASE))
            assertEquals("fingerprint", fixture.secret(ConnectionSecret.SSH_HOST_KEY))
        }

    @Test
    fun encryptionFailureDoesNotSaveMetadata() =
        runTest {
            val fixture = Fixture(this, ssh(), cipher = FailingSecretCipher)
            advanceUntilIdle()
            fixture.model.changeCredentialReplacement(true)
            fixture.model.password = "new"
            fixture.model.name = "Changed"
            fixture.model.save()
            advanceUntilIdle()
            assertFalse(fixture.model.saved)
            assertNotNull(fixture.model.failure)
            assertEquals(listOf(fixture.original), fixture.connections.load())
        }

    private fun ssh(): Connection =
        device(port = 22).copy(kind = ConnectionKind.SSH, sshConfig = SshConfig("alice", SshAuthMethod.PASSWORD))

    private inner class Fixture(
        test: TestScope,
        val original: Connection = device(),
        failsMetadata: Boolean = false,
        cipher: SecretCipher = XorSecretCipher,
    ) {
        private val dispatcher = StandardTestDispatcher(test.testScheduler)
        private val scope = CoroutineScope(dispatcher + Job(test.backgroundScope.coroutineContext[Job]))
        private val memory = InMemoryConnectionStore(listOf(original))
        val connections: ConnectionStore =
            if (failsMetadata) {
                object : ConnectionStore by memory {
                    override suspend fun update(
                        previous: Connection,
                        connection: Connection,
                    ): Unit = throw IOException("Metadata unavailable")
                }
            } else {
                memory
            }
        private val dataStore = preferencesDataStore("EditSecrets", scope) { File(folder.newFolder(), "secrets.preferences_pb") }
        private val secrets = EncryptedSecretStore(dataStore, cipher, dispatcher)
        val credentials = SecretCredentialStore(secrets)
        val connector = FakeServerConnector(emptyList())
        val directory = ServerDirectory(credentials, connector, test.backgroundScope)
        val model =
            EditConnectionViewModel(
                original.id,
                connections,
                ConnectionEditor(connections, credentials, secrets, directory),
                ConnectionInputValidator(),
            )

        suspend fun secret(
            kind: ConnectionSecret,
            value: String,
        ) {
            secrets.write(kind.name(original.id), value)
        }

        suspend fun secret(kind: ConnectionSecret): String? = secrets.read(kind.name(original.id))
    }
}
