# Mac Screenrecorder

Native macOS screen recorder for presenting web apps.

## Features

- Record full display, app window, or selected region
- Web demo, Retina, social clip, and browser-window presets
- Microphone and system audio capture
- Adjustable resolution, codec, frame rate, bitrate, and video quality
- Audio level meters for microphone and system audio
- Cursor capture and configurable click highlighting
- Countdown overlay before recording starts
- Floating mini controls for pause, microphone mute, and stop
- Simple trim editor after recording
- Menu bar controls and keyboard shortcuts

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

## License

MIT. See [LICENSE](LICENSE).
