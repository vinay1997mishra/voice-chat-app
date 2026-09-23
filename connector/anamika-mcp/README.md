# Anamika AI 13 ChatGPT MCP Connector

This folder is the remote relay between ChatGPT and the owner-paired Anamika Android app.

## Architecture

- ChatGPT connects to the public HTTPS `/mcp` endpoint.
- The Anamika phone pairs once through `/device/pair` using the server pairing code.
- The phone keeps an authenticated foreground data-sync bridge and polls for queued commands.
- ChatGPT tools can read connector status, queue a command, and fetch the result.
- Commands still pass through Anamika owner controls, Android permissions, normal command routing, and offline Qwen fallback.

## Required server environment

- `ANAMIKA_PAIRING_CODE`: one-time/admin pairing secret entered on the phone.
- `ANAMIKA_MCP_TOKEN`: bearer token used by the ChatGPT MCP connection.
- `PORT`: optional, defaults to `3000`.
- `ANAMIKA_CONNECTOR_DATA`: optional persistent data directory.

Never commit either secret to the repository.

## Run

```sh
npm install
ANAMIKA_PAIRING_CODE="..." ANAMIKA_MCP_TOKEN="..." npm start
```

Production deployment must expose a stable HTTPS URL, for example `https://connector.example.com/mcp`.
The Android setup screen takes the base URL without `/mcp`, for example `https://connector.example.com`.

## MCP tools

- `anamika_status`
- `send_anamika_command`
- `get_anamika_result`
- `recent_anamika_results`

The Android connector token returned by pairing is stored on the phone using Android Keystore AES-GCM on Android 6+.
