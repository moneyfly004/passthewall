package com.hiddify.hiddify.utils

import go.Seq
import io.nekohasekai.libbox.CommandClient
import io.nekohasekai.libbox.CommandClientHandler
import io.nekohasekai.libbox.CommandClientOptions
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.OutboundGroup
import io.nekohasekai.libbox.OutboundGroupIterator
import io.nekohasekai.libbox.StatusMessage
import io.nekohasekai.libbox.StringIterator
import com.hiddify.hiddify.ktx.toList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

open class CommandClient(
    private val scope: CoroutineScope,
    private val connectionType: ConnectionType,
    private val handler: Handler
) {

    enum class ConnectionType {
        Status, Groups, Log, ClashMode, GroupOnly
    }

    interface Handler {

        fun onConnected() {}
        fun onDisconnected() {}
        fun updateStatus(status: StatusMessage) {}
        fun updateGroups(groups: List<OutboundGroup>) {}
        fun clearLog() {}
        fun appendLog(message: String) {}
        fun initializeClashMode(modeList: List<String>, currentMode: String) {}
        fun updateClashMode(newMode: String) {}

    }


    private var commandClient: CommandClient? = null
    private val clientHandler = ClientHandler()
    fun connect() {
        disconnect()
        val options = CommandClientOptions()
        options.command = when (connectionType) {
            ConnectionType.Status -> Libbox.CommandStatus
            ConnectionType.Groups -> Libbox.CommandGroup
            ConnectionType.Log -> Libbox.CommandLog
            ConnectionType.ClashMode -> Libbox.CommandClashMode
            ConnectionType.GroupOnly -> Libbox.CommandGroupInfoOnly
        }
        options.statusInterval = 2 * 1000 * 1000 * 1000
        val commandClient = CommandClient(clientHandler, options)
        scope.launch(Dispatchers.IO) {
            android.util.Log.d("CommandClient", "Attempting to connect ${connectionType.name} client...")
            for (i in 1..20) { // 增加重试次数
                delay(100 + i.toLong() * 50)
                try {
                    commandClient.connect()
                    android.util.Log.d("CommandClient", "${connectionType.name} client connected successfully on attempt $i")
                } catch (e: Exception) {
                    android.util.Log.w("CommandClient", "${connectionType.name} client connection attempt $i failed: ${e.message}")
                    continue
                }
                if (!isActive) {
                    android.util.Log.w("CommandClient", "${connectionType.name} client coroutine is not active, disconnecting")
                    runCatching {
                        commandClient.disconnect()
                    }
                    return@launch
                }
                this@CommandClient.commandClient = commandClient
                return@launch
            }
            android.util.Log.e("CommandClient", "${connectionType.name} client failed to connect after 20 attempts")
            runCatching {
                commandClient.disconnect()
            }
        }
    }

    fun disconnect() {
        commandClient?.apply {
            runCatching {
                disconnect()
            }
            Seq.destroyRef(refnum)
        }
        commandClient = null
    }

    private inner class ClientHandler : CommandClientHandler {

        override fun connected() {
            android.util.Log.d("CommandClient", "${connectionType.name} client handler: connected")
            handler.onConnected()
        }

        override fun disconnected(message: String?) {
            android.util.Log.w("CommandClient", "${connectionType.name} client handler: disconnected, message: $message")
            handler.onDisconnected()
        }

        override fun writeGroups(message: OutboundGroupIterator?) {
            if (message == null) {
                return
            }
            val groups = mutableListOf<OutboundGroup>()
            while (message.hasNext()) {
                groups.add(message.next())
            }
            handler.updateGroups(groups)
        }

        override fun clearLog() {
            handler.clearLog()
        }

        override fun writeLog(message: String?) {
            if (message == null) {
                return
            }
            handler.appendLog(message)
        }

        override fun writeStatus(message: StatusMessage?) {
            if (message == null) {
                return
            }
            handler.updateStatus(message)
        }

        override fun initializeClashMode(modeList: StringIterator, currentMode: String) {
            handler.initializeClashMode(modeList.toList(), currentMode)
        }

        override fun updateClashMode(newMode: String) {
            handler.updateClashMode(newMode)
        }

    }

}