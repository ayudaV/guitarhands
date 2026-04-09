# Track Builder

The track builder scene is the editor/runtime hub for creating, loading, and previewing tracks.

Main scene:

- [track_builder/track_builder.tscn](../track_builder/track_builder.tscn)

## Main nodes

- `Track` instantiates the playable track mesh and follower.
- `ConfigLayer` holds the UI and runtime transport controls.
- `PlaybackController` controls play, pause, and seeking.
- `TrackSetupPanel` handles loading and saving track metadata.
- `FileWriter` persists track data.
- `FileReader` rebuilds the runtime scene from saved JSON.
- `SwitchRoot` stores timed mode switches.

## Runtime pieces

### TrackFollower

See [models/track_follower/track_follower.gd](../models/track_follower/track_follower.gd).

- Keeps the follower progress in sync with the audio playback position.
- Uses `track_speed` to convert music time into path progress.
- Switches between guitar, spaceship, and shapes mode scenes.
- Uses `is_playing` to decide whether it should keep updating from audio.

### PlaybackController

See [track_builder/playback_controller/playback_controller.gd](../track_builder/playback_controller/playback_controller.gd).

- Owns Play and Pause buttons.
- Owns the seek bar.
- Starts the music from the current seek position.
- Pauses the music without destroying the loaded track state.
- Updates the `TrackFollower` transport state when playback changes.

### TrackSetupPanel

See [track_builder/track_setup_panel/create_track_panel.gd](../track_builder/track_setup_panel/create_track_panel.gd).

- Displays the editable track folder, title, BPM, speed multiplier, track speed, and WAV path.
- Loads values from `FileLoader` into the UI.
- Imports loaded track JSON into `FileWriter`.
- Copies the UI values back into `FileWriter` on save.
- Triggers the reader to reload the runtime objects after load or save.

## Track data

The builder works with the JSON track format documented in [docs/load_save_system.md](load_save_system.md).

The important fields for the builder are:

- `track_name`
- `title`
- `music_path`
- `bpm`
- `speed_multiplier`
- `track_speed`

## Flow overview

### Save Track

1. The user edits the panel fields.
2. The panel copies the display values into `FileWriter`.
3. `FileWriter.save_track()` writes the JSON file and local music copy.
4. `FileReader.reload_track()` refreshes the runtime scene objects.

### Load Track

1. The user enters a track folder and clicks Load.
2. `FileLoader.load_track()` reads the track metadata and button lists.
3. The panel copies the loaded values back into the UI.
4. The panel imports the loaded JSON into `FileWriter`.
5. `FileReader.reload_track()` rebuilds the runtime track objects.

## Notes

- The scene depends on direct exported references instead of runtime node-path lookup.
- The builder is intentionally split between UI, transport, saving, and reconstruction so each part stays narrow.
