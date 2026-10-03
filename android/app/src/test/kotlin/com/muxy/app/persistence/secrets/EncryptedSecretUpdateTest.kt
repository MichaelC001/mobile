@file:OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)

package com.muxy.app.persistence.secrets

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import com.muxy.app.persistence.preferencesDataStore
import com.muxy.app.testing.XorSecretCipher
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException

class EncryptedSecretUpdateTest {
    @get:Rule
    val folder = TemporaryFolder()

    @Test
    fun batchUpdatesReplaceAndRemoveSecretsWithoutChangingHostTrust() =
        runTest {
            val fixture = Fixture(this)
            fixture.store.write("password", "old")
            fixture.store.write("passphrase", "old-phrase")
            fixture.store.write("host-key", "fingerprint")
            var committed = false

            fixture.store.update(mapOf("password" to null, "key" to "new-key", "passphrase" to null)) {
                assertEquals("new-key", fixture.store.read("key"))
                assertNull(fixture.store.read("password"))
                committed = true
            }

            assertTrue(committed)
            assertEquals("fingerprint", fixture.store.read("host-key"))
            assertNull(fixture.store.read("passphrase"))
        }

    @Test
    fun metadataFailureRestoresTheExactPreviousEncryptedValues() =
        runTest {
            val fixture = Fixture(this)
            fixture.store.write("password", "old")
            fixture.store.write("host-key", "fingerprint")
            val previous = fixture.data.data.first()
            val failure = IOException("Metadata unavailable")

            val result =
                runCatching {
                    fixture.store.update(mapOf("password" to null, "key" to "new-key")) { throw failure }
                }

            assertTrue(result.exceptionOrNull() is IOException)
            assertEquals(failure.message, result.exceptionOrNull()?.message)
            assertEquals(previous, fixture.data.data.first())
            assertEquals("old", fixture.store.read("password"))
            assertNull(fixture.store.read("key"))
        }

    @Test
    fun encryptionFailureDoesNotPartiallyWriteTheBatch() =
        runTest {
            val cipher =
                object : SecretCipher by XorSecretCipher {
                    override fun seal(
                        plaintext: ByteArray,
                        associatedData: ByteArray,
                    ): ByteArray {
                        if (plaintext.toString(Charsets.UTF_8) == "unsealable") throw IOException("Encryption unavailable")
                        return XorSecretCipher.seal(plaintext, associatedData)
                    }
                }
            val fixture = Fixture(this, cipher)
            fixture.store.write("password", "old")
            val previous = fixture.data.data.first()
            var committed = false

            val result =
                runCatching {
                    fixture.store.update(mapOf("password" to "new", "key" to "unsealable")) { committed = true }
                }

            assertTrue(result.isFailure)
            assertFalse(committed)
            assertEquals(previous, fixture.data.data.first())
        }

    @Test
    fun cancellationCannotInterruptAnInProgressCommit() =
        runTest {
            val fixture = Fixture(this)
            val enteredCommit = CompletableDeferred<Unit>()
            val finishCommit = CompletableDeferred<Unit>()
            var committed = false
            val saving =
                launch {
                    fixture.store.update(mapOf("password" to "new")) {
                        enteredCommit.complete(Unit)
                        finishCommit.await()
                        committed = true
                    }
                }
            runCurrent()
            enteredCommit.await()
            saving.cancel()
            finishCommit.complete(Unit)
            saving.join()

            assertTrue(committed)
            assertEquals("new", fixture.store.read("password"))
        }

    @Test
    fun aCommitThatThrowsCancellationStillRollsBack() =
        runTest {
            val fixture = Fixture(this)
            fixture.store.write("password", "old")

            val result =
                runCatching {
                    fixture.store.update(mapOf("password" to "new")) { throw CancellationException("Commit cancelled") }
                }

            assertTrue(result.exceptionOrNull() is CancellationException)
            assertEquals("old", fixture.store.read("password"))
        }

    @Test
    fun failedRollbackIsReportedAsRecoveryFailure() =
        runTest {
            val fixture = Fixture(this, failsRollback = true)
            fixture.store.write("password", "old")
            val failure = IOException("Metadata unavailable")

            val result =
                runCatching {
                    fixture.store.update(mapOf("password" to "new")) { throw failure }
                }

            assertTrue(result.exceptionOrNull() is SecretUpdateRecoveryException)
            assertTrue(generateSequence(result.exceptionOrNull()) { it.cause }.any { it is IOException && it.message == failure.message })
        }

    private inner class Fixture(
        test: TestScope,
        cipher: SecretCipher = XorSecretCipher,
        failsRollback: Boolean = false,
    ) {
        private val dispatcher = StandardTestDispatcher(test.testScheduler)
        private val scope = CoroutineScope(dispatcher + Job(test.backgroundScope.coroutineContext[Job]))
        val data = preferencesDataStore("UpdateSecrets", scope) { File(folder.newFolder(), "secrets.preferences_pb") }
        private val backing =
            if (failsRollback) {
                object : DataStore<Preferences> by data {
                    private var writes = 0

                    override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences {
                        writes += 1
                        if (writes == 3) throw IOException("Rollback unavailable")
                        return this@Fixture.data.updateData(transform)
                    }
                }
            } else {
                data
            }
        val store = EncryptedSecretStore(backing, cipher, dispatcher)
    }
}
