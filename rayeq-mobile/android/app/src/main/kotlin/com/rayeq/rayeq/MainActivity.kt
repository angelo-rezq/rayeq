package com.rayeq.rayeq

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import javax.net.ssl.HttpsURLConnection
import java.net.URL
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "rayeq/app_updates"
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "installedBuild" -> result.success(buildCode(packageManager.getPackageInfo(packageName, 0)))
                "downloadUpdate" -> {
                    val url = call.argument<String>("url") ?: ""
                    val hash = call.argument<String>("sha256") ?: ""
                    val build = call.argument<Number>("build")?.toLong() ?: 0L
                    Thread {
                        try {
                            val file = download(url, hash, build)
                            runOnUiThread { result.success(file.absolutePath) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("UPDATE_DOWNLOAD_FAILED", "Download or verification failed", null) }
                        }
                    }.start()
                }
                "installUpdate" -> {
                    val path = call.argument<String>("path") ?: ""
                    val hash = call.argument<String>("sha256") ?: ""
                    val build = call.argument<Number>("build")?.toLong() ?: 0L
                    Thread {
                        try {
                            val file = File(path)
                            require(file.canonicalFile.parentFile == File(cacheDir, "updates").canonicalFile)
                            validate(file, hash, build)
                            runOnUiThread {
                                try {
                                    if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                                        result.success("permission_required")
                                    } else {
                                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                                        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                                        startActivity(intent)
                                        result.success("installer_opened")
                                    }
                                } catch (_: Exception) { result.error("UPDATE_INSTALL_FAILED", "Installer could not open", null) }
                            }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("UPDATE_VERIFICATION_FAILED", "Package verification failed", null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun download(address: String, expected: String, build: Long): File {
        require(expected.matches(Regex("^[a-fA-F0-9]{64}$")) && build > 0)
        val uri = Uri.parse(address)
        require(uri.scheme == "https" && uri.host == "rayeq-platform.onrender.com" && uri.userInfo == null && (uri.port == -1 || uri.port == 443))
        val folder = File(cacheDir, "updates").apply { mkdirs() }
        folder.listFiles()?.filter { it.name.endsWith(".part.apk") }?.forEach { it.delete() }
        val partial = File(folder, "rayeq-$build.part.apk")
        val finalFile = File(folder, "rayeq-$build.apk")
        val connection = URL(address).openConnection() as HttpsURLConnection
        connection.connectTimeout = 20000
        connection.readTimeout = 45000
        connection.instanceFollowRedirects = false
        try {
            require(connection.responseCode == 200)
            require(connection.contentLengthLong <= 100L * 1024L * 1024L)
            var count = 0L
            connection.inputStream.use { input -> partial.outputStream().use { output ->
                val buffer = ByteArray(65536)
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    count += n
                    require(count <= 100L * 1024L * 1024L)
                    output.write(buffer, 0, n)
                }
            } }
            validate(partial, expected, build)
            if (finalFile.exists()) finalFile.delete()
            require(partial.renameTo(finalFile))
            return finalFile
        } finally {
            connection.disconnect()
            partial.delete()
        }
    }
    private fun digest(file: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input -> val buf = ByteArray(65536); while (true) { val n = input.read(buf); if (n < 0) break; md.update(buf, 0, n) } }
        return md.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
    }
    @Suppress("DEPRECATION")
    private fun certs(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return (signatures ?: emptyArray()).map { sig -> MessageDigest.getInstance("SHA-256").digest(sig.toByteArray()).joinToString("") { "%02x".format(it.toInt() and 255) } }.toSet()
    }
    private fun validate(file: File, expected: String, build: Long) {
        require(file.isFile && digest(file).equals(expected, ignoreCase = true))
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else @Suppress("DEPRECATION") PackageManager.GET_SIGNATURES
        val archive = packageManager.getPackageArchiveInfo(file.absolutePath, flags) ?: error("Invalid APK")
        val installed = packageManager.getPackageInfo(packageName, flags)
        require(archive.packageName == packageName && buildCode(archive) == build && build > buildCode(installed))
        val own = certs(installed)
        require(own.isNotEmpty() && certs(archive) == own)
    }
    @Suppress("DEPRECATION")
    private fun buildCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
}
