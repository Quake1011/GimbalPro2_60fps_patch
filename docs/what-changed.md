# What changed

The patch is intentionally narrow:

- main recording encoder target frame rate: `30 -> 60`;
- normal `MediaRecorder` frame rate: `60`;
- Camera1 recording preview range: `60000/60000`;
- visible UI labels: `30fps -> 60fps`.

Known untouched areas:

- photo editing;
- video clipping/export;
- GL transition encoder;
- time-lapse encoder;
- generic media encoder;
- video bitrate;
- decoded Android resources.

The build script uses `apktool d -r` so raw resources are copied through instead
of being decoded and rebuilt.
