# OpenClawControl iOS

`OpenClawControl` is a self-hosted native SwiftUI client for the OpenClaw gateway. It replaces the browser Control UI session friction with a secure native app flow:

- secure gateway URL, token, device ID, client ID, and active session key in Keychain
- `URLSessionWebSocketTask` transport against the same gateway WebSocket used by the browser UI
- auto-reconnect on app launch, foreground resume, and network recovery
- local chat/session/dashboard cache for offline viewing and fast cold-start restore
- dark native shell with drawer, chat, server status, sessions, usage, agents, and settings
- push-ready app delegate and token handling stubs without imposing any hosted dependency

## Repo layout

```text
apps/ios/OpenClawControl/
├── OpenClawControl.xcodeproj/
├── OpenClawControl/
│   ├── App/
│   ├── Configurations/
│   ├── Models/
│   ├── Resources/
│   ├── Services/
│   ├── ViewModels/
│   └── Views/
└── Deploy/
```

## Architecture

- `App/OpenClawControlApp.swift`: app entrypoint, scene lifecycle, and native dark-mode shell.
- `Models/AppModels.swift`: connection, chat, usage, agent, server, and cache models.
- `Services/KeychainService.swift`: secure credential and identifier persistence.
- `Services/SecureConfigurationStore.swift`: bootstraps from build config once, then persists everything in Keychain.
- `Services/GatewayClient.swift`: clean WebSocket request/event transport built on `URLSessionWebSocketTask`.
- `Services/LocalCacheStore.swift`: on-device JSON cache for sessions, messages, usage, and server state.
- `Services/NetworkMonitor.swift`: reconnect trigger for network recovery.
- `Services/PushNotificationCoordinator.swift`: APNs-ready seam for future server-driven notifications.
- `ViewModels/AppViewModel.swift`: MVVM coordinator for connect, reconnect, message flow, and page refreshes.
- `Views/*`: SwiftUI shell, reusable cards, chat experience, and dashboard pages.

## Gateway contract

The app talks directly to the existing OpenClaw gateway WebSocket and uses the same method family as the browser UI:

- `connect`
- `chat.history`
- `chat.send`
- `sessions.list`
- `sessions.usage`
- `usage.cost`
- `agents.list`
- `health`

No browser cookies, no tab-local token storage, and no hosted middleware are required.

## Setup

1. Open `apps/ios/OpenClawControl/OpenClawControl/Configurations/Environment.xcconfig.template`.
2. Copy it to `apps/ios/OpenClawControl/OpenClawControl/Configurations/Environment.xcconfig`.
3. Fill in:
   - `OPENCLAW_BOOTSTRAP_GATEWAY_URL`
   - `OPENCLAW_BOOTSTRAP_GATEWAY_TOKEN`
   - `OPENCLAW_BOOTSTRAP_DISPLAY_NAME`
4. Open `apps/ios/OpenClawControl/OpenClawControl.xcodeproj` in Xcode 16 or newer.
5. Select the `OpenClawControl` target, your team, and a physical iPhone running iOS 17+.
6. Build and run.
7. On first launch the app imports the bootstrap URL/token into Keychain, generates secure device and client IDs, opens the socket, and restores the active session automatically.

## Running against your OpenClaw server

Preferred backend options:

- direct private-network `wss://` to the existing OpenClaw gateway
- Tailscale MagicDNS plus HTTPS/WSS
- a reverse proxy terminating TLS in front of the gateway

Recommended gateway posture:

- keep the OpenClaw gateway bound on a private network or loopback behind a reverse proxy
- keep token auth enabled for the native app
- avoid embedding production secrets directly in source; use the local `Environment.xcconfig` file for bootstrap only
- if you rotate the token, open the app Settings page, paste the new token, and tap `Save and Reconnect`

## Xcode run checklist

1. Confirm the gateway accepts the WebSocket URL you configured.
2. Confirm the token can connect from another control surface first.
3. Build the app.
4. Launch on iPhone.
5. Verify the top banner reaches `Connected`.
6. Open `Server Status` and confirm the gateway version and health snapshot.
7. Open `Sessions`, pick a session, return to `Assistant`, and verify history loads.
8. Send a test message from the composer and confirm streamed assistant output appears in chat.

## Backend deployment notes

The iPhone runtime is native only. Server-side deployment artifacts live in `Deploy/` and are optional:

- `Deploy/docker-compose.yml`
- `Deploy/Caddyfile`
- `Deploy/.env.example`

Use them only if you want a TLS reverse proxy in front of an existing Dockerized OpenClaw gateway.

