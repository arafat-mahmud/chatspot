# Voice & Video Calls - Implementation Documentation

## Overview

ChatSpot supports 1:1 **HD voice calls** and **HD video calls** between friends.
Media flows peer-to-peer over **WebRTC** (`flutter_webrtc`); **Firestore** is the
signaling channel, so no extra backend is needed.

Quality adapts to the network every 2 seconds, entirely on the device (no
server, no paid service):

| Level | Video | Voice | Needs roughly |
|---|---|---|---|
| Full HD | 1080p @ 30 fps, up to 4 Mbps | 64 kbps Opus fullband | 2.8 Mbps |
| HD (start) | 720p @ 30 fps, up to 2 Mbps | 64 kbps | 1.2 Mbps |
| Medium | 480p @ 30 fps | 48 kbps | 550 kbps |
| Low | 360p @ 24 fps | 36 kbps | 280 kbps |
| Very low | 240p @ 15 fps | 28 kbps | 110 kbps |
| Voice only | paused | 20 kbps | below that |

Voice always gets bandwidth before video, with in-band FEC, echo
cancellation and noise suppression. A sudden drop is handled within 2 s; when
the link recovers, quality jumps straight back up as soon as the bandwidth
estimate proves it (otherwise one level every ~8 s).

## Features

- Voice and video call buttons in every chat's app bar
- Full-screen incoming call screen with ringtone, from anywhere in the app
- Calling / ringing / connecting / reconnecting / duration states
- Mute, speaker, camera on/off, front/back camera switch, draggable self-view
- Remote "muted" and "camera off" indicators
- Busy detection (callee already on a call), 45 s ring timeout -> missed call
- **Rings even when the app is closed** (Android): FCM push -> full-screen
  incoming call screen over the lock screen, Accept / Decline
- Push notifications for new messages and missed calls
- Automatic recovery when the network changes (Wi-Fi <-> mobile) via continual
  ICE gathering, with ICE restart as the fallback
- **Adaptive quality**: Full HD on fast networks, down to 240p or voice only
  on slow ones and back up when the network recovers; both sides see "Full
  HD"/"HD" badges, "Weak/Poor connection", or "video paused" instead of a
  frozen picture
- Calls keep running in the background (Android foreground service, iOS background audio)
- Proximity sensor turns the screen off during earpiece calls
- **Calls** tab with call history (incoming / outgoing / missed, duration) and one-tap call back
- Friends-only, matching the messaging rules

## File Structure

```
lib/
├── services/call/
│   ├── call_config.dart     # ICE servers, media constraints, timeouts, bitrates
│   ├── call_model.dart      # CallType, CallStatus, CallModel (Firestore mapping)
│   ├── call_session.dart    # One call: WebRTC peer connection + Firestore signaling
│   ├── call_service.dart    # App-wide: start calls, incoming listener, busy handling, history
│   ├── call_platform.dart   # Ringtone, audio routing, screen handling, foreground service
│   ├── call_notifications.dart # System incoming-call screen (flutter_callkit_incoming)
│   ├── call_quality.dart    # Adaptive quality from live WebRTC stats
│   └── sdp_utils.dart       # Opus "HD voice" SDP tuning
└── views/call/
    ├── call_screen.dart          # In-call UI (incoming, outgoing, connected)
    └── call_history_screen.dart  # Calls tab
lib/services/notification/
└── push_notification_service.dart  # FCM token, foreground notifications, background handler
functions/index.js                  # Cloud Functions that send the pushes
firestore.rules                     # Security rules (includes `calls`)
```

## Push notifications

| Event | Cloud Function | What the phone shows |
|---|---|---|
| New message in `chats/{id}/messages` | `onMessageCreated` | Notification (sender name + text); tap opens the chat |
| New ringing `calls/{id}` | `onCallCreated` | App open: in-app call screen. App in background or closed: system full-screen call screen |
| Call stops ringing | `onCallUpdated` | Dismisses the ringing screen; "Missed call" notification if nobody answered |

The app stores each device's FCM token in `users/{uid}.fcmTokens`. Dead tokens
are removed by the functions after a failed send.

## How a call works

```
Caller                         Firestore calls/{id}                    Callee
------                         --------------------                    ------
getUserMedia + offer   ──►  status: ringing, offer{rev:0}   ──►  incoming listener → ring
trickle ICE            ──►  callerCandidates/*
                                                             ◄──  accept: answer{rev:0},
                       ◄──  status: accepted                      status: accepted
                                                             ◄──  calleeCandidates/*
              ◄════════════ peer-to-peer audio/video (SRTP) ════════════►
network drop: ICE restart → offer{rev:1}  ──►                ◄──  answer{rev:1}
hang up                ──►  status: ended, duration, endedBy
```

- Only the caller creates offers (including ICE restarts), so there is no offer glare.
- Every transition out of `ringing` runs in a transaction, so "accept" and
  "cancel" can never both win.
- Each side deletes its own ICE candidates when the call ends.

## Database Collection

### `calls`
```javascript
{
  callerId, callerName, callerPhotoUrl,
  calleeId, calleeName, calleePhotoUrl,
  participants: [callerId, calleeId],
  type: "audio" | "video",
  status: "ringing" | "accepted" | "ended" | "declined" | "missed" | "busy" | "cancelled" | "failed",
  offer:  { type, sdp, rev },
  answer: { type, sdp, rev },
  media:  { "<uid>": { mic, cam, videoPaused, net: "good" | "weak" | "poor",
                       quality: "ultra" | "high" | "medium" | "low" | "veryLow" | "minimal" } },
  createdAt, answeredAt, endedAt,  // server timestamps
  endedBy, duration                // seconds
}
// subcollections: callerCandidates/*, calleeCandidates/*  { candidate, sdpMid, sdpMLineIndex }
```

## Setup

### 0. Deploy rules and functions (required)

Without the `calls` rules every call fails immediately with
"Call failed: calls are not allowed by the server rules". Without the
functions, nothing rings while the app is closed.

```bash
firebase login --reauth
firebase deploy --only firestore:rules,firestore:indexes,functions
```

- Cloud Functions need the **Blaze** (pay-as-you-go) plan. The free quota
  (2M invocations/month) covers a small app.
- `firestore.rules` replaces the rules in the console. If you edited rules
  there, merge them into the file first.
- Firestore triggers must run in the database's region. If the deploy says the
  region doesn't match, set `REGION` in `functions/index.js` to your Firestore
  location (Firebase console -> Firestore).
- Xiaomi / Redmi / POCO, Oppo, Vivo and similar phones kill background apps
  aggressively. For calls to ring while the app is closed, enable **Autostart**
  for Chatnook and set battery saver to **No restrictions**.

### 1. Firestore index (call history)

The Calls tab queries `participants array-contains` + `orderBy createdAt`, which
needs a composite index. Until it exists the app falls back to client-side
sorting and prints a one-click creation link in the debug console.

Deploy it from `firestore.indexes.json`:
```bash
firebase deploy --only firestore:indexes
```
or create it in the Firebase console: collection `calls`, fields
`participants` (Arrays) + `createdAt` (Descending).

### 2. Firestore security rules

Merge this into your existing rules:

```
match /calls/{callId} {
  // Each disjunct matches one query: the incoming-call listener filters on
  // calleeId, the Calls tab on participants.
  allow read: if request.auth != null && (
    request.auth.uid == resource.data.calleeId ||
    request.auth.uid in resource.data.participants);

  allow create: if request.auth != null
    && request.resource.data.callerId == request.auth.uid
    && request.resource.data.participants ==
         [request.auth.uid, request.resource.data.calleeId]
    && request.resource.data.status == 'ringing';

  allow update: if request.auth != null
    && request.auth.uid in resource.data.participants
    && request.resource.data.callerId == resource.data.callerId
    && request.resource.data.calleeId == resource.data.calleeId
    && request.resource.data.participants == resource.data.participants;

  match /{candidateCollection}/{candidateId} {
    allow read, write: if request.auth != null
      && candidateCollection in ['callerCandidates', 'calleeCandidates']
      && request.auth.uid in
           get(/databases/$(database)/documents/calls/$(callId)).data.participants;
  }
}
```

### 3. TURN relay (optional, not used by default)

Calls connect peer-to-peer through free Google STUN servers, with no relay and
no running cost. That works on most Wi-Fi and many mobile connections, but
when **both** phones are behind strict carrier NAT (common on mobile data) a
call can stay on "Connecting…" and fail; only a TURN relay fixes that, and
relays cost money or a server to run. If you ever add one (coturn, Twilio,
Metered, Cloudflare…), pass it at build time:

```bash
flutter run \
  --dart-define=TURN_URLS=turn:turn.example.com:3478,turns:turn.example.com:5349 \
  --dart-define=TURN_USERNAME=user \
  --dart-define=TURN_CREDENTIAL=secret
```

### 4. Platform configuration (already done)

- **Android** (`AndroidManifest.xml`): microphone, camera, network, Bluetooth,
  wake lock and foreground-service permissions; foreground service of type
  `microphone|camera`. Runtime mic/camera permissions are requested when a call starts.
- **iOS** (`Info.plist`): camera/microphone usage descriptions and the `audio`
  background mode.
- Proximity sensor and keep-screen-on: `MainActivity.kt` / `AppDelegate.swift`
  (`chatspot/call` method channel).

## Testing

1. Run the app on **two physical devices** (simulators have no real camera),
   signed in as two users who are friends.
2. Open the chat and tap the phone or video icon.
3. Try: decline, no answer (45 s), hang up from both sides, mute/camera/speaker,
   switching Wi-Fi off mid-call (should show "Reconnecting…" and recover), and
   calling someone who is already on a call ("is on another call").
4. Weak networks: throttle one phone, e.g. Android: Settings -> Mobile network -> Preferred
   network type -> 2G/3G; iOS: Settings -> Developer -> Network Link
   Conditioner ("3G", "Very Bad Network"). Voice should stay clear; video
   drops resolution, then pauses with a "video paused" chip, and climbs back
   to HD / Full HD when the throttling is removed. `CallSession: quality …` lines in the debug log
   show each step.

Unit tests: `flutter test test/services/call`

## Limitations / next steps

- **iOS, app closed:** an incoming call arrives as a normal notification;
  tapping it opens the app, which rings. A native CallKit screen on a killed
  iOS app needs PushKit VoIP pushes (Apple VoIP certificate + APNs sender),
  which are not set up.
- On Android 13+, the ongoing-call notification is only visible if the user has
  granted notification permission; the call itself works either way.
- 1:1 only. Group calls would need an SFU (e.g. LiveKit) instead of peer-to-peer.
