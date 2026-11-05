# Architecture notes

## App flow

`myuzickApp` owns the shared `AudioPlayer` and the SwiftData model container. `RootView` provides the tab shell and persistent mini-player.

## Import pipeline

1. `LibraryView` presents the system document picker for MP3 files.
2. `MusicFileStore` copies each selected file into the app's Documents/Music directory.
3. `MetadataReader` reads common metadata, duration and embedded artwork.
4. `Song` records are inserted into SwiftData.

## Playback pipeline

`AudioPlayer` owns an `AVPlayer`, a lightweight queue and published playback state. The selected song's copied local URL is passed to `AVPlayer`.

## Known starter limitations

- The queue is in-memory and resets when the app process ends.
- Repeat and shuffle are not implemented.
- End-of-track queue advancement and remote transport commands are not yet wired.
- Lock-screen / Control Centre metadata is not yet published.
- Import rollback for a file whose metadata cannot be read should be improved.
- Artwork extraction depends on the metadata exposed by the source file.
- The project has not been compiled in Xcode in this environment; build and device testing are required.
