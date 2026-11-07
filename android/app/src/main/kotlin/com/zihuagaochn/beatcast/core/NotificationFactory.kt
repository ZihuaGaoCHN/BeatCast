package com.zihuagaochn.beatcast.core

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.Icon
import android.os.Build
import com.zihuagaochn.beatcast.BeatCastService
import com.zihuagaochn.beatcast.MainActivity
import com.zihuagaochn.beatcast.R
import com.zihuagaochn.beatcast.model.BroadcastSnapshot

class NotificationFactory(private val context: Context) {
    fun ensureChannel() {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(R.string.notification_channel_description)
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        manager.createNotificationChannel(channel)
    }

    fun build(snapshot: BroadcastSnapshot): Notification {
        val openIntent = PendingIntent.getActivity(
            context,
            REQUEST_OPEN,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = PendingIntent.getService(
            context,
            REQUEST_STOP,
            Intent(context, BeatCastService::class.java).setAction(BeatCastService.ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopAction = Notification.Action.Builder(
            Icon.createWithResource(context, R.drawable.ic_stat_stop),
            context.getString(R.string.notification_stop),
            stopIntent,
        ).build()

        val builder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_beat)
            .setContentTitle(context.getString(R.string.notification_title))
            .setContentText(statusText(snapshot))
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setColor(ACCENT)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(stopAction)

        if (Build.VERSION.SDK_INT >= 31) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun statusText(snapshot: BroadcastSnapshot): String = when {
        snapshot.phase == BroadcastSnapshot.PHASE_ERROR ->
            context.getString(R.string.notification_attention)

        snapshot.clients > 0 && snapshot.bpm != null ->
            context.getString(R.string.notification_live, snapshot.bpm, snapshot.clients)

        snapshot.clients > 0 ->
            context.getString(R.string.notification_connected, snapshot.clients)

        else -> context.getString(R.string.notification_waiting)
    }

    companion object {
        const val CHANNEL_ID = "beatcast.broadcast"
        const val NOTIFICATION_ID = 4101
        private const val REQUEST_OPEN = 41
        private const val REQUEST_STOP = 42
        private val ACCENT = Color.rgb(255, 107, 94)
    }
}
