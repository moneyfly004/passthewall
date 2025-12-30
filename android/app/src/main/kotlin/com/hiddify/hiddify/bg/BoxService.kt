package com.hiddify.hiddify.bg

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import androidx.lifecycle.MutableLiveData
import com.hiddify.hiddify.Application
import com.hiddify.hiddify.R
import com.hiddify.hiddify.Settings
import com.hiddify.hiddify.constant.Action
import com.hiddify.hiddify.constant.Alert
import com.hiddify.hiddify.constant.Status
import go.Seq
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.mobile.Mobile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.io.File

class BoxService(
        private val service: Service,
        private val platformInterface: PlatformInterface
) : CommandServerHandler {

    companion object {
        private const val TAG = "A/BoxService"

        private var initializeOnce = false
        private lateinit var workingDir: File
        private fun initialize() {
            if (initializeOnce) {
                Log.d(TAG, "已经初始化过，跳过")
                return
            }
            
            Log.d(TAG, "开始初始化目录...")
            val baseDir = Application.application.filesDir
            baseDir.mkdirs()
            
            workingDir = File(baseDir, "box_working")
            if (!workingDir.exists()) {
                val created = workingDir.mkdirs()
                Log.d(TAG, "创建 working 目录: $created")
            }
            
            workingDir.setReadable(true, false)
            workingDir.setWritable(true, false)
            workingDir.setExecutable(true, false)
            
            val tempDir = Application.application.cacheDir
            tempDir.mkdirs()
            
            Log.d(TAG, "=== 目录配置 ===")
            Log.d(TAG, "base dir: ${baseDir.absolutePath}")
            Log.d(TAG, "working dir: ${workingDir.absolutePath}")
            Log.d(TAG, "temp dir: ${tempDir.absolutePath}")
            Log.d(TAG, "working dir exists: ${workingDir.exists()}")
            Log.d(TAG, "working dir canRead: ${workingDir.canRead()}")
            Log.d(TAG, "working dir canWrite: ${workingDir.canWrite()}")
            Log.d(TAG, "working dir canExecute: ${workingDir.canExecute()}")
            
            Log.d(TAG, "设置系统属性...")
            System.setProperty("sing-box.base-dir", baseDir.absolutePath)
            System.setProperty("sing-box.working-dir", workingDir.absolutePath)
            System.setProperty("sing-box.cache-dir", tempDir.absolutePath)
            System.setProperty("user.dir", workingDir.absolutePath)
            
            Log.d(TAG, "调用 Mobile.setup()...")
            try {
                Mobile.setup()
                Log.d(TAG, "✅ Mobile.setup() 完成")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Mobile.setup() 失败: ${e.message}", e)
            }
            
            Log.d(TAG, "设置 stderr 重定向...")
            try {
                Libbox.redirectStderr(File(workingDir, "stderr.log").path)
                Log.d(TAG, "stderr 重定向完成")
            } catch (e: Exception) {
                Log.w(TAG, "redirectStderr failed: ${e.message}")
            }
            
            initializeOnce = true
            Log.d(TAG, "初始化完成")
        }

        fun parseConfig(path: String, tempPath: String, debug: Boolean): String {
            return try {
                Mobile.parse(path, tempPath, debug)
                ""
            } catch (e: Exception) {
                Log.w(TAG, e)
                e.message ?: "invalid config"
            }
        }

        fun buildConfig(path: String, options: String): String {
            return Mobile.buildConfig(path, options)
        }

        fun start() {
            val intent = runBlocking {
                withContext(Dispatchers.IO) {
                    Intent(Application.application, Settings.serviceClass())
                }
            }
            ContextCompat.startForegroundService(Application.application, intent)
        }

        fun stop() {
            Application.application.sendBroadcast(
                    Intent(Action.SERVICE_CLOSE).setPackage(
                            Application.application.packageName
                    )
            )
        }

        fun reload() {
            Application.application.sendBroadcast(
                    Intent(Action.SERVICE_RELOAD).setPackage(
                            Application.application.packageName
                    )
            )
        }
    }

    var fileDescriptor: ParcelFileDescriptor? = null

    private val status = MutableLiveData(Status.Stopped)
    private val binder = ServiceBinder(status)
    private val notification = ServiceNotification(status, service)
    private var boxService: BoxService? = null
    private var commandServer: CommandServer? = null
    private var receiverRegistered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Action.SERVICE_CLOSE -> {
                    stopService()
                }

                Action.SERVICE_RELOAD -> {
                    serviceReload()
                }

                PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        serviceUpdateIdleMode()
                    }
                }
            }
        }
    }

    private fun startCommandServer() {
        Log.d(TAG, "尝试启动 CommandServer...")
        try {
            val commandServer = CommandServer(this, 0)
            commandServer.start()
            this.commandServer = commandServer
            Log.d(TAG, "✅ CommandServer 启动成功")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ CommandServer 启动失败: ${e.message}")
            Log.i(TAG, "📝 说明：某些设备（如华为/vivo/荣耀）的 SELinux 策略禁止创建 Unix socket")
            Log.i(TAG, "✅ VPN 核心功能完全正常，将使用默认最优节点")
            Log.i(TAG, "⚠️ 节点切换功能暂时不可用")
            this.commandServer = null
        }
    }

    private var activeProfileName = ""
    private suspend fun startService(delayStart: Boolean = false) {
        try {
            Log.d(TAG, "starting service")
            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
            }

            val selectedConfigPath = Settings.activeConfigPath
            if (selectedConfigPath.isBlank()) {
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            activeProfileName = Settings.activeProfileName

            val configOptions = Settings.configOptions
            if (configOptions.isBlank()) {
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            val content = try {
                Mobile.buildConfig(selectedConfigPath, configOptions)
            } catch (e: Exception) {
                Log.w(TAG, e)
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            if (Settings.debugMode) {
                File(workingDir, "current-config.json").writeText(content)
            }

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
                binder.broadcast {
                    it.onServiceResetLogs(listOf())
                }
            }

            DefaultNetworkMonitor.start()
            Libbox.registerLocalDNSTransport(LocalResolver)
            Libbox.setMemoryLimit(!Settings.disableMemoryLimit)

            val newService = try {
                Libbox.newService(content, platformInterface)
            } catch (e: Exception) {
                stopAndAlert(Alert.CreateService, e.message)
                return
            }

            if (delayStart) {
                delay(1000L)
            }

            newService.start()
            boxService = newService
            commandServer?.setService(boxService)
            status.postValue(Status.Started)

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_started)
            }
            notification.start()
        } catch (e: Exception) {
            stopAndAlert(Alert.StartService, e.message)
            return
        }
    }

    override fun serviceReload() {
        notification.close()
        status.postValue(Status.Starting)
        val pfd = fileDescriptor
        if (pfd != null) {
            pfd.close()
            fileDescriptor = null
        }
        commandServer?.setService(null)
        boxService?.apply {
            runCatching {
                close()
            }.onFailure {
                writeLog("service: error when closing: $it")
            }
            Seq.destroyRef(refnum)
        }
        boxService = null
        runBlocking {
            startService(true)
        }
    }

    override fun getSystemProxyStatus(): SystemProxyStatus {
        val status = SystemProxyStatus()
        if (service is VPNService) {
            status.available = service.systemProxyAvailable
            status.enabled = service.systemProxyEnabled
        }
        return status
    }

    override fun setSystemProxyEnabled(isEnabled: Boolean) {
        serviceReload()
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun serviceUpdateIdleMode() {
        if (Application.powerManager.isDeviceIdleMode) {
            boxService?.pause()
        } else {
            boxService?.wake()
        }
    }

    private fun stopService() {
        if (status.value != Status.Started) return
        status.value = Status.Stopping
        if (receiverRegistered) {
            service.unregisterReceiver(receiver)
            receiverRegistered = false
        }
        notification.close()
        GlobalScope.launch(Dispatchers.IO) {
            val pfd = fileDescriptor
            if (pfd != null) {
                pfd.close()
                fileDescriptor = null
            }
            commandServer?.setService(null)
            boxService?.apply {
                runCatching {
                    close()
                }.onFailure {
                    writeLog("service: error when closing: $it")
                }
                Seq.destroyRef(refnum)
            }
            boxService = null
            Libbox.registerLocalDNSTransport(null)
            DefaultNetworkMonitor.stop()

            commandServer?.apply {
                close()
                Seq.destroyRef(refnum)
            }
            commandServer = null
            Settings.startedByUser = false
            withContext(Dispatchers.Main) {
                status.value = Status.Stopped
                service.stopSelf()
            }
        }
    }
    override fun postServiceClose() {
        // Not used on Android
    }

    private suspend fun stopAndAlert(type: Alert, message: String? = null) {
        Settings.startedByUser = false
        withContext(Dispatchers.Main) {
            if (receiverRegistered) {
                service.unregisterReceiver(receiver)
                receiverRegistered = false
            }
            notification.close()
            binder.broadcast { callback ->
                callback.onServiceAlert(type.ordinal, message)
            }
            status.value = Status.Stopped
        }
    }

    fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (status.value != Status.Stopped) return Service.START_NOT_STICKY
        status.value = Status.Starting

        if (!receiverRegistered) {
            ContextCompat.registerReceiver(service, receiver, IntentFilter().apply {
                addAction(Action.SERVICE_CLOSE)
                addAction(Action.SERVICE_RELOAD)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
                }
            }, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        }

        GlobalScope.launch(Dispatchers.IO) {
            try {
                Settings.startedByUser = true
                Log.d(TAG, "开始初始化...")
                
                initialize()
                Log.d(TAG, "初始化完成")
                
                Log.d(TAG, "开始启动 CommandServer...")
                startCommandServer()
                Log.d(TAG, "CommandServer 启动完成")
                
                Log.d(TAG, "开始启动服务...")
                startService()
                Log.d(TAG, "服务启动完成")
            } catch (e: Exception) {
                Log.e(TAG, "服务启动失败: ${e.message}", e)
                stopAndAlert(Alert.StartCommandServer, e.message)
            }
        }
        return Service.START_NOT_STICKY
    }

    fun onBind(intent: Intent): IBinder {
        return binder
    }

    fun onDestroy() {
        binder.close()
    }

    fun onRevoke() {
        stopService()
    }

    fun writeLog(message: String) {
        binder.broadcast {
            it.onServiceWriteLog(message)
        }
    }

}