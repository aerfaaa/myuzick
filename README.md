# myuzick

A simple, modern offline MP3 player for iPhone.

## v0.1 — basic player

The first version focuses on the essentials:

- Import one or multiple MP3 files from the iOS Files app.
- Keep imported audio in the app's local storage.
- Read track title, artist, album, duration and embedded artwork.
- Browse and search the music library.
- Play, pause, seek, skip forward and skip backward.
- Automatically continue to the next track in the current list.
- Keep a mini-player available while browsing the library.
- Open a full now-playing screen.
- Retain the library after closing and reopening the app.

No account, streaming service or internet connection is required for playback.

## Build

Requirements: macOS with Xcode 15 or newer and XcodeGen.

```sh
xcodegen generate
open myuzick.xcodeproj
```

Set your own signing team and a unique bundle identifier before installing on a device.

## Technical stack

- SwiftUI
- AVFoundation / AVPlayer
- AVAudioSession
- SwiftData
- FileManager

## Scope

This is an early development build. Background audio is configured at the app level, but lock-screen metadata and remote transport controls are not implemented yet. Playlists, equaliser, shuffle and additional audio formats are intentionally deferred until the basic player is stable.
