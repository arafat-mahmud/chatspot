# Voice & Video Calls - Implementation Documentation

## Overview

ChatSpot supports 1:1 **HD voice calls** and **HD video calls** between friends.
Media flows peer-to-peer over **WebRTC** (`flutter_webrtc`); **Firestore** is the
signaling channel, so no extra backend is needed.

| | Quality |
|---|---|
| Voice | Opus fullband (48 kHz), 64 kbps, in-band FEC for packet loss, echo cancellation + noise suppression |
| Video | 1280x720 @ 30 fps, up to 2.5 Mbps; WebRTC congestion control scales down automatically on weak networks |

## Features

- Voice and video call buttons in every chat's app bar
- Full-screen incoming call screen with ringtone, from anywhere in the app
- Calling / ringing / connecting / reconnecting / duration states
- Mute, speaker, camera on/off, front/back camera switch, draggable self-view
- Remote "muted" and "camera off" indicators
- Busy detection (callee already on a call), 45 s ring timeout -> missed call
- Automatic recovery when the network changes (Wi-Fi <-> mobile) via ICE restart
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
│   └── sdp_utils.dart       # Opus "HD voice" SDP tuning
└── views/call/
    ├── call_screen.dart          # In-call UI (incoming, outgoing, connected)
    └── call_history_screen.dart  # Calls tab
```

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
  media:  { "<uid>": { mic: true, cam: true } },
  createdAt, answeredAt, endedAt,  // server timestamps
  endedBy, duration                // seconds
}
// subcollections: callerCandidates/*, calleeCandidates/*  { candidate, sdpMid, sdpMLineIndex }
```

## Setup

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

### 3. TURN server (recommended for production)

Google STUN servers are configured by default, which connects most calls. Calls
between users behind strict/symmetric NATs (some mobile carriers, corporate
Wi-Fi) need a TURN relay. Use a hosted one (e.g. Cloudflare Calls TURN, Twilio,
Metered) or self-host [coturn](https://github.com/coturn/coturn), then pass the
credentials at build time — they never go into git:

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

Unit tests: `flutter test test/services/call`

## Limitations / next steps

- **Ringing when the app is closed** requires push notifications: FCM (Android)
  / PushKit + CallKit (iOS) triggered by a Cloud Function on `calls` create.
  Today incoming calls ring while the app is open or recently backgrounded.
- On Android 13+, the ongoing-call notification is only visible if the user has
  granted notification permission; the call itself works either way.
- 1:1 only. Group calls would need an SFU (e.g. LiveKit) instead of peer-to-peer.
