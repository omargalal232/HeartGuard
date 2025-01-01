import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

export const sendEmergencyAlerts = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { userId, userName, heartRate, timestamp, contacts, location } = data;

  const messages = contacts.map((contact: any) => ({
    notification: {
      title: 'Emergency Alert!',
      body: `${userName} needs immediate attention! Heart rate: ${heartRate} BPM`,
    },
    data: {
      type: 'emergency_alert',
      userId: userId,
      heartRate: heartRate.toString(),
      timestamp: timestamp,
      latitude: location?.latitude?.toString() || '',
      longitude: location?.longitude?.toString() || '',
    },
    token: contact.fcmToken,
  }));

  try {
    const response = await admin.messaging().sendAll(messages);
    console.log('Successfully sent messages:', response);
    return { success: true, messagesSent: response.successCount };
  } catch (error) {
    console.error('Error sending messages:', error);
    throw new functions.https.HttpsError('internal', 'Error sending emergency alerts');
  }
}); 