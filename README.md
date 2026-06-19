# Mac Screenrecorder

Native macOS screen recorder for presenting web apps.

## Features

- Record full display, app window, or selected region
- Microphone and system audio capture
- Adjustable resolution and video quality
- Cursor capture and click highlighting
- Floating mini controls for pause and stop
- Simple trim editor after recording
- Menu bar controls

## Requirements

- macOS 14 or newer
- Xcode command line tools
- Screen Recording and Microphone permissions

## Run

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM app, stages `dist/MacScreenRecorder.app`, signs it with the first available local codesigning identity, and launches it.

## Notes

For stable Screen Recording permissions during development, sign the app with a persistent local codesigning identity. The build script automatically uses an available identity such as `Apple Development` or another valid codesigning certificate.
