# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Top Weight is an iOS fitness logger for multiple people: pick a user and exercise, enter a session, save. Built with SwiftUI and SwiftData for on-device persistence, with personal bests, history, evolution charts, and a compare-users chart.

**Target audience / product focus:** families training together, not general multi-tenant fitness tracking. The core scenario is a parent working out alongside their kids and logging everyone's sets in the same session — e.g. a dad doing a workout with his three children needs to quickly register his own weight/reps/series and then each child's, exercise by exercise, without friction. This is why the app is built around fast user-switching (Record screen remembers last user/exercise but makes changing user a one-tap action) and per-user personal bests/history/evolution rather than a single-profile design. Favor UX decisions that keep switching between a small household's worth of profiles fast (few taps, no re-entering shared context like the exercise) over features aimed at gyms, trainers, or large rosters.

## Commands

The project source lives under `TopWeight/` and the Xcode project is generated from `project.yml` via XcodeGen — do not hand-edit `TopWeight.xcodeproj/project.pbxproj`; regenerate it instead.

```bash
# Regenerate the Xcode project after adding/removing/renaming Swift files
xcodegen generate

# Build from the CLI (adjust destination to an installed simulator)
xcodebuild -project TopWeight.xcodeproj -scheme TopWeight -destination 'platform=iOS Simulator,name=iPhone 17' build
```

There is no test target and no linter/formatter config in this repo. When adding new Swift files, always run `xcodegen generate` afterward since `project.yml` globs `TopWeight/**/*.swift` — new files won't appear in Xcode/build until regenerated.

Primary workflow is still opening `TopWeight.xcodeproj` in Xcode 26 and running on a simulator or device (see README's "Device testing" section for on-device signing/trust steps).

## Architecture

### Data model (SwiftData)

Four `@Model` classes in `TopWeight/Models/`, wired into a single `modelContainer` in `TopWeightApp.swift`:

- **User** — profile (name, optional photo or SF Symbol avatar). Cascade-deletes its `WorkoutRecord`s.
- **Exercise** — has an `exerciseType` (`strength`, `distance`, `repsOnly`, `timed`) stored as a raw string (`exerciseTypeRawValue`) with a computed enum wrapper — follow this pattern (raw-value-backed property + computed enum) if adding new persisted enums, since SwiftData models need default values for schema migration. Cascade-deletes its `WorkoutRecord`s.
- **WorkoutRecord** — the actual logged set/session. Not all fields apply to all exercise types (e.g. `distance`/`isIndoor` only for distance exercises, `seconds` only for timed); `weight`/`reps`/`series` are always present but zeroed/unused for types that don't need them.
- **PersonalBest** — one cached row per (user, exercise) pair holding the best-ever stats. This is a derived/denormalized cache, not source of truth — `WorkoutRecord` is authoritative.

**Critical invariant:** `PersonalBest` is never computed ad hoc from the UI layer. Every save, edit, or delete of a `WorkoutRecord` must call `PersonalBest.recompute(modelContext:user:exercise:)` (in `Models/PersonalBest.swift`) for the affected user+exercise pair afterward, or the cached best silently goes stale. The "best" definition depends on `exercise.exerciseType`:
  - strength → max training volume (`weight * reps * series`)
  - distance → max `distance`
  - repsOnly → max `reps * series`
  - timed → max `seconds * series`

  The same per-type metric logic is duplicated as `Exercise.chartMetricValue(for:)` in `Models/Exercise.swift` for the Evolution/Compare charts — when adding a new exercise type or changing how a type's "best"/metric is derived, update both `PersonalBest.recompute` and `chartMetricValue` together, they must stay in sync.

  `PersonalBest.migrateFromExistingRecords` backfills/repairs rows from `WorkoutRecord` history (used opportunistically, e.g. when Tops opens) and is idempotent — it only does work if PersonalBests are missing or have a nil `topDate`.

### Views (`TopWeight/Views/`)

`MainTabView` is the root, a 5-tab `TabView`: Record, History, Tops, Evolution, Compare. Each top-level view is its own file. `Sheets/` holds modal editors (user manager, exercise manager, edit workout). `Components/` holds shared UI (avatar rendering/pickers, stepper fields, the `glassBackground` material helper).

- **RecordView** adapts its input fields to the selected exercise's `exerciseType` (weight/reps/series vs. distance+indoor/outdoor vs. reps-only vs. timed). It remembers the last-selected user and exercise across launches via `UserDefaults` (not SwiftData) — this is intentionally separate from persisted workout data.
- **EvolutionView** and **CompareEvolutionView** both build Swift Charts line charts using `Exercise.chartMetricValue`/`chartYAxisLabel`; Compare overlays multiple users on the same exercise. Picker options are limited to user/exercise combinations that already have at least one `WorkoutRecord`.
- **HistoryView** groups records by day; deleting a row must trigger `PersonalBest.recompute` for that row's user+exercise, since deleting the record that held the current best changes what the best is.

### UI conventions

- Frosted-glass panels use `.ultraThinMaterial` via the `glassBackground(cornerRadius:)` helper (`Components/GlassModifier.swift`), not `.glassEffect()` directly — `.glassEffect()` is iOS 26+ Liquid Glass and is called out in code as an intentional future swap point, not yet standardized on.
- Haptic feedback accompanies selection changes, stepper taps, and saves — preserve this when touching those interactions.
