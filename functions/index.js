/**
 * Push notifications for Chatnook.
 *
 * - New chat message      -> notification to the receiver
 * - New ringing call      -> high-priority data push that rings the callee's
 *                            phone even when the app is closed (Android shows
 *                            a full-screen incoming call screen)
 * - Call stops ringing    -> push that dismisses that screen, plus a
 *                            "missed call" notification when nobody answered
 *
 * Device tokens live in `users/{uid}.fcmTokens` (written by the app);
 * tokens FCM reports as dead are removed after each send.
 */
const {setGlobalOptions} = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// Firestore triggers must run in the same region as the Firestore database.
// Check Firebase console -> Firestore -> location, and change this if it
// isn't nam5 / us-central1 (e.g. "asia-south1").
const REGION = "us-central1";
setGlobalOptions({region: REGION, maxInstances: 10});

// Keep in sync with CallConfig.ringTimeout in the app.
const RING_TIMEOUT_SECONDS = 45;

// Ended without the callee ever picking up.
const MISSED_STATUSES = new Set(["missed", "cancelled"]);

const DEAD_TOKEN_ERRORS = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/**
 * Sends [message] to every device of [uid] and prunes dead tokens.
 * @param {string} uid
 * @param {object} message FCM message without `token`/`tokens`.
 */
async function sendToUser(uid, message) {
  if (!uid) return;
  const userRef = db.collection("users").doc(uid);
  const user = await userRef.get();
  const tokens = user.get("fcmTokens") || [];
  if (tokens.length === 0) return;

  const result = await getMessaging().sendEachForMulticast({...message, tokens});
  const dead = [];
  result.responses.forEach((response, i) => {
    const code = response.error && response.error.code;
    if (DEAD_TOKEN_ERRORS.has(code)) {
      dead.push(tokens[i]);
    } else if (response.error) {
      logger.warn("Push failed", {uid, code, message: response.error.message});
    }
  });
  if (dead.length > 0) {
    await userRef.update({fcmTokens: FieldValue.arrayRemove(...dead)});
  }
}

exports.onMessageCreated = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const message = event.data && event.data.data();
      if (!message) return;
      const {senderId, receiverId} = message;
      if (!senderId || !receiverId || senderId === receiverId) return;

      const sender = await db.collection("users").doc(senderId).get();
      const senderName = sender.get("name") || "New message";
      const text = (message.text || "").trim();
      const body = message.isImage ? "📷 Photo" :
        text.length > 200 ? `${text.slice(0, 197)}...` : text;
      const chatId = event.params.chatId;

      await sendToUser(receiverId, {
        notification: {title: senderName, body},
        data: {type: "message", chatId, senderId, senderName},
        android: {
          priority: "high",
          // The tag lets the app clear this chat's notifications on open.
          notification: {channelId: "messages", tag: chatId},
        },
        apns: {payload: {aps: {"sound": "default", "thread-id": chatId}}},
      });
    },
);

exports.onCallCreated = onDocumentCreated("calls/{callId}", async (event) => {
  const call = event.data && event.data.data();
  if (!call || call.status !== "ringing") return;
  const callId = event.params.callId;
  const video = call.type === "video";
  const callerName = call.callerName || "Unknown";

  await sendToUser(call.calleeId, {
    // Data-only on Android so the app's background handler can show the
    // full-screen call UI instead of a plain notification.
    data: {
      type: "incoming_call",
      callId,
      callerId: call.callerId || "",
      callerName,
      callerPhotoUrl: call.callerPhotoUrl || "",
      callType: call.type || "audio",
      sentAt: String(Date.now()),
    },
    android: {
      priority: "high",
      // Never ring for a call that has long stopped ringing.
      ttl: RING_TIMEOUT_SECONDS * 1000,
    },
    // iOS: a regular alert that opens the app, which then rings in-app.
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
        "apns-expiration": String(
            Math.floor(Date.now() / 1000) + RING_TIMEOUT_SECONDS),
      },
      payload: {
        aps: {
          alert: {
            title: callerName,
            body: video ? "Incoming video call" : "Incoming voice call",
          },
          sound: "default",
        },
      },
    },
  });
});

exports.onCallUpdated = onDocumentUpdated("calls/{callId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  // Only the moment a call stops ringing matters here.
  if (before.status !== "ringing" || after.status === "ringing") return;
  if (after.status === "accepted") return;

  const callId = event.params.callId;
  const jobs = [
    // Stops the full-screen ringing on a closed app.
    sendToUser(after.calleeId, {
      data: {type: "call_ended", callId},
      android: {priority: "high", ttl: 60 * 1000},
    }),
  ];

  if (MISSED_STATUSES.has(after.status)) {
    const callerName = after.callerName || "Unknown";
    const kind = after.type === "video" ? "video" : "voice";
    jobs.push(sendToUser(after.calleeId, {
      notification: {title: callerName, body: `Missed ${kind} call`},
      data: {
        type: "missed_call",
        callId,
        callerId: after.callerId || "",
        callerName,
      },
      android: {
        priority: "high",
        notification: {channelId: "missed_calls", tag: `missed_${callId}`},
      },
      apns: {payload: {aps: {sound: "default"}}},
    }));
  }

  await Promise.all(jobs);
});
