package com.example.heartguardapp3

import io.flutter.app.FlutterApplication
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class HeartGuardApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "heart_guard_channel",
                "Heart Guard Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Important alerts from Heart Guard"
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
} 