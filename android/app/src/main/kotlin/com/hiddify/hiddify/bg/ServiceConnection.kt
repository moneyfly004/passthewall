package com.hiddify.hiddify.bg

import com.hiddify.hiddify.IService
import com.hiddify.hiddify.IServiceCallback
import com.hiddify.hiddify.Settings
import com.hiddify.hiddify.constant.Action
import com.hiddify.hiddify.constant.Alert
import com.hiddify.hiddify.constant.Status
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.os.RemoteException
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

class ServiceConnection(
    private val context: Context,
    callback: Callback,
    private val register: Boolean = true,
) : ServiceConnection {

    companion object {
        private const val TAG = "ServiceConnection"
    }

    private val serviceCallback = ServiceCallback(callback)
    private val originalCallback = callback
    private var service: IService? = null

    val status: Status get() = service?.let { 
        try {
            Status.values()[it.status]
        } catch (e: Exception) {
            Status.Stopped
        }
    } ?: Status.Stopped

    fun connect() {
        val intent = runBlocking {
            withContext(Dispatchers.IO) {
                Intent(context, Settings.serviceClass()).setAction(Action.SERVICE)
            }
        }
        context.bindService(intent, this, AppCompatActivity.BIND_AUTO_CREATE)
    }

    fun disconnect() {
        try {
            context.unbindService(this)
        } catch (_: IllegalArgumentException) {
        }
    }

    fun reconnect() {
        try {
            context.unbindService(this)
        } catch (_: IllegalArgumentException) {
        }
        val intent = runBlocking {
            withContext(Dispatchers.IO) {
                Intent(context, Settings.serviceClass()).setAction(Action.SERVICE)
            }
        }
        context.bindService(intent, this, AppCompatActivity.BIND_AUTO_CREATE)
    }

    override fun onServiceConnected(name: ComponentName, binder: IBinder) {
        val service = IService.Stub.asInterface(binder)
        this.service = service
        try {
            if (register) {
                service.registerCallback(serviceCallback)
                Log.d(TAG, "Callback registered successfully")
            }
            val currentStatus = service.status
            val statusEnum = Status.values()[currentStatus]
            Log.d(TAG, "Service connected, current status: $statusEnum (ordinal: $currentStatus)")
            // 确保在主线程调用回调
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                originalCallback.onServiceStatusChanged(statusEnum)
            }
        } catch (e: RemoteException) {
            Log.e(TAG, "initialize service connection", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error in onServiceConnected: ${e.message}", e)
        }
    }

    override fun onServiceDisconnected(name: ComponentName?) {
        try {
            service?.unregisterCallback(serviceCallback)
        } catch (e: RemoteException) {
            Log.e(TAG, "cleanup service connection", e)
        }
    }

    override fun onBindingDied(name: ComponentName?) {
        reconnect()
    }

    interface Callback {
        fun onServiceStatusChanged(status: Status)
        fun onServiceAlert(type: Alert, message: String?) {}
        fun onServiceWriteLog(message: String?) {}
        fun onServiceResetLogs(messages: MutableList<String>) {}
    }

    class ServiceCallback(private val callback: Callback) : IServiceCallback.Stub() {
        override fun onServiceStatusChanged(status: Int) {
            callback.onServiceStatusChanged(Status.values()[status])
        }

        override fun onServiceAlert(type: Int, message: String?) {
            callback.onServiceAlert(Alert.values()[type], message)
        }

        override fun onServiceWriteLog(message: String?) = callback.onServiceWriteLog(message)

        override fun onServiceResetLogs(messages: MutableList<String>) =
            callback.onServiceResetLogs(messages)
    }
}
