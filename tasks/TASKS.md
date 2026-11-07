# Tasks

## Task IDs

1. fix-download-progress
   Id: 1-fix-download-progress
   Scope: Fix realtime download progress parsing/display
   Files: NewNet/Services/YTDLPService.swift NewNet/Services/DownloadManager.swift NewNet/Views/DownloadRow.swift NewNet/Models/DownloadItem.swift
   Note: Fixed yt-dlp progress parser fallback for formatted percent/byte fields. make build passed; make test unavailable because scheme has no test action.
   Detail: tasks/details/1-fix-download-progress.md
   Claimed by: CODEX
   Claimed at: 2026-05-31T07:10:29Z
   Done by: CODEX
   Done at: 2026-05-31T07:13:41Z

2. simplify-download-ui
   Id: 2-simplify-download-ui
   Scope: Remove unreliable progress UI and add Liquid Glass downloading/completed states
   Files: NewNet/Views/DownloadRow.swift NewNet/Views/DropdownPanel.swift NewNet/ViewModels/DownloadManagerViewModel.swift
   Note: Removed progress/percentage/pre-completion file-size UI, added indeterminate downloading/completed states, made Add button start default media downloads immediately, and refreshed affected Liquid Glass styling. Build passed; test action unavailable.
   Detail: tasks/details/2-simplify-download-ui.md
   Claimed by: CODEX
   Claimed at: 2026-05-31T09:01:16Z
   Done by: CODEX
   Done at: 2026-05-31T09:04:09Z

3. gif-clip-yt-dlp-privacy
   Id: 3-gif-clip-yt-dlp-privacy
   Scope: Add GIF clip selection, remove anonymous analytics, make yt-dlp opt-in, and verify Sparkle OTA configuration
   Files: NewNet/Models/DownloadItem.swift NewNet/Services/YTDLPService.swift NewNet/Services/DownloadManager.swift NewNet/ViewModels/DownloadManagerViewModel.swift NewNet/Views/DropdownPanel.swift NewNet/Views/SettingsView.swift NewNet/Models/AppSettings.swift NewNet/NewNetApp.swift NewNet.xcodeproj/project.pbxproj NewNet/Info.plist
   Note: Implemented GIF clip selection with 3/5/10 sec presets and bounded from/to values; removed app analytics, endpoint, worker, and telemetry run mode; made yt-dlp opt-in with latest GitHub release lookup; verified Sparkle appcast wiring. make diagnose and make build pass. make test unavailable: scheme has no test action.
   Detail: tasks/details/3-gif-clip-yt-dlp-privacy.md
   Claimed by: CODEX
   Claimed at: 2026-11-07T02:17:11Z
   Done by: CODEX
   Done at: 2026-11-07T02:25:29Z

4. gif-retry-scroll-output
   Id: 4-gif-retry-scroll-output
   Scope: Fix failed-row retry affordance, GIF icon/format presentation, format list scrolling, and GIF-only output
   Files: NewNet/Views/DownloadRow.swift NewNet/Views/DropdownPanel.swift NewNet/ViewModels/DownloadManagerViewModel.swift NewNet/Services/YTDLPService.swift
   Note: Fixed retry affordance, GIF-only format/output handling, and format list scrolling. make diagnose, make build, and make package succeeded; fresh DMG generated at build/NewNet.dmg.
   Detail: tasks/details/4-gif-retry-scroll-output.md
   Claimed by: CODEX
   Claimed at: 2026-11-07T02:37:48Z
   Done by: CODEX
   Done at: 2026-11-07T04:55:24Z

5. gif-postprocess-ytdlp-updater
   Id: 5-gif-postprocess-ytdlp-updater
   Scope: Fix GIF ffmpeg postprocessing, add yt-dlp update control in Settings, and keep yt-dlp out of the app bundle
   Files: NewNet/Services/YTDLPService.swift NewNet/Views/SettingsView.swift NewNet/ViewModels/DownloadManagerViewModel.swift makedmg.sh
   Note: Fixed GIF ffmpeg audio postprocessing, added Settings yt-dlp updater, confirmed yt-dlp is not bundled, and generated fresh DMG.
   Detail: tasks/details/5-gif-postprocess-ytdlp-updater.md
   Claimed by: CODEX
   Claimed at: 2026-11-07T05:05:54Z
   Done by: CODEX
   Done at: 2026-11-07T05:07:54Z

