package com.hiddify.hiddify

import android.util.Log
import com.hiddify.hiddify.bg.BoxService
import com.hiddify.hiddify.constant.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.mobile.Mobile
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

class MethodHandler(private val scope: CoroutineScope) : FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "com.hiddify.app/method"

        enum class Trigger(val method: String) {
            Setup("setup"),
            ParseConfig("parse_config"),
            changeHiddifyOptions("change_hiddify_options"),
            GenerateConfig("generate_config"),
            Start("start"),
            Stop("stop"),
            Restart("restart"),
            SelectOutbound("select_outbound"),
            UrlTest("url_test"),
            ClearLogs("clear_logs"),
            GenerateWarpConfig("generate_warp_config"),
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            channelName,
        )
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Trigger.Setup.method -> {
                GlobalScope.launch {
                    result.runCatching {
                           val baseDir = Application.application.filesDir                
                            baseDir.mkdirs()
                            val workingDir = File(baseDir, "box_working")
                            workingDir.mkdirs()
                            
                            workingDir.setReadable(true, false)
                            workingDir.setWritable(true, false)
                            workingDir.setExecutable(true, false)
                            
                            val tempDir = Application.application.cacheDir
                            tempDir.mkdirs()
                            Log.d(TAG, "base dir: ${baseDir.path}")
                            Log.d(TAG, "working dir: ${workingDir.path}")
                            Log.d(TAG, "temp dir: ${tempDir.path}")
                            
                            System.setProperty("sing-box.base-dir", baseDir.absolutePath)
                            System.setProperty("sing-box.working-dir", workingDir.absolutePath)
                            System.setProperty("sing-box.cache-dir", tempDir.absolutePath)
                            System.setProperty("user.dir", workingDir.absolutePath)
                            
                            try {
                                Mobile.setup()
                            } catch (e: Exception) {
                                Log.w(TAG, "Mobile.setup() failed: ${e.message}")
                            }
                            try {
                                Libbox.redirectStderr(File(workingDir, "stderr2.log").path)
                            } catch (e: Exception) {
                                Log.w(TAG, "redirectStderr failed: ${e.message}")
                            }

                            success("")
                    }
                }
            }

            Trigger.ParseConfig.method -> {
                scope.launch(Dispatchers.IO) {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val path = args["path"] as String
                        val tempPath = args["tempPath"] as String
                        val debug = args["debug"] as Boolean
                        val msg = BoxService.parseConfig(path, tempPath, debug)
                        success(msg)
                    }
                }
            }

            Trigger.changeHiddifyOptions.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as String
                        Settings.configOptions = args
                        success(true)
                    }
                }
            }

            Trigger.GenerateConfig.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val path = args["path"] as String
                        val options = Settings.configOptions
                        if (options.isBlank() || path.isBlank()) {
                            error("blank properties")
                        }
                        val config = BoxService.buildConfig(path, options)
                        success(config)
                    }
                }
            }

            Trigger.Start.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        Settings.activeConfigPath = args["path"] as String? ?: ""
                        Settings.activeProfileName = args["name"] as String? ?: ""
                        val mainActivity = MainActivity.instance
                        val started = mainActivity.serviceStatus.value == Status.Started
                        if (started) {
                            Log.w(TAG, "service is already running")
                            return@launch success(true)
                        }
                        mainActivity.startService()
                        success(true)
                    }
                }
            }

            Trigger.Stop.method -> {
                scope.launch {
                    result.runCatching {
                        val mainActivity = MainActivity.instance
                        val started = mainActivity.serviceStatus.value == Status.Started
                        if (!started) {
                            Log.w(TAG, "service is not running")
                            return@launch success(true)
                        }
                        BoxService.stop()
                        success(true)
                    }
                }
            }

            Trigger.Restart.method -> {
                scope.launch(Dispatchers.IO) {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        Settings.activeConfigPath = args["path"] as String? ?: ""
                        Settings.activeProfileName = args["name"] as String? ?: ""
                        val mainActivity = MainActivity.instance
                        val started = mainActivity.serviceStatus.value == Status.Started
                        if (!started) return@launch success(true)
                        val restart = Settings.rebuildServiceMode()
                        if (restart) {
                            mainActivity.reconnect()
                            BoxService.stop()
                            delay(1000L)
                            mainActivity.startService()
                            return@launch success(true)
                        }
                        runCatching {
                            Libbox.newStandaloneCommandClient().serviceReload()
                            success(true)
                        }.onFailure {
                            error(it)
                        }
                    }
                }
            }

            Trigger.SelectOutbound.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        Log.d(TAG, "使用 StandaloneCommandClient 切换节点...")
                        try {
                            val client = Libbox.newStandaloneCommandClient()
                            client.selectOutbound(
                                args["groupTag"] as String,
                                args["outboundTag"] as String
                            )
                            Log.d(TAG, "✅ 节点切换成功")
                            success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ 节点切换失败: ${e.message}")
                            error(e)
                        }
                    }
                }
            }

            Trigger.UrlTest.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        Log.d(TAG, "使用 StandaloneCommandClient 测试延迟...")
                        try {
                            val client = Libbox.newStandaloneCommandClient()
                            client.urlTest(args["groupTag"] as String)
                            Log.d(TAG, "✅ 延迟测试成功")
                            success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ 延迟测试失败: ${e.message}")
                            error(e)
                        }
                    }
                }
            }

            Trigger.ClearLogs.method -> {
                scope.launch {
                    result.runCatching {
                        MainActivity.instance.onServiceResetLogs(mutableListOf())
                        success(true)
                    }
                }
            }

            Trigger.GenerateWarpConfig.method -> {
                scope.launch(Dispatchers.IO) {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val warpConfig = Mobile.generateWarpConfig(
                            args["license-key"] as String,
                            args["previous-account-id"] as String,
                            args["previous-access-token"] as String,
                        )
                        success(warpConfig)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }
}