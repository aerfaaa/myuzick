# myuzick

A modern, offline-first MP3 player for iPhone, built with SwiftUI and AVFoundation.

> Early development starter — the first milestone focuses on importing local MP3 files, reading their metadata, displaying a library, and basic playback.

## Requirements

- macOS with Xcode 15 or newer
- iOS 17.0 deployment target
- XcodeGen (to generate the Xcode project)

## Getting started

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. Clone this repository.
3. From the repository root, run:

   ```sh
   xcodegen generate
   open myuzick.xcodeproj
   ```

4. Select your Apple development team under **Signing & Capabilities**.
5. Select an iPhone simulator or connected iPhone and build.

The app bundle identifier is currently `com.example.myuzick`. Change it to your own unique identifier before installing on a physical device.

## Current functionality

- Import MP3 files using the iOS Files picker.
- Copy imported audio into the app's private Documents/Music directory.
- Read common audio metadata and embedded artwork.
- Persist the library with SwiftData.
- Browse and search imported tracks.
- Play, pause, seek, and skip between tracks.
- Keep a compact player visible across tabs.

## Planned next

- Background playback and lock-screen / Control Centre metadata.
- Queue management and repeat / shuffle.
- Playlists and sorting.
- Better artwork fallbacks and empty states.
- Additional formats (M4A, AAC, WAV; FLAC support to be evaluated separately).
- Unit tests and CI build validation.

## Architecture

```text
myuzick/
├── App/                 App entry point
├── Models/              SwiftData models
├── Audio/               Playback engine
├── Library/             Importing and metadata extraction
├── Features/            SwiftUI screens
├── Components/          Reusable UI
└── Resources/           Asset catalog
```

### Design decisions

- **SwiftUI** for the native interface.
- **AVPlayer** for local audio playback and seeking.
- **SwiftData** for library metadata and playlists (planned).
- **FileManager** for copying imported audio into app-owned storage.
- **AVFoundation** for audio metadata and artwork extraction.

Imported audio is copied into the app sandbox. The app does not stream music or require an account.

## Notes

This is an early starter project, not a finished App Store product. Test with non-DRM MP3 files first. Audio formats and metadata can vary between files. Background audio capability is declared in the project configuration; lock-screen controls and robust interruption handling are planned follow-up work.
