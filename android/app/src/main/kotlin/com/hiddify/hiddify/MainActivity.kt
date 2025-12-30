package com.hiddify.hiddify

import android.annotation.SuppressLint
import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.lifecycleScope
import com.hiddify.hiddify.bg.ServiceConnection
import com.hiddify.hiddify.bg.ServiceNotification
import com.hiddify.hiddify.constant.Alert
import com.hiddify.hiddify.constant.ServiceMode
import com.hiddify.hiddify.constant.Status
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.LinkedList


class MainActivity : FlutterFragmentActivity(), ServiceConnection.Callback {
    companion object {
        private const val TAG = "ANDROID/MyActivity"
        lateinit var instance: MainActivity

        const val VPN_PERMISSION_REQUEST_CODE = 1001
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1010
    }

    private val connection = ServiceConnection(this, this)

    val logList = LinkedList<String>()
    var logCallback: ((Boolean) -> Unit)? = null
    val serviceStatus = MutableLiveData(Status.Stopped)
    val serviceAlerts = MutableLiveData<ServiceEvent?>(null)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        reconnect()
        flutterEngine.plugins.add(MethodHandler(lifecycleScope))
        flutterEngine.plugins.add(PlatformSettingsHandler())
        flutterEngine.plugins.add(EventHandler())
        flutterEngine.plugins.add(LogHandler())
        flutterEngine.plugins.add(GroupsChannel(lifecycleScope))
        flutterEngine.plugins.add(ActiveGroupsChannel(lifecycleScope))
        flutterEngine.plugins.add(StatsChannel(lifecycleScope))
    }

    fun reconnect() {
        connection.reconnect()
    }

    fun startService() {
        Log.d(TAG, "startService() called")
        
        // 首先检查通知权限（Android 13+ 需要）
        if (!ServiceNotification.checkPermission()) {
            Log.d(TAG, "Notification permission not granted, requesting...")
            grantNotificationPermission()
            return
        }
        Log.d(TAG, "Notification permission check passed")
        
        lifecycleScope.launch(Dispatchers.IO) {
            if (Settings.rebuildServiceMode()) {
                Log.d(TAG, "Service mode changed, reconnecting...")
                reconnect()
            }
            
            // 如果是 VPN 模式，需要检查 VPN 权限
            if (Settings.serviceMode == ServiceMode.VPN) {
                Log.d(TAG, "VPN mode detected, checking VPN permission...")
                val needsPermission = prepare()
                if (needsPermission) {
                    // prepare() 返回 true 表示需要用户授权，已弹出系统对话框
                    // 等待用户在 onActivityResult 中处理
                    Log.d(TAG, "VPN permission required, waiting for user authorization")
                    return@launch
                }
                // prepare() 返回 false 表示已有权限，可以继续
                Log.d(TAG, "VPN permission already granted")
            } else {
                Log.d(TAG, "Non-VPN mode: ${Settings.serviceMode}")
            }

            // 所有权限检查通过，启动服务
            Log.d(TAG, "All permissions granted, starting VPN service")
            
            // 如果是VPN模式，再次验证权限状态（双重检查）
            if (Settings.serviceMode == ServiceMode.VPN) {
                val finalCheck = withContext(Dispatchers.Main) {
                    val intent = VpnService.prepare(this@MainActivity)
                    intent == null // 返回true表示有权限
                }
                if (!finalCheck) {
                    Log.w(TAG, "VPN permission check failed at final stage, requesting again")
                    val needsPermission = prepare()
                    if (needsPermission) {
                        Log.d(TAG, "VPN permission required again, waiting for user authorization")
                        return@launch
                    }
                }
            }
            
            val intent = Intent(Application.application, Settings.serviceClass())
            withContext(Dispatchers.Main) {
                try {
                    ContextCompat.startForegroundService(Application.application, intent)
                    Log.d(TAG, "✅ VPN service start intent sent successfully")
                } catch (e: SecurityException) {
                    Log.e(TAG, "❌ SecurityException starting VPN service: ${e.message}", e)
                    onServiceAlert(Alert.StartService, "Security error: ${e.message}. Please check VPN permission in system settings.")
                } catch (e: IllegalStateException) {
                    Log.e(TAG, "❌ IllegalStateException starting VPN service: ${e.message}", e)
                    // IllegalStateException通常是因为前台服务启动限制
                    onServiceAlert(Alert.StartService, "Service error: ${e.message}. Please try again.")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to start VPN service: ${e.message}", e)
                    onServiceAlert(Alert.StartService, "Failed to start service: ${e.message}")
                }
            }
        }
    }

    private suspend fun prepare() = withContext(Dispatchers.Main) {
        try {
            // 检查VPN权限状态
            val intent = VpnService.prepare(this@MainActivity)
            if (intent != null) {
                // 需要用户授权，弹出系统对话框（会要求输入密码/指纹）
                Log.d(TAG, "VPN permission required, starting permission request activity")
                try {
                    // 使用 startActivityForResult（虽然已弃用，但为了兼容性保留）
                    // 在Android 11+上，这仍然可以正常工作
                    startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
                    Log.d(TAG, "VPN permission request activity started successfully")
                } catch (e: SecurityException) {
                    Log.e(TAG, "SecurityException starting VPN permission request: ${e.message}", e)
                    onServiceAlert(Alert.RequestVPNPermission, "Security error: Cannot request VPN permission. ${e.message}")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start VPN permission request activity: ${e.message}", e)
                    onServiceAlert(Alert.RequestVPNPermission, "Cannot open VPN permission dialog: ${e.message}")
                }
                true  // 返回 true 表示需要权限，会阻止服务启动，等待用户授权
            } else {
                // 已有权限，可以继续
                Log.d(TAG, "VPN permission already granted, can proceed")
                false
            }
        } catch (e: SecurityException) {
            // 如果 prepare() 抛出安全异常，说明无法请求权限
            Log.e(TAG, "SecurityException preparing VPN service: ${e.message}", e)
            onServiceAlert(Alert.RequestVPNPermission, "Security error: ${e.message}")
            true  // 返回 true 阻止服务启动
        } catch (e: Exception) {
            // 如果 prepare() 抛出其他异常，说明无法请求权限，应该阻止服务启动
            Log.e(TAG, "Failed to prepare VPN service: ${e.message}", e)
            onServiceAlert(Alert.RequestVPNPermission, "Failed to prepare VPN: ${e.message}")
            true  // 返回 true 阻止服务启动，因为无法确定权限状态
        }
    }

    override fun onServiceStatusChanged(status: Status) {
        Log.d(TAG, "onServiceStatusChanged called with status: $status")
        // 确保在主线程更新状态
        if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) {
            serviceStatus.postValue(status)
            Log.d(TAG, "Service status updated to: $status (on main thread), LiveData value: ${serviceStatus.value}")
        } else {
            runOnUiThread {
                serviceStatus.postValue(status)
                Log.d(TAG, "Service status updated to: $status (switched to main thread), LiveData value: ${serviceStatus.value}")
            }
        }
    }

    override fun onServiceAlert(type: Alert, message: String?) {
        serviceAlerts.postValue(ServiceEvent(Status.Stopped, type, message))
    }

    override fun onServiceWriteLog(message: String?) {
        if (logList.size > 300) {
            logList.removeFirst()
        }
        logList.addLast(message)
        logCallback?.invoke(false)
    }

    override fun onServiceResetLogs(messages: MutableList<String>) {
        logList.clear()
        logList.addAll(messages)
        logCallback?.invoke(true)
    }

    override fun onDestroy() {
        connection.disconnect()
        super.onDestroy()
    }

    @SuppressLint("NewApi")
    private fun grantNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "Notification permission granted, continuing with service start")
                // 通知权限已授予，继续启动服务流程
                startService()
            } else {
                Log.w(TAG, "Notification permission denied")
                onServiceAlert(Alert.RequestNotificationPermission, null)
            }
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                // 用户已授权 VPN 权限，可以启动服务
                Log.d(TAG, "✅ VPN permission granted by user (resultCode: $resultCode), starting service")
                // 重新检查所有权限并启动服务
                // 延迟一小段时间确保权限状态已更新
                lifecycleScope.launch(Dispatchers.Main) {
                    delay(100) // 短暂延迟确保系统权限状态已更新
                    startService()
                }
            } else {
                // 用户拒绝或取消授权
                Log.w(TAG, "❌ VPN permission denied or cancelled by user (resultCode: $resultCode)")
                onServiceAlert(Alert.RequestVPNPermission, "VPN permission was denied. Please grant VPN permission in system settings to use this feature.")
            }
        } else if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            // 虽然通知权限通常通过 onRequestPermissionsResult 处理，
            // 但保留此逻辑以兼容某些特殊情况
            if (resultCode == RESULT_OK) {
                Log.d(TAG, "Notification permission granted via activity result, starting service")
                lifecycleScope.launch(Dispatchers.Main) {
                    delay(100)
                    startService()
                }
            } else {
                Log.w(TAG, "Notification permission denied via activity result (resultCode: $resultCode)")
                onServiceAlert(Alert.RequestNotificationPermission, null)
            }
        }
    }
}
