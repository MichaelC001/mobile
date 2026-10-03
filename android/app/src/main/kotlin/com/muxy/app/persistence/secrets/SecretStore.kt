package com.muxy.app.persistence.secrets

interface SecretStore {
    suspend fun read(name: String): String?

    suspend fun write(
        name: String,
        value: String,
    )

    suspend fun delete(name: String)
}

fun interface SecretUpdating {
    suspend fun update(
        values: Map<String, String?>,
        commit: suspend () -> Unit,
    )
}

interface SecretCipher {
    fun seal(
        plaintext: ByteArray,
        associatedData: ByteArray,
    ): ByteArray

    fun open(
        sealed: ByteArray,
        associatedData: ByteArray,
    ): ByteArray?
}
