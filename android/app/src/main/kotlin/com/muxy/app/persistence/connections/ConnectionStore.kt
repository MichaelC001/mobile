package com.muxy.app.persistence.connections

import com.muxy.app.models.Connection
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID

interface ConnectionStore {
    val connections: StateFlow<List<Connection>?>

    suspend fun load(): List<Connection>

    suspend fun upsert(connection: Connection)

    suspend fun delete(id: UUID)

    suspend fun update(
        previous: Connection,
        connection: Connection,
    ) {
        check(load().firstOrNull { it.id == previous.id } == previous) { "Connection changed while editing" }
        require(connection.id == previous.id && connection.kind == previous.kind)
        upsert(connection)
    }
}

fun List<Connection>.withConnection(connection: Connection): List<Connection> {
    if (none { it.id == connection.id }) return this + connection
    return map { if (it.id == connection.id) connection else it }
}
