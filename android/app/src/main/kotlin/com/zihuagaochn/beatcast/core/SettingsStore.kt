package com.zihuagaochn.beatcast.core

import android.content.Context
import com.zihuagaochn.beatcast.model.BroadcastSettings

class SettingsStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(): BroadcastSettings = BroadcastSettings.sanitize(
        mode = prefs.getString(KEY_MODE, BroadcastSettings.MODE_BALANCED),
        autoStop = prefs.getInt(KEY_AUTO_STOP, 15),
        maxSession = prefs.getInt(KEY_MAX_SESSION, 0),
    )

    fun save(settings: BroadcastSettings) {
        prefs.edit()
            .putString(KEY_MODE, settings.advertisingMode)
            .putInt(KEY_AUTO_STOP, settings.autoStopMinutes)
            .putInt(KEY_MAX_SESSION, settings.maxSessionMinutes)
            .apply()
    }

    fun hasPromptedPermissions(): Boolean = prefs.getBoolean(KEY_PROMPTED, false)

    fun markPromptedPermissions() {
        prefs.edit().putBoolean(KEY_PROMPTED, true).apply()
    }

    private companion object {
        const val PREFS = "beatcast.settings"
        const val KEY_MODE = "advertisingMode"
        const val KEY_AUTO_STOP = "autoStopMinutes"
        const val KEY_MAX_SESSION = "maxSessionMinutes"
        const val KEY_PROMPTED = "permissionsPrompted"
    }
}
