# Bluetooth Profiles

A Ryoku shell plugin (`bluetooth-profiles`) to view and change Bluetooth audio profiles (A2DP High Fidelity codecs like AAC, SBC, SBC-XQ, LDAC, aptX vs Headset HSP/HFP for mic/calls) of connected devices directly from the QS bar.

Designed to faithfully match the native Ryoku Bluetooth panel aesthetic.

## Features

- **Live Profile Switching**: One-click switching between High Fidelity audio (AAC, SBC, SBC-XQ, LDAC, aptX) and Headset (HSP/HFP) with microphone support.
- **Instant Reactive Sync**: Listens to PulseAudio/PipeWire events via `pactl subscribe` for zero-latency updates when devices connect, disconnect, or change profiles externally.
- **Top Bar Glyph**: Compact bar widget showing connection status and current active audio codec (e.g. `AAC`, `HFP`) or device count.
- **Connected Device Details**: Displays device names, connection state, battery percentage, and full profile list with codec badges.
- **Quick Action Toggle**: Instant one-click toggle between Music (High-Fi) and Voice/Call (Headset) modes directly on each device card.
- **Native Ryoku Styling**: Seamlessly integrates with the active desktop theme palette, typography, and connected panel surfaces.

## Architecture

- **Service (`service/Main.qml`)**: Background logic that inspects audio cards via `pactl --format=json list cards`, parses profiles and BlueZ battery information, watches `pactl subscribe` event stream, and executes profile switches.
- **Widget (`content/Widget.qml`)**: The top bar glyph rendering the Bluetooth icon and optional active codec/count badge. Left-click toggles the panel.
- **Panel (`content/Panel.qml`)**: The popup card rendering connected devices, quick action buttons, expandable profile radio selectors, and settings links.

## Settings

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `barBadge` | choice | `codec` | Text shown beside the bar mark (`codec`, `count`, or `none`) |
| `autoExpand` | toggle | `true` | Always expand profiles list by default |

## Validation & Installation

```bash
# Validate manifest and security rules
ryoku plugin validate /home/matthias/dev/quickshell-plugins/bluetooth-profiles

# Install and enable on the top bar
ryoku plugin add /home/matthias/dev/quickshell-plugins/bluetooth-profiles --bar --yes
```

## Author

Matthias <derntl@daim.tech>
