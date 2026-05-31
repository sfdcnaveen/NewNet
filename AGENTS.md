# NewNet Agent Rules

NewNet is an existing native macOS SwiftUI menu-bar download manager. Treat this as AppCreator adopt mode: do not regenerate the Xcode project, do not replace the checked-in Sparkle package, and do not add third-party UI frameworks.

## Project Defaults

- Platform: macOS only unless a task explicitly adds another target.
- Xcode project: `NewNet.xcodeproj`.
- Scheme: `NewNet`.
- Primary build path: `make diagnose`, then `make build`.
- Run path: `./script/build_and_run.sh` or the Codex `Run` action.
- Distribution path: `make package` delegates to `./makedmg.sh`.

## Apple Platform Rules

- Use SwiftUI and Apple frameworks first.
- Keep dependencies in Swift Package Manager.
- Preserve the existing menu-bar utility behavior and Sparkle update support.
- Follow the repository Liquid Glass direction for new UI: layered glass surfaces, adaptive light/dark behavior, dynamic type, accessibility, and native SwiftUI controls.
- Do not introduce non-Liquid-Glass replacement UI when modifying visible app surfaces.

## Build And Optimization Rules

- Keep builds reproducible and agent-isolated under `build/`.
- Prefer `make build` over ad hoc `xcodebuild` commands.
- Keep Debug builds incremental and unoptimized.
- Keep Release builds whole-module optimized.
- Use local module/package caches through `scripts/xcbuild.sh`.
- Treat build setting changes as project changes: inspect first, explain the risk, and verify with a build.

## Task Workflow

- Use `scripts/task.sh` as the single task entrypoint.
- Use `AGENT_NAME` when claiming and completing work.
- Keep committed task backlog in `tasks/TASKS.md`.
- Put deeper task notes in `tasks/details/<id>.md`.

Task workflow commands:

- `scripts/task.sh plan <slug> --scope "..." --files "..." --note "..."`
- `AGENT_NAME=CODEX scripts/task.sh claim <number|id> --note "Starting work"`
- `AGENT_NAME=CODEX scripts/task.sh done <number|id> --note "Finished + build/test status"`
- `scripts/task.sh summary --last-24h`

## Local Skill References

Use these installed references when a task calls for them:

- AppCreator adopt mode: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/appcreator/app-creator/SKILL.md`
- xcode-makefiles: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/appcreator/xcode-makefiles/SKILL.md`
- simple-tasks: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/appcreator/simple-tasks/SKILL.md`
- OpenAI build-macos-apps: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/official-openai/build-macos-apps/README.md`
- SwiftLee build optimization: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/swiftlee/Xcode-Build-Optimization-Agent-Skill/README.md`
- Merowing rules: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/merowing/general.md`
