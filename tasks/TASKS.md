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

6. update-notifications-network-monitoring
   Id: 6-update-notifications-network-monitoring
   Scope: Sparkle update state, native network monitoring, speed test, and dashboard integration
   Files: NewNet/Services/UpdateManager.swift,NewNet/Services/NetworkSpeedMonitor.swift,NewNet/Services/SpeedTestService.swift,NewNet/Views/DropdownPanel.swift,NewNet/Views/SettingsView.swift,NewNetTests
   Note: Implemented shared Sparkle update state with launch/foreground/periodic checks, native notifications, dismiss/postpone handling, 64-bit interface monitoring, history graph, active-interface status, opt-in nettop process attribution, Cloudflare speed test with persisted results, dashboard/settings integration, and NewNetTests. make diagnose/build/test pass; 2 tests pass; existing Info.plist warning remains.
   Detail: tasks/details/6-update-notifications-network-monitoring.md
   Claimed by: CODEX
   Claimed at: 2026-11-07T05:39:37Z
   Done by: CODEX
   Done at: 2026-11-07T05:53:30Z

7. fix-utilities-keepawake-quit-scroll
   Id: 7-fix-utilities-keepawake-quit-scroll
   Scope: Utilities
   Files: NewNet/Services/Utilities/KeepAwakeService.swift NewNet/Services/Utilities/QuitOnCloseService.swift NewNet/Services/Utilities/ScrollInverterService.swift NewNet/Views/Utilities/UtilitiesDashboardView.swift
   Note: Finished clamshell keep-awake via pmset -a, AXObserver quit-on-close, and physical mouse scroll inversion; make diagnose, make build, and make test all succeed with zero warnings.
   Detail: tasks/details/7-fix-utilities-keepawake-quit-scroll.md
   Claimed by: CODEX
   Claimed at: 2026-11-18T05:55:51Z
   Done by: CODEX
   Done at: 2026-11-18T06:05:36Z

8. settings-modernization-tab-visibility
   Id: 8-settings-modernization-tab-visibility
   Scope: Settings UI modernization and tab visibility controls
   Files: NewNet/App/StatusBarController.swift NewNet/Models/AppSettings.swift NewNet/Views/SettingsView.swift NewNet/Views/DropdownPanel.swift
   Note: Completed Settings UI modernization, circular back button, tab visibility toggle, and test suite verification; make diagnose, make build, and make test all pass.
   Detail: tasks/details/8-settings-modernization-tab-visibility.md
   Claimed by: GEMINI
   Claimed at: 2026-11-20T05:39:00Z
   Done by: GEMINI
   Done at: 2026-11-20T05:47:57Z

9. design-polish-settings-media-menubar
   Id: 9-design-polish-settings-media-menubar
   Scope: Settings declutter, sleek media player redesign, and menu bar coffee indicator
   Files: NewNet/Views/SettingsView.swift NewNet/Views/MusicDashboardView.swift NewNet/Views/MenuBarSpeedIndicator.swift NewNet/App/StatusBarController.swift
   Note: Design polish complete: Settings declutter, sleek media player redesign, menu bar coffee indicator; make diagnose, make build, and make test all pass.
   Detail: tasks/details/9-design-polish-settings-media-menubar.md
   Claimed by: GEMINI
   Claimed at: 2026-11-20T06:30:48Z
   Done by: GEMINI
   Done at: 2026-11-20T06:40:14Z

10. fix-duplicate-panel-size-slider-icons
   Id: 10-fix-duplicate-panel-size-slider-icons
   Scope: Fix duplicate panel size label and upgrade slider symbols
   Files: NewNet/Views/SettingsView.swift
   Note: Fixed duplicate Panel size label and upgraded slider icons to crisp white Apple-style boxes
   Detail: tasks/details/10-fix-duplicate-panel-size-slider-icons.md
   Claimed by: GEMINI
   Claimed at: 2026-11-20T06:53:02Z
   Done by: GEMINI
   Done at: 2026-11-20T06:56:36Z

11. fix-upside-down-coffee-icon-orange
   Id: 11-fix-upside-down-coffee-icon-orange
   Scope: MenuBarSpeedIndicator
   Files: NewNet/Views/MenuBarSpeedIndicator.swift
   Note: Fixed upside-down coffee icon rendering with respectFlipped: true and changed color to systemOrange; all builds and 41 tests pass
   Detail: tasks/details/11-fix-upside-down-coffee-icon-orange.md
   Claimed by: CODEX
   Claimed at: 2026-11-20T06:59:42Z
   Done by: CODEX
   Done at: 2026-11-20T07:00:17Z

12. fix-ytdlp-first-install-auto-bootstrap-updater
   Id: 12-fix-ytdlp-first-install-auto-bootstrap-updater
   Scope: YTDLPService, SettingsView, makedmg
   Files: NewNet/Services/YTDLPService.swift NewNet/Views/SettingsView.swift makedmg.sh
   Note: Bundled yt-dlp binary in release DMG, added automatic bootstrap fallback on first use, stripped quarantine attributes, added background preflight, and added Media Downloader Engine (yt-dlp) manager in Settings. All 43 tests pass.
   Detail: tasks/details/12-fix-ytdlp-first-install-auto-bootstrap-updater.md
   Claimed by: CODEX
   Claimed at: 2026-11-20T14:02:10Z
   Done by: CODEX
   Done at: 2026-11-20T14:10:35Z

13. fix-keep-awake-lid-closed-modes
   Id: 13-fix-keep-awake-lid-closed-modes
   Scope: Utilities/KeepAwakeService
   Files: NewNet/Services/Utilities/KeepAwakeService.swift
   Note: Fixed Keep Awake assertions: display assertion always active when Keep Awake is enabled so screen stays awake unless lid is closed; lid-close assertion & pmset disablesleep only active when lid-closed mode is enabled. All 44 unit tests pass, make diagnose and make package pass.
   Detail: tasks/details/13-fix-keep-awake-lid-closed-modes.md
   Claimed by: CODEX
   Claimed at: 2026-11-23T08:44:43Z
   Done by: CODEX
   Done at: 2026-11-23T08:50:44Z

14. remove-ffmpeg-x64-apple-silicon-only
   Id: 14-remove-ffmpeg-x64-apple-silicon-only
   Scope: Build/Packaging & Documentation
   Files: makedmg.sh README.md NewNet/Services/YTDLPService.swift
   Note: Removed ffmpeg-x64 from packaging scripts and bundle, dropping DMG size from 83.2 MB down to 58.5 MB (-25 MB). Updated README.md with Apple Silicon (arm64) badge and requirements callout.
   Detail: tasks/details/14-remove-ffmpeg-x64-apple-silicon-only.md
   Claimed by: CODEX
   Claimed at: 2026-11-23T09:18:08Z
   Done by: CODEX
   Done at: 2026-11-23T09:20:30Z

15. audio-cutter-mmss
   Id: 15-audio-cutter-mmss
   Scope: DownloadManager & UI
   Files: NewNet/ViewModels/DownloadManagerViewModel.swift NewNet/Views/DropdownPanel.swift NewNet/Services/YTDLPService.swift NewNetTests/YTDLPServiceHostTests.swift
   Note: Implemented Audio Cutter with MM:SS time range selection, dynamic duration pill, preset chips, and yt-dlp section cutting arguments. All 46 tests pass, make diagnose and package pass.
   Detail: tasks/details/15-audio-cutter-mmss.md
   Claimed by: CODEX
   Claimed at: 2026-11-23T11:06:02Z
   Done by: CODEX
   Done at: 2026-11-23T11:14:56Z

16. youtube-bot-check-cookies
   Id: 16-youtube-bot-check-cookies
   Scope: Feature/UI
   Files: NewNet/Models/AppSettings.swift,NewNet/Services/YTDLPService.swift,NewNet/Views/SettingsView.swift,NewNet/Views/DropdownPanel.swift
   Note: Added browser cookies support including Safari with Full Disk Access detection, humanized YouTube bot check and extractor errors, enhanced error UI cards with 1-click action buttons, passed 50 unit tests, built NewNet.dmg
   Detail: tasks/details/16-youtube-bot-check-cookies.md
   Claimed by: CODEX
   Claimed at: 2026-11-23T11:31:29Z
   Done by: CODEX
   Done at: 2026-11-23T11:49:54Z

17. m4r-iphone-ringtone-support
   Id: 17-m4r-iphone-ringtone-support
   Scope: Feature/UI
   Files: NewNet/Services/YTDLPService.swift,NewNet/ViewModels/DownloadManagerViewModel.swift,NewNet/Views/DropdownPanel.swift,NewNetTests/NetworkMonitoringTests.swift
   Note: Added native M4R iPhone ringtone support with 256k AAC, format selector, and tests
   Detail: tasks/details/17-m4r-iphone-ringtone-support.md
   Claimed by: CODEX
   Claimed at: 2026-11-23T12:58:05Z
   Done by: CODEX
   Done at: 2026-11-23T13:08:07Z

