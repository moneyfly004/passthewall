package com.hiddify.hiddify

import android.util.Log
import com.google.gson.Gson
import com.hiddify.hiddify.utils.ParsedOutboundGroup
import fi.iki.elonen.NanoHTTPD
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.Libbox

class ProxyHttpServer(private val getBoxService: () -> BoxService?) : NanoHTTPD("127.0.0.1", 19080) {
    companion object {
        const val TAG = "A/ProxyHttpServer"
        val gson = Gson()
    }

    override fun serve(session: IHTTPSession): Response {
        Log.d(TAG, "收到请求: ${session.method} ${session.uri}")
        
        return try {
            when (session.uri) {
                "/api/groups" -> handleGetGroups()
                "/api/active_groups" -> handleGetActiveGroups()
                "/api/select" -> handleSelectOutbound(session)
                "/api/urltest" -> handleUrlTest(session)
                else -> newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Not Found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "处理请求失败: ${e.message}", e)
            newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, e.message ?: "Internal Error")
        }
    }

    private fun handleGetGroups(): Response {
        try {
            Log.d(TAG, "获取节点组列表...")
            val boxService = getBoxService()
            if (boxService == null) {
                Log.w(TAG, "BoxService 未就绪")
                return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_PLAINTEXT, "Service not ready")
            }
            
            // 由于 Android SELinux 限制，CommandServer 的 Unix socket 无法创建
            // 因此无法通过 Libbox.newStandaloneCommandClient() 获取节点信息
            // 这是已知的架构限制
            val errorInfo = mapOf(
                "error" to "CommandServer unavailable",
                "reason" to "Unix socket blocked by SELinux on this device",
                "vpn_status" to "VPN功能正常，使用默认节点"
            )
            
            Log.w(TAG, "❌ CommandServer 不可用（SELinux限制）")
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, "application/json", gson.toJson(errorInfo))
        } catch (e: Exception) {
            Log.e(TAG, "❌ 获取节点组失败: ${e.message}", e)
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, e.message ?: "Error")
        }
    }

    private fun handleGetActiveGroups(): Response {
        try {
            Log.d(TAG, "获取活动节点组...")
            
            val errorInfo = mapOf(
                "error" to "CommandServer unavailable",
                "reason" to "Unix socket blocked by SELinux on this device"
            )
            
            Log.w(TAG, "❌ CommandServer 不可用（SELinux限制）")
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, "application/json", gson.toJson(errorInfo))
        } catch (e: Exception) {
            Log.e(TAG, "❌ 获取活动节点组失败: ${e.message}", e)
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, e.message ?: "Error")
        }
    }

    private fun handleSelectOutbound(session: IHTTPSession): Response {
        try {
            Log.w(TAG, "❌ 节点切换功能不可用（CommandServer SELinux限制）")
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_PLAINTEXT, "CommandServer unavailable")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 节点切换失败: ${e.message}", e)
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, e.message ?: "Error")
        }
    }

    private fun handleUrlTest(session: IHTTPSession): Response {
        try {
            Log.w(TAG, "❌ 延迟测试功能不可用（CommandServer SELinux限制）")
            return newFixedLengthResponse(Response.Status.SERVICE_UNAVAILABLE, MIME_PLAINTEXT, "CommandServer unavailable")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 延迟测试失败: ${e.message}", e)
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, e.message ?: "Error")
        }
    }
    
    fun stopServer() {
        try {
            stop()
            Log.d(TAG, "HTTP 服务器已停止")
        } catch (e: Exception) {
            Log.w(TAG, "停止 HTTP 服务器失败: ${e.message}")
        }
    }
}

