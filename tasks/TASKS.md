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

