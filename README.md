<div align="center">
  <img src="app_icon.png" width="128" alt="NewNet Logo">
  <h1>NewNet</h1>
  <p><strong>A lightning-fast, native macOS menu-bar download manager powered by <code>yt-dlp</code>.</strong></p>

  [![macOS](https://img.shields.io/badge/macOS-15.0+-000000.svg?logo=apple&style=flat-square)](https://apple.com/macos)
  [![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
  [![GitHub release (latest by date)](https://img.shields.io/github/v/release/sfdcnaveen/NewNet?style=flat-square)](https://github.com/sfdcnaveen/NewNet/releases)
  [![Downloads](https://img.shields.io/github/downloads/sfdcnaveen/NewNet/total?style=flat-square)](https://github.com/sfdcnaveen/NewNet/releases)
</div>

<br>

NewNet is a lightweight, natively built macOS menu-bar utility designed for quick, explicit, and reliable media downloading. It acts as a beautiful frontend for `yt-dlp`, allowing you to easily select video and audio formats, download them, and automatically merge them using bundled `ffmpeg`—all without opening a terminal.

## ✨ Features

- **Menu-Bar Native UI:** Instantly accessible from your menu bar with quick paste functionality.
- **Explicit Format Selection:** Choose exactly what video/audio resolution and codec you want before downloading.
- **Auto-Merging:** Seamlessly merges separate high-quality video and audio streams via bundled `ffmpeg`.
- **Resumable Downloads:** Direct download support with robust resumption capabilities.
- **Live Progress Tracking:** Monitor speeds, progress, and statuses directly in the app.
- **In-App Auto Updates:** Never miss a release. Powered by Sparkle, NewNet updates itself automatically.
- **Privacy First:** Built-in telemetry is anonymous and easily opt-outable in Settings.

## 🚀 Installation

### Option 1: Direct Download (Recommended)
1. Head to the [Releases](https://github.com/sfdcnaveen/NewNet/releases) page.
2. Download the latest `NewNet-X.X.X.dmg`.
3. Open the DMG and drag `NewNet.app` into your `/Applications` folder.
4. Launch NewNet! 
> *Note: If macOS prompts you with an "Unverified Developer" warning, simply Right-Click (or Control-Click) the app in your Applications folder and select **"Open"**.*

### Option 2: Homebrew (Coming Soon)
```bash
brew install --cask newnet
```

## 🛠️ Usage

1. Click the NewNet icon in your macOS menu bar.
2. Paste any supported media link (YouTube, Twitter, Vimeo, etc.).
3. Choose **Video** or **Audio**, then select your preferred format and quality from the dropdown.
4. Click **Download**! The file will be saved directly to your Downloads folder.

## 💻 Development & Building

Want to build NewNet from source or contribute? Check out our [Contributing Guidelines](CONTRIBUTING.md).

**Quick Build:**
```bash
# Clone the repository
git clone https://github.com/sfdcnaveen/NewNet.git
cd NewNet

# Build the release app
./makedmg.sh
```

*Note: You must have `yt-dlp` installed for local development. `ffmpeg` binaries are downloaded automatically during the DMG build process.*

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
