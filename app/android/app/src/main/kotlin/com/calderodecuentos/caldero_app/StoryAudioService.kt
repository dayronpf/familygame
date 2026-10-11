package com.calderodecuentos.caldero_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Mantiene vivo el cuento con la pantalla bloqueada.
 *
 * Con el teléfono bloqueado Android duerme la CPU y puede matar una app que "no hace nada visible", y el cuento (la
 * voz del sistema, el fondo, el avance de frase en frase) se corta. Un servicio **en primer plano** de tipo
 * `mediaPlayback` con su notificación de medios evita las dos cosas, y de paso deja los botones de
 * reproducir/pausar/parar en la pantalla de bloqueo. Mientras suena también toma un bloqueo parcial de CPU
 * (no enciende la pantalla) para que no se pare entre frase y frase.
 *
 * No toca el foco de audio: la voz y el fondo ya lo piden por su cuenta, y pedirlo aquí también haría que se
 * pausaran el uno al otro.
 */
class StoryAudioService : Service() {

    companion object {
        private const val CHANNEL_ID = "story_audio"
        private const val NOTIFICATION_ID = 4107
        private const val ACTION_PLAY = "play"
        private const val ACTION_PAUSE = "pause"
        private const val ACTION_STOP = "stop"

        // Mismo proceso que la actividad: se comunican por estas variables.
        @Volatile
        var instance: StoryAudioService? = null
            private set

        /** Quien recibe las órdenes de la notificación (la actividad las reenvía a Flutter). */
        @Volatile
        var onAction: ((String) -> Unit)? = null

        @Volatile
        private var title: String = ""

        @Volatile
        private var playing: Boolean = false

        /** Arranca el servicio (hay que llamarlo con la app a la vista). */
        fun begin(context: Context, title: String, playing: Boolean) {
            this.title = title
            this.playing = playing
            val running = instance
            if (running != null) {
                running.refresh()
                return
            }
            val intent = Intent(context, StoryAudioService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Cambia reproducir/pausar. Si el servicio aún no arrancó, lo recogerá al arrancar. */
        fun setPlaying(playing: Boolean) {
            this.playing = playing
            instance?.refresh()
        }

        fun end(context: Context) {
            // Se olvida ya de esta instancia: si enseguida se vuelve a llamar a begin (del cine al holograma), arranca
            // un servicio nuevo en vez de tomar por vivo uno que se está apagando.
            instance = null
            context.stopService(Intent(context, StoryAudioService::class.java))
        }
    }

    private var session: MediaSession? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Cuento sonando", NotificationManager.IMPORTANCE_LOW
            )
            channel.setSound(null, null)
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }
        session = MediaSession(this, "StoryAudio").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { onAction?.invoke(ACTION_PLAY) }
                override fun onPause() { onAction?.invoke(ACTION_PAUSE) }
                override fun onStop() { onAction?.invoke(ACTION_STOP) }
            })
            isActive = true
        }
        // Android exige llamar a startForeground enseguida después de startForegroundService.
        publish(first = true)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Botones de la notificación
        when (intent?.action) {
            ACTION_PLAY, ACTION_PAUSE -> onAction?.invoke(intent.action!!)
            ACTION_STOP -> {
                onAction?.invoke(ACTION_STOP)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Si cierran la app desde recientes, la voz ya no tiene quién la dirija.
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        releaseWakeLock()
        session?.isActive = false
        session?.release()
        session = null
        if (instance === this) instance = null
        super.onDestroy()
    }

    /** Pone al día la notificación, el estado de la sesión de medios y el bloqueo de CPU. */
    fun refresh() = publish(first = false)

    private fun publish(first: Boolean) {
        val isPlaying = playing
        val s = session ?: return
        s.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, title).build())
        s.setPlaybackState(
            PlaybackState.Builder()
                .setActions(
                    PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or
                        PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_STOP
                )
                .setState(
                    if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED,
                    PlaybackState.PLAYBACK_POSITION_UNKNOWN,
                    1f
                )
                .build()
        )
        if (isPlaying) acquireWakeLock() else releaseWakeLock()

        val notification = buildNotification(s, isPlaying)
        if (first) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } else {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(s: MediaSession, isPlaying: Boolean): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val appName = applicationInfo.loadLabel(packageManager).toString()
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
        val toggle = action(if (isPlaying) ACTION_PAUSE else ACTION_PLAY)
        val stop = action(ACTION_STOP)
        builder
            .setSmallIcon(R.drawable.ic_stat_story)
            .setContentTitle(title)
            .setContentText(appName)
            .setContentIntent(open)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Pausar" else "Seguir",
                toggle
            )
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Parar", stop)
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(s.sessionToken)
                    .setShowActionsInCompactView(0, 1)
            )
        return builder.build()
    }

    private fun action(name: String): PendingIntent {
        val intent = Intent(this, StoryAudioService::class.java).setAction(name)
        return PendingIntent.getService(
            this, name.hashCode(), intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        // Tope de seguridad de 4 horas por si algo falla: un cuento dura minutos.
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "caldero:story").apply {
            setReferenceCounted(false)
            acquire(4 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: RuntimeException) {
        }
        wakeLock = null
    }
}
