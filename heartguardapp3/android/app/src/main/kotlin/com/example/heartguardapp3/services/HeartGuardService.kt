package com.example.heartguardapp3.services

import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.heartguardapp3.R

class HeartGuardService : Service() {
    companion object {
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "heart_guard_channel"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIFICATION_ID, createNotification())
    }

    private fun createNotification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle("Heart Guard")
        .setContentText("Monitoring your heart health")
        .setSmallIcon(R.drawable.notification_icon)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .build()
} 