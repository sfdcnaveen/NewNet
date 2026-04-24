# Contributing to NewNet

First off, thank you for considering contributing to NewNet! It's people like you that make the open-source community such an amazing place to learn, inspire, and create.

## 🛠 Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/NewNet.git
   cd NewNet
   ```
3. **Open** the project in Xcode:
   ```bash
   open NewNet.xcodeproj
   ```

## 🏗 Building the Project

NewNet is a native macOS app built using Swift and SwiftUI. 

To build and run the app locally:
1. Ensure you have macOS 15.0+ and the latest Xcode installed.
2. Ensure you have `yt-dlp` installed on your machine (e.g., via `brew install yt-dlp`), as the app relies on it to fetch formats.
3. Select the `NewNet` scheme and the `My Mac` destination in Xcode.
4. Press `Cmd + R` to build and run.

### Building a Release DMG
If you want to test the full release pipeline (which bundles `ffmpeg` and creates the installer DMG), you can run our build script:
```bash
./makedmg.sh
```
This will output a finalized DMG inside the `build/` directory.

## 🐛 Found a Bug?

If you find a bug in the source code, you can help us by submitting an issue to our [GitHub Repository](https://github.com/sfdcnaveen/NewNet/issues). Even better, you can submit a Pull Request with a fix!

## 💡 Submitting a Pull Request

1. Create a new branch for your feature or bugfix:
   ```bash
   git checkout -b feature/my-new-feature
   ```
2. Make your changes and commit them with descriptive messages.
3. Push your branch to your fork:
   ```bash
   git push origin feature/my-new-feature
   ```
4. Open a Pull Request against the `main` branch of the original repository.

We will review your changes as soon as possible!
