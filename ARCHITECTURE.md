# Data architecture

How ChatSpot loads, caches and writes data, and what each screen costs in
Firestore reads and writes.

## Principles

1. **One listener per kind of data, per session.** Friends, friend requests,
   the chat list and your own profile are each loaded by a single listener
   that lives from sign-in to sign-out. Screens read from memory.
2. **Firestore's on-device cache is the mobile cache.** Persistence is on
   (200 MB). Lists appear instantly on launch and work offline. A listener
   resumed within 30 minutes only pays for documents that changed.
3. **Bounded queries only.** Every query has a `limit` or a narrow filter.
   Nothing downloads a whole collection.
4. **Denormalize what's read often, fan out what's written rarely.**
   Friendships and chats carry each person's name and photo, so lists never
   read profiles. When you edit your profile, the change is copied into those
   documents once (`ProfileService.update`).
5. **Optimistic writes.** Firestore applies writes locally at once; the UI
   updates immediately, even offline, and syncs later. Failures show a
   snackbar (`AppMessenger`).

## Layers

```
SessionService            starts/stops everything once per signed-in user
├── UserRepository        own profile (live) + cached profiles (memory + disk, 12 h)
├── FriendRepository      friends, received and sent requests (3 listeners)
├── ChatRepository        chat list (1 listener, 50 at a time), send, mark read
└── PresenceService       own "active" status + friends' (foreground only)
ChatRoomController        one open chat: 30 newest live, older pages on scroll
UserSearchService         prefix queries on nameLower / name / username, limit 20
SearchHistoryStore        recent profiles, on device only
ProfileService            own profile edits + fan-out
```

Screens (`views/`, `dashboard/`) only talk to these classes.

## Cost per action

| Action | Before | Now |
|---|---|---|
| App launch | every chat re-read **and rewritten**, +1 read per chat participant | 1 listener each for profile, friends, requests and chats (cache first) |
| Chat list | all chats, then the **whole friends list once per chat** on every change | ≤ 50 chats; names/photos from memory |
| Open a chat | **all** messages, a new listener on every rebuild, 1 profile listener per message | ≤ 30 messages; older pages of 30 on scroll |
| Read messages | 1 write **per message** | 1 write per chat visit (`unread`, `lastRead` on the chat doc) |
| Send a message | full friends query + 2 profile reads + 2 writes | 2 writes (message + chat summary) |
| Search | **whole `users` collection on every keystroke**, +3 queries per result | debounced; ≤ 3 queries of ≤ 20 docs; cached per query |
| Search history | 1 read + 1 read per entry; 1 write per visit | on device, 0 |
| Friends screen / badges | separate queries per screen and per badge | memory, 0 |
| Send / accept request | 3 queries + 1–2 profile reads | 1 write / 1 batch |
| Drawer, menu, my profile | 1 read each time opened | memory, 0 |
| Username check | 1 query per keystroke (+2 debug queries per visit) | 1 read after typing pauses |
| Image bubbles | re-downloaded on every scroll | disk-cached |
| FCM token | 1 write per app start | only when it changes (or weekly) |
| Presence (new) | — | 1 write on open, 1 on leave, 1 per 10 min while open; friends' status read only while the app is open |

## Data model additions

- `chats/{a-b}`:
  - `participantIds: [a, b]` (sorted) for the ordered, limited chat list query
  - `unread: {uid: n}` increments with each message
  - `lastRead: {uid: timestamp}` drives unread counts and the "Seen" receipt
  - `users.{uid}.photoUrl`
- `users/{uid}.nameLower` for name prefix search. Accounts get it when their
  owner next signs in. Until then, search also matches the capitalized name.
- New friend requests use the id `{sender}_{receiver}` and also store the
  receiver's name and photo. New friendships use `{a}_{b}`. Older documents
  with random ids keep working.

Older chats get `participantIds` once, on the first sign-in after the update
(`ChatRepository._migrateLegacyChats`).

## Presence

`presence/{uid}: {online, lastActive}`, written only by its owner:

- on coming to the foreground: `online: true`
- every 10 minutes while open (heartbeat)
- on going to the background or logging out: `online: false`

Someone is "Active now" when `online` is true and the heartbeat is under
12 minutes old, so an app that was killed without going offline stops
showing as active by itself. Otherwise the UI shows "Active 5m ago" (badge
on avatars for the last hour, full label in the chat header up to a week).

Friends' presence is followed in batches of 30 per listener and only while
the app is in the foreground. The chat list's top strip shows friends who
are active now or were in the last hour.

## Notifications when the app is closed

Only a server can wake a closed app. The Cloud Functions in `functions/`
(`onMessageCreated`, `onCallCreated`, `onCallUpdated`) send FCM pushes:
message and missed-call pushes are shown by the system itself; incoming
calls ring through the native call screen. They must be deployed (see
CALL_SYSTEM_README.md). The app saves each device's token to
`users/{uid}.fcmTokens`.

## Deploy

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

- The index (`participantIds` + `lastMessageTime`) powers the chat list.
  Until it's built, the app falls back to the old unordered query.
- The rules now scope chats, messages, requests and friendships to their
  participants, and only the owner can edit a profile.
