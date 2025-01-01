package com.example.heartguardapp3.services

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class HeartGuardFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        // Handle message here if needed
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Handle token refresh if needed
    }
} 