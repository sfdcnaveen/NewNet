# Submitting NewNet to Homebrew Cask

Getting NewNet on Homebrew Cask is one of the best ways to increase its adoption on macOS. 
Here are the steps to submit NewNet to the official `homebrew-cask` repository once you feel the app is ready for a wider audience.

## 1. Prepare Your Information
You will need the SHA256 checksum of your latest `.dmg` release.
You can get this by running the following command in your terminal on the `NewNet-1.1.7.dmg` file:
```bash
shasum -a 256 /path/to/NewNet-1.1.7.dmg
```

## 2. The Cask Formula (`newnet.rb`)
This is the Ruby script that Homebrew uses to install your app.

```ruby
cask "newnet" do
  version "1.1.7"
  sha256 "INSERT_YOUR_SHA256_HASH_HERE"

  url "https://github.com/sfdcnaveen/NewNet/releases/download/v#{version}/NewNet-#{version}.dmg"
  name "NewNet"
  desc "Lightweight macOS menu-bar download manager powered by yt-dlp"
  homepage "https://github.com/sfdcnaveen/NewNet"

  auto_updates true
  depends_on macos: ">= :sequoia"

  app "NewNet.app"

  zap trash: [
    "~/Library/Application Support/NewNet",
    "~/Library/Caches/NihanviBuilds.NewNet",
    "~/Library/Preferences/NihanviBuilds.NewNet.plist",
  ]
end
```

## 3. How to Submit
1. Go to the [homebrew-cask repository](https://github.com/Homebrew/homebrew-cask).
2. Fork the repository to your own GitHub account.
3. Clone your fork to your computer.
4. Add the `newnet.rb` file to the `Casks/n/` directory inside the repository.
5. Make sure the SHA256 matches your release DMG exactly.
6. Commit your changes with the message: `Add newnet 1.1.7`
7. Push to your fork and open a Pull Request against the main `homebrew-cask` repo.

The Homebrew maintainers will review your PR. Once merged, anyone in the world can install your app by simply typing:
`brew install --cask newnet`
