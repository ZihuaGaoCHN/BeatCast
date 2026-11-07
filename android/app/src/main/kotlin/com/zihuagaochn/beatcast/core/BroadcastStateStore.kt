package com.zihuagaochn.beatcast.core

import android.os.Handler
import android.os.Looper
import com.zihuagaochn.beatcast.model.BroadcastSnapshot
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Process-wide, lock-free-ish state bus shared by the foreground service and
 * the Flutter activity. The service owns the truth; the activity only observes.
 */
object BroadcastStateStore {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArraySet<(BroadcastSnapshot) -> Unit>()

    @Volatile
    private var current = BroadcastSnapshot()

    val snapshot: BroadcastSnapshot
        get() = current

    fun update(transform: (BroadcastSnapshot) -> BroadcastSnapshot) {
        val next = synchronized(this) {
            transform(current).also { current = it }
        }
        mainHandler.post {
            listeners.forEach { listener ->
                runCatching { listener(next) }
            }
        }
    }

    fun addListener(listener: (BroadcastSnapshot) -> Unit) {
        listeners.add(listener)
        mainHandler.post {
            if (listeners.contains(listener)) {
                runCatching { listener(current) }
            }
        }
    }

    fun removeListener(listener: (BroadcastSnapshot) -> Unit) {
        listeners.remove(listener)
    }

    fun reset(snapshot: BroadcastSnapshot = BroadcastSnapshot()) {
        update { snapshot }
    }
}
