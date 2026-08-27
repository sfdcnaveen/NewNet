# NewNet Agent Rules

NewNet is an existing native macOS SwiftUI menu-bar download manager. Treat this as AppCreator adopt mode: do not regenerate the Xcode project, do not replace the checked-in Sparkle package, and do not add third-party UI frameworks.

The application should feel like a first-class native macOS product. Prioritize Apple's platform conventions, thoughtful interaction design, visual hierarchy, accessibility, and purposeful motion over decorative UI.

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
- Preserve existing menu-bar utility behavior and Sparkle update support.
- Follow the repository Liquid Glass direction for new UI: layered glass surfaces, adaptive light/dark behavior, Dynamic Type, accessibility, native SwiftUI controls, appropriate material usage, and platform-consistent spacing and typography.
- Do not introduce non-Liquid-Glass replacement UI when modifying visible app surfaces.
- Prefer native macOS patterns over web-inspired UI patterns.
- Avoid unnecessarily rounded cards, excessive gradients, excessive shadows, or decorative effects that make the application feel unlike macOS.
- Do not imitate iOS UI when a macOS-native pattern is more appropriate.
- Respect system appearance, reduced transparency, increased contrast, Dynamic Type, and accessibility settings.

# Design Engineering Rules

For every task that changes or creates a visible UI surface, apply the following design skills.

## 1. emil-design-eng

Use `emil-design-eng` as the primary design-engineering framework for UI decisions.

Before implementing a significant UI change:

1. Understand the existing visual language.
2. Identify the user's primary task.
3. Establish information hierarchy.
4. Identify the most important action and supporting actions.
5. Define spacing, typography, alignment, and component relationships.
6. Prefer reusable design primitives over one-off styling.
7. Preserve consistency with existing NewNet surfaces.
8. Consider empty, loading, success, error, disabled, hover, focus, and pressed states.
9. Consider normal and edge-case content lengths.
10. Validate the result at realistic macOS window sizes.

### Design principles

- Design for clarity before decoration.
- Every visual element should have a functional reason.
- Reduce unnecessary cognitive load.
- Prefer progressive disclosure when information is secondary.
- Maintain strong visual hierarchy.
- Use whitespace intentionally.
- Align related content to a consistent visual grid.
- Avoid arbitrary hardcoded spacing when a reusable design token is appropriate.
- Avoid introducing new visual patterns when an existing component can be extended.
- Prefer composition and reusable SwiftUI components.

### Component quality

New UI should:

- Have clear component boundaries.
- Use reusable SwiftUI views.
- Avoid duplicated styling logic.
- Prefer environment-driven configuration where appropriate.
- Support accessibility labels and hints.
- Support keyboard and pointer interaction.
- Handle dynamic content gracefully.
- Avoid layout assumptions based on a single window size.

## 2. apple-design

Use `apple-design` whenever designing or reviewing visible application experiences.

The goal is to make NewNet feel like a polished native macOS application rather than a generic cross-platform interface.

### Apple design principles

Prioritize:

- Clarity
- Deference
- Depth
- Consistency
- Familiar interaction patterns
- Strong typography
- Appropriate whitespace
- Content-first layouts
- Subtle visual hierarchy
- Contextual controls
- Native macOS behavior

### macOS interaction conventions

Prefer native controls and patterns where appropriate:

- `Button`
- `Menu`
- `MenuBarExtra`
- `Toolbar`
- `NavigationSplitView`
- `List`
- `Table`
- `Form`
- `Popover`
- `Sheet`
- `Alert`
- `ConfirmationDialog`
- `ProgressView`
- `Toggle`
- `Picker`
- `TextField`
- `SecureField`
- `ScrollView`

Do not replace native controls with custom equivalents unless there is a clear product/design reason.

### Liquid Glass

When modifying existing Liquid Glass surfaces:

- Preserve translucency and material hierarchy.
- Use depth to distinguish layers.
- Avoid excessive opacity.
- Ensure text remains readable over dynamic backgrounds.
- Do not use glass merely as decoration.
- Maintain appropriate contrast in both light and dark appearance.
- Avoid stacking too many translucent surfaces.
- Ensure controls remain visually discoverable.

### Typography

- Prefer system typography where appropriate.
- Use semantic text styles instead of arbitrary font sizes.
- Preserve Dynamic Type behavior.
- Establish clear hierarchy between title, subtitle, metadata, and supporting information.
- Avoid excessive bold text.
- Do not use decorative fonts unless explicitly required.

### Color

- Prefer semantic/system colors where appropriate.
- Support light and dark appearance.
- Do not hardcode colors when an adaptive system color is available.
- Use accent color intentionally.
- Ensure sufficient contrast.
- Avoid using color as the only mechanism for communicating state.

### Accessibility

Every new interactive UI should consider:

- VoiceOver
- keyboard navigation
- focus visibility
- Dynamic Type
- reduced motion
- increased contrast
- reduced transparency
- pointer interaction
- appropriate hit targets
- meaningful accessibility labels and hints

# Animation & Motion Rules

## 3. review-animations

Use `review-animations` whenever adding, modifying, or reviewing animation and transition behavior.

Animations must communicate state, hierarchy, continuity, cause-and-effect, or meaningful feedback.

Do not add animation simply because an interface feels empty.

### Motion goals

Animations should feel:

- purposeful
- responsive
- native to macOS
- subtle
- interruptible
- spatially coherent
- performant

Avoid:

- excessive bouncing
- unnecessary scaling
- long transitions
- constant movement
- attention-grabbing effects
- animation on every element
- animations that delay task completion

### Animation hierarchy

Use motion to communicate:

1. State changes
2. Hierarchy changes
3. Insertion/removal
4. Navigation
5. Feedback
6. Secondary delight

Primary interactions should remain fast and predictable.

### Transitions

When appropriate, use:

- opacity
- subtle movement
- scale
- blur/material changes
- matched spatial movement
- container expansion
- progressive disclosure

Prefer small spatial changes over large dramatic movement.

### Spring behavior

Use spring animation only when it improves the physical relationship between UI elements.

Tune:

- stiffness
- damping
- response
- blend duration

Do not blindly reuse one spring configuration throughout the application.

### Animation timing

As a general guideline:

- Micro feedback: approximately 100–200ms
- Small state transitions: approximately 150–300ms
- Larger layout transitions: approximately 250–450ms

Adjust based on interaction complexity rather than following these values rigidly.

### Reduced Motion

Every meaningful animation must have an appropriate reduced-motion behavior.

When reduced motion is enabled:

- remove unnecessary movement
- prefer opacity or instantaneous state changes
- avoid continuous animations
- preserve the functional meaning of the transition

Use the appropriate SwiftUI accessibility/environment APIs rather than creating a custom preference system unnecessarily.

# UI Review Requirements

Before considering a UI task complete, review the implementation against:

### Visual hierarchy

- Is the primary action immediately obvious?
- Are secondary actions visually subordinate?
- Is the information hierarchy clear?
- Does the interface feel balanced?

### Layout

- Does the layout work at narrow and wide window sizes?
- Does content wrap correctly?
- Are controls clipped?
- Are there unnecessary empty areas?
- Are spacing values consistent?
- Does the interface remain usable when content grows?

### Interaction

- Are hover states useful?
- Are pressed states clear?
- Is keyboard interaction supported?
- Is focus visible?
- Are destructive actions appropriately communicated?
- Are loading and disabled states understandable?

### Motion

- Does animation communicate something?
- Is it fast enough?
- Does it feel native?
- Does it interfere with interaction?
- Does reduced motion behave correctly?

### Accessibility

- Can the entire experience be used with VoiceOver?
- Can controls be reached using the keyboard?
- Are accessibility labels meaningful?
- Does Dynamic Type work?
- Does increased contrast remain readable?
- Does reduced transparency remain usable?

### Appearance

Test:

- Light mode
- Dark mode
- Increased contrast
- Reduced transparency
- Reduced motion

# Design System Rules

Establish and reuse design tokens where practical.

Tokens should cover:

- spacing
- typography
- corner radius
- control height
- icon sizing
- semantic colors
- border treatments
- elevation/materials
- animation timing
- animation curves

Avoid creating multiple visually equivalent values for the same purpose.

If several surfaces require the same spacing or corner radius, define and reuse a shared value rather than introducing independent constants.

# Component Rules

Before creating a new component:

1. Search the existing codebase for an equivalent component.
2. Determine whether the existing component can be extended.
3. Reuse existing design tokens.
4. Follow established naming conventions.
5. Keep business logic separate from presentation logic where practical.

New components should be:

- focused
- reusable
- accessible
- testable
- composable
- consistent with existing UI

Avoid creating components solely to wrap a single SwiftUI modifier unless the abstraction provides meaningful reuse.

# Existing App Behavior

Never sacrifice existing NewNet functionality for visual improvements.

Preserve:

- menu-bar behavior
- download management
- download state handling
- Sparkle updates
- existing navigation
- existing persistence
- existing networking behavior
- existing error handling
- existing background operations

UI improvements must not introduce regressions in application behavior.

# Build And Optimization Rules

- Keep builds reproducible and agent-isolated under `build/`.
- Prefer `make build` over ad hoc `xcodebuild` commands.
- Keep Debug builds incremental and unoptimized.
- Keep Release builds whole-module optimized.
- Use local module/package caches through `scripts/xcbuild.sh`.
- Treat build setting changes as project changes: inspect first, explain the risk, and verify with a build.
- Avoid unnecessary dependencies.
- Avoid expensive view recomputation.
- Avoid animations that cause unnecessary rendering work.
- Avoid continuously updating views when the UI does not require it.
- Prefer lazy containers for large collections where appropriate.
- Verify UI changes do not introduce obvious performance regressions.

# Task Workflow

- Use `scripts/task.sh` as the single task entrypoint.
- Use `AGENT_NAME` when claiming and completing work.
- Keep committed task backlog in `tasks/TASKS.md`.
- Put deeper task notes in `tasks/details/<id>.md`.

Task workflow commands:

- `scripts/task.sh plan <slug> --scope "..." --files "..." --note "..."`
- `AGENT_NAME=CODEX scripts/task.sh claim <number|id> --note "Starting work"`
- `AGENT_NAME=CODEX scripts/task.sh done <number|id> --note "Finished + build/test status"`
- `scripts/task.sh summary --last-24h`

# UI Task Workflow

For any task involving UI/UX changes:

### Step 1 — Inspect

Before changing code:

- Inspect the existing implementation.
- Identify reusable components.
- Identify existing design tokens.
- Identify existing animations.
- Identify accessibility behavior.
- Identify Liquid Glass usage.
- Understand the affected user flow.

### Step 2 — Review

Apply:

- `emil-design-eng`
- `apple-design`
- `review-animations`

Explicitly consider:

- visual hierarchy
- layout
- interaction
- accessibility
- motion
- platform conventions
- performance

### Step 3 — Implement

- Reuse existing components and tokens.
- Prefer native SwiftUI.
- Keep the implementation simple.
- Avoid unnecessary dependencies.
- Preserve existing behavior.

### Step 4 — Validate

Validate:

- Light mode
- Dark mode
- Different window sizes
- Keyboard navigation
- VoiceOver where relevant
- Reduced motion
- Increased contrast
- Reduced transparency
- Hover/pressed/focus states
- Loading/error/empty states

### Step 5 — Build

Run:

```bash
make diagnose
make build
```

If the UI change affects runtime behavior, also run the appropriate tests.

### Step 6 — Report

When completing the task, summarize:

- What changed
- Why the design changed
- Components affected
- Accessibility considerations
- Animation/motion changes
- Performance considerations
- Build/test status

# Local Skill References

Use these installed references when a task calls for them:

- AppCreator adopt mode: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/appcreator/app-creator/SKILL.md`
- xcode-makefiles: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/appcreator/xcode-makefiles/SKILL.md`
- simple-tasks: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/appcreator/simple-tasks/SKILL.md`
- OpenAI build-macos-apps: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/official-openai/build-macos-apps/README.md`
- SwiftLee build optimization: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/swiftlee/Xcode-Build-Optimization-Agent-Skill/README.md`
- Merowing rules: `/Users/nn/Documents/Codex/2026-05-31/set-up-my-codex-environment-with/agent-skills/merowing/general.md`

## Design Skills

The following design skills must be applied to relevant UI/UX tasks:

- `emil-design-eng`
  - Use for design engineering, component architecture, hierarchy, spacing, interaction design, and UI quality.

- `apple-design`
  - Use for native Apple platform design, Liquid Glass, typography, accessibility, adaptive appearance, and macOS interaction conventions.

- `review-animations`
  - Use whenever reviewing or implementing animations, transitions, loading states, hover/press feedback, or motion systems.

When these skills are available as local skill files, inspect and follow their instructions before implementing the relevant task.

# Dependency Rules

- Do not add third-party UI frameworks.
- Do not replace SwiftUI with another UI framework.
- Do not add a dependency solely to implement an interaction that SwiftUI or Apple frameworks already provide.
- Prefer Apple frameworks and existing project dependencies.
- Preserve the checked-in Sparkle package.

# Safety And Change Management

- Do not make unrelated refactors while implementing a UI task.
- Do not modify project configuration unless necessary.
- Do not regenerate the Xcode project.
- Do not replace existing packages.
- Do not remove working functionality simply to simplify the UI.
- Keep changes focused and reversible.
- If a requested visual change conflicts with an existing product behavior, preserve behavior and explain the trade-off.
- If a design decision has multiple valid approaches, prefer the option that is most native to macOS and consistent with the existing NewNet design language.

# Definition Of Done

A UI task is complete only when:

- The implementation matches the intended design.
- Existing NewNet behavior still works.
- The UI is responsive to realistic macOS window sizes.
- Light and dark appearances are supported.
- Accessibility has been considered.
- Keyboard/focus behavior is usable.
- Reduced-motion behavior is implemented where applicable.
- Animations are purposeful and performant.
- Existing design tokens/components are reused where possible.
- No unnecessary third-party UI dependencies were introduced.
- `make diagnose` passes.
- `make build` passes.
- The final implementation is consistent with:
  - `emil-design-eng`
  - `apple-design`
  - `review-animations`
