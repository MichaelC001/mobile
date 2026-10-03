package com.muxy.app.persistence.secrets

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.muxy.app.core.logging.Log
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.IOException
import java.util.Base64

class EncryptedSecretStore(
    private val dataStore: DataStore<Preferences>,
    private val cipher: SecretCipher,
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
) : SecretStore,
    SecretUpdating {
    private val updateMutex = Mutex()

    override suspend fun update(
        values: Map<String, String?>,
        commit: suspend () -> Unit,
    ) {
        updateMutex.withLock {
            withContext(NonCancellable) {
                val encoded = values.mapValues { (name, value) -> value?.let { encode(name, it) } }
                var previous = emptyMap<String, String?>()
                dataStore.edit { preferences ->
                    previous = encoded.mapValues { (name, _) -> preferences[stringPreferencesKey(name)] }
                    encoded.forEach { (name, value) ->
                        val key = stringPreferencesKey(name)
                        if (value == null) preferences.remove(key) else preferences[key] = value
                    }
                }
                try {
                    commit()
                } catch (error: Throwable) {
                    try {
                        dataStore.edit { preferences ->
                            previous.forEach { (name, value) ->
                                val key = stringPreferencesKey(name)
                                if (value == null) preferences.remove(key) else preferences[key] = value
                            }
                        }
                    } catch (rollbackError: Throwable) {
                        Log.persistence.error("Restoring edited credentials failed: ${rollbackError.javaClass.simpleName}")
                        throw SecretUpdateRecoveryException(error)
                    }
                    throw error
                }
            }
        }
    }

    override suspend fun read(name: String): String? {
        val encoded =
            try {
                dataStore.data.first()[stringPreferencesKey(name)]
            } catch (error: IOException) {
                Log.persistence.error("Reading a secret failed", error)
                null
            } ?: return null
        val sealed =
            try {
                Base64.getDecoder().decode(encoded)
            } catch (error: IllegalArgumentException) {
                Log.persistence.error("A stored secret is malformed", error)
                return null
            }
        return withContext(dispatcher) { cipher.open(sealed, name.toByteArray()) }?.toString(Charsets.UTF_8)
    }

    override suspend fun write(
        name: String,
        value: String,
    ) {
        val encoded = encode(name, value)
        dataStore.edit { it[stringPreferencesKey(name)] = encoded }
    }

    override suspend fun delete(name: String) {
        dataStore.edit { it.remove(stringPreferencesKey(name)) }
    }

    private suspend fun encode(
        name: String,
        value: String,
    ): String {
        val sealed = withContext(dispatcher) { cipher.seal(value.toByteArray(), name.toByteArray()) }
        return Base64.getEncoder().encodeToString(sealed)
    }
}

class SecretUpdateRecoveryException(
    cause: Throwable,
) : Exception("Couldn't restore the previous credentials. Check the connection settings before connecting.", cause)
