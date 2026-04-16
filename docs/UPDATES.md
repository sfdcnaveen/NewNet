# Auto Update (Sparkle)

NewNet uses [Sparkle](https://sparkle-project.org) for outside-App-Store updates.

## Configure Once

1. Generate an Ed25519 keypair:
   ```bash
   /path/to/Sparkle/bin/generate_keys
   ```
2. Put the printed public key in `SUPublicEDKey` (set in `NewNet.xcodeproj/project.pbxproj` as `INFOPLIST_KEY_SUPublicEDKey`).
3. Update `SUFeedURL` to your hosted `appcast.xml` URL.

## Release Flow

1. Build your release `.dmg` or `.zip`.
2. Sign the archive with Sparkle:
   ```bash
   /path/to/Sparkle/bin/sign_update /path/to/NewNet-1.0.1.dmg
   ```
3. Copy the generated EdDSA signature and file size into `appcast.xml`.
4. Upload the archive to GitHub Releases.
5. Publish/update `appcast.xml` on a static URL (GitHub raw or GitHub Pages).
6. NewNet checks in background at launch and supports manual **Check for Updates…**.

## Unsigned Build Warning (No Apple Developer Program)

If macOS blocks launch for an unsigned app, users can:

- Right-click `NewNet.app` and choose **Open**, then confirm.
- Or go to **System Settings > Privacy & Security** and click **Open Anyway**.

Sparkle still verifies update package integrity with the configured Ed25519 key.
