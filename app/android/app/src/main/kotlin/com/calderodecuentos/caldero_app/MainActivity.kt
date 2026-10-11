package com.calderodecuentos.caldero_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "caldero/background_audio")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    askForNotifications()
                    StoryAudioService.onAction = { action -> runOnUiThread { channel.invokeMethod("action", action) } }
                    StoryAudioService.begin(
                        this,
                        call.argument<String>("title") ?: "",
                        call.argument<Boolean>("playing") ?: false
                    )
                    result.success(null)
                }
                "setPlaying" -> {
                    StoryAudioService.setPlaying(call.argument<Boolean>("playing") ?: false)
                    result.success(null)
                }
                "stop" -> {
                    StoryAudioService.onAction = null
                    StoryAudioService.end(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Android 13+ no enseña la notificación (ni sus botones en la pantalla de bloqueo) sin permiso. Se pide una sola
     * vez; el cuento suena igual si la familia dice que no.
     */
    private fun askForNotifications() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        val prefs = getSharedPreferences("caldero_background_audio", MODE_PRIVATE)
        if (prefs.getBoolean("asked_notifications", false)) return
        prefs.edit().putBoolean("asked_notifications", true).apply()
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4107)
    }

    override fun onDestroy() {
        // Sin pantalla de Flutter no hay quien dirija el cuento: se quita el servicio.
        StoryAudioService.onAction = null
        StoryAudioService.end(this)
        super.onDestroy()
    }
}
