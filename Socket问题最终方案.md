# Socket 权限问题 - 最终技术方案

## 🔍 问题本质

经过深入研究，发现：

### libbox 的架构限制
```
BoxService (Go) ←→ CommandServer (Unix Socket) ←→ CommandClient (Kotlin)
```

**所有通信都依赖 Unix socket：**
- 节点列表获取
- 节点切换
- 延迟测试
- 状态监控

### SELinux 阻止
vivo/华为/荣耀手机的 SELinux 策略：
- 禁止读取 `/proc/net/somaxconn`
- 禁止在应用目录创建 Unix socket
- 即使队列大小为 0 也失败

## 🎯 可行的解决方案

### 方案 1：修改 libbox 源代码（最彻底）

**需要：**
1. Go 开发环境
2. libbox 源代码
3. 将 Unix socket 改为 Android Binder IPC

**步骤：**
```bash
git clone https://github.com/hiddify/hiddify-next-core
cd hiddify-next-core
# 修改 Go 代码，使用 gomobile 的 Binder 机制
make android
```

**优点：** 彻底解决，完美支持所有功能
**缺点：** 需要 Go 环境和深入修改

### 方案 2：使用 HTTP API 替代 Socket（推荐）

修改 BoxService 暴露 HTTP 接口：

```kotlin
// 在 BoxService 中添加
private var httpServer: NanoHTTPD? = null

fun startHttpServer() {
    httpServer = object : NanoHTTPD("127.0.0.1", 19080) {
        override fun serve(session: IHTTPSession): Response {
            when (session.uri) {
                "/api/groups" -> {
                    val groups = boxService?.queryOutboundGroups()
                    return newFixedLengthResponse(gson.toJson(groups))
                }
                "/api/select" -> {
                    val params = session.parameters
                    boxService?.selectOutbound(params["group"], params["outbound"])
                    return newFixedLengthResponse("OK")
                }
            }
        }
    }
    httpServer?.start()
}
```

然后 Flutter 层通过 HTTP 请求获取节点。

**优点：** 不需要 socket，HTTP 没有 SELinux 限制
**缺点：** 需要添加 HTTP 服务器库

### 方案 3：使用 SharedPreferences 传递（简单）

BoxService 定期将节点列表写入 SharedPreferences，Flutter 层读取：

```kotlin
// BoxService 中
fun updateGroupsCache() {
    val prefs = context.getSharedPreferences("proxy_groups", Context.MODE_PRIVATE)
    val groups = boxService?.queryOutboundGroups()
    prefs.edit().putString("groups_json", gson.toJson(groups)).apply()
}

// 每秒更新一次
handler.postDelayed({ updateGroupsCache() }, 1000)
```

**优点：** 简单，不需要额外依赖
**缺点：** 实时性差，轮询消耗资源

### 方案 4：使用 ContentProvider（Android 标准）

创建 ContentProvider 暴露节点数据：

```kotlin
class ProxyGroupsProvider : ContentProvider() {
    override fun query(...): Cursor? {
        val groups = BoxService.getBoxService()?.queryOutboundGroups()
        // 返回 Cursor
    }
}
```

**优点：** Android 标准机制，无 SELinux 限制
**缺点：** 需要实现 Cursor 转换

## 🚀 我推荐的实现方案

**方案 2（HTTP API）** 最实用：

1. 添加轻量级 HTTP 服务器（NanoHTTPD）
2. 在 BoxService 启动时开启 HTTP 服务
3. Flutter 层通过 `http://127.0.0.1:19080/api/groups` 获取节点
4. 通过 `http://127.0.0.1:19080/api/select?group=X&outbound=Y` 切换节点

## ❓ 您的决定

请告诉我您想：
1. **实现 HTTP API 方案**（我可以立即开始，预计 30 分钟）
2. **实现 SharedPreferences 方案**（最简单，预计 15 分钟）
3. **接受当前版本**（VPN 可用，无节点切换）
4. **测试原始代码**（看看原始代码是否也有问题）

请选择一个方案，我立即执行！

