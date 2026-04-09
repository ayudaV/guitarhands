# Load and Save System

This project uses a JSON track file as the source of truth for a loaded track.
The current format is stored under `user://tracks/<track_name>/data.json`.
A legacy `game_data.json` path is still supported for compatibility while loading existing tracks for append.

## What gets saved

The save payload includes:

- `track_name`
- `title`
- `music_path`
- `bpm`
- `speed_multiplier`
- `track_speed`
- `guitar_buttons`
- `guitar_sliders`
- `shape_buttons`
- `switchs`

`music_path` normally points to the copied local music file inside the track folder:
`user://tracks/<track_name>/music.wav`.

## FileWriter

See [track_builder/file_writer/file_writer.gd](../track_builder/file_writer/file_writer.gd).

Responsibilities:

- Stores the editable track metadata in exported fields.
- Copies the source WAV into the track folder when preparing a new track.
- Serializes track data to JSON.
- Appends new runtime input into the recorded button lists.
- Saves using `save_track()`.

Important methods:

- `apply_track_metadata(...)` updates the writer fields from the panel.
- `save_track()` writes the current JSON payload to disk.
- `_build_save_payload(...)` assembles the JSON dictionary.
- `_sync_music_stream()` loads the local WAV into the active `AudioStreamPlayer`.

## FileReader

See [track_builder/file_reader/file_reader.gd](../track_builder/file_reader/file_reader.gd).

Responsibilities:

- Loads `data.json` for a track folder.
- Reads metadata back into the active runtime.
- Loads the music stream from `music_path`.
- Recreates the recorded track objects from the saved lists.
- Configures the `TrackFollower` transport state.

Important behavior:

- `track_speed` is read from the file when present.
- If `track_speed` is missing, it is derived from `bpm / 60 * speed_multiplier`.
- The spawned gameplay objects use the loaded `track_speed`.

## FileLoader

See [track_builder/file_loader/file_loader.gd](../track_builder/file_loader/file_loader.gd).

This is a separate JSON loader that reads the track file and exposes the parsed data for the panel.
It keeps track metadata such as title, BPM, speed multiplier, music path, track speed, and the raw button lists.

## Load flow

1. The panel asks the writer to load an existing track folder.
2. `FileLoader` parses the JSON data for that track folder.
3. The panel copies the loaded values into the visible fields.
4. The panel imports the loaded JSON into `FileWriter`.
5. The reader reloads the runtime scene objects from the same track folder.

## Save flow

1. The user edits the fields in the track panel.
2. The panel copies the display values into the writer.
3. The writer stores metadata and button lists in JSON.
4. The reader can be reloaded so the runtime scene matches the saved track.

## Notes

- The project favors direct exported references for scene dependencies.
- Missing scene bindings should fail loudly instead of being hidden by defensive null plumbing.
- The saved JSON file is the canonical track record; the local WAV copy is stored alongside it.
