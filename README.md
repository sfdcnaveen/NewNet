# NewNet

NewNet is a lightweight macOS menu‑bar download manager with yt‑dlp for social-media media links. It focuses on quick pasting, explicit format selection, and reliable merging of video + audio into a single file.

## Features

- Menu‑bar UI with quick paste and one‑click downloads.
- Format picker for supported media links (video/audio/resolution/codec).
- yt‑dlp integration with automatic ffmpeg merging for separate audio/video streams.
- Direct download support with resumable transfers.
- Per‑download progress, speed, and status.
- Recent downloads list with quick access to the Downloads folder.

## How It Works

- NewNet detects supported media links and uses yt‑dlp to inspect available formats.
- You choose the exact format; NewNet starts yt‑dlp with that selection.
- If the chosen format has separate audio/video streams, ffmpeg merges them into one file.
- Files are saved to your macOS Downloads folder by default.

## Requirements

- macOS 15+.
- `yt-dlp` installed (NewNet can download it automatically).
- `ffmpeg` installed for merged audio/video formats.

## Usage

1. Launch NewNet from the menu bar.
2. Paste a supported link.
3. Choose Video or Audio, then select a format from the list.
4. Click Download. Progress updates live in the download row.

## Common Issues

### Gatekeeper warning

If macOS blocks the app after download, remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/NewNet.app
```

### Missing ffmpeg

If video and audio are separate, NewNet requires ffmpeg to merge them into one file.

## Release Build (DMG)

```bash
xcodebuild -scheme NewNet -configuration Release -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
APP="build/DerivedData/Build/Products/Release/NewNet.app"
hdiutil create -volname NewNet -srcfolder "$APP" -ov -format UDZO build/NewNet.dmg
```

Upload `build/NewNet.dmg` to GitHub Releases.
