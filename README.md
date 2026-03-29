# Top Weight

A fast iOS fitness logger for **multiple people**: pick a user and exercise, enter a session, save. Built with **SwiftUI** and **SwiftData** for on-device persistence, with **personal bests**, **history**, and **progress charts**.

---

## Features

### Recording

- **Quick record flow:** Choose user and exercise from menus, adjust values with steppers, tap Save. Remembers **last selected user and exercise** across launches (`UserDefaults`).
- **Four exercise types** (set when you create or edit an exercise):
  - **Strength** — weight (kg, 0.5 kg steps), reps, series.
  - **Distance** — distance in km, **indoor vs outdoor**.
  - **Reps only** — reps and series (no weight).
  - **Timed** — seconds per set and series (e.g. hangs, planks).
- **Stepper fields:** Tap the number to type a value; plus/minus with light haptics.
- **Save feedback:** Medium haptic, brief **“Saved!”** overlay; alert if save fails.

### Users

- **Multiple profiles** with name, optional **camera/photo library** picture, or **preset SF Symbol** avatar.
- **User manager sheet:** add, edit, delete; avatars shown in Record, History, Tops, and Evolution.

### Exercises

- **Exercise manager sheet:** add exercises with a **type** (strength / distance / reps only / timed), edit, delete.
- Record screen **adapts inputs** to the selected exercise type.

### History

- **Chronological list** grouped by day (**Today**, **Yesterday**, formatted dates).
- Rows show **avatar**, user, exercise, summary line, and time.
- **Tap a row** or **swipe → Edit** to change a workout; **swipe → Delete** removes it and **recomputes** that user’s personal best for that exercise.

### Tops (personal bests)

- **Per user**, list of exercises with **best performance** derived from all records:
  - Strength: best **training volume** (kg × reps × series) with breakdown and volume line.
  - Distance: longest **km**.
  - Reps only: highest **total reps** (reps × series).
  - Timed: best **total time** (seconds × series).
- Shows **date** of the qualifying record when available.
- **Migration:** opening Tops can **backfill or repair** `PersonalBest` rows from existing `WorkoutRecord` data.

### Evolution

- **Swift Charts** line chart for one **user + exercise** over time.
- Y-axis metric matches exercise type: **volume (kg)**, **km**, **total seconds**, or **total reps**.
- Pickers limited to users/exercises that already have data.

### Experience and UI

- **Haptic feedback** on selection, steppers, and save.
- **Frosted panels** via `.ultraThinMaterial` (and a `glassBackground` helper); Liquid Glass (`.glassEffect()`) remains an easy swap on iOS 26+ where available.
- **Empty states** on History, Tops, and Evolution with clear copy.
- **Accessibility:** labels and hints on key controls.

---

## Stack and target

| Item | Detail |
|------|--------|
| Platform | iOS **26** |
| Language / UI | **Swift 6**, **SwiftUI** |
| Persistence | **SwiftData** (`User`, `Exercise`, `WorkoutRecord`, `PersonalBest`) |
| Charts | **Swift Charts** (Evolution tab) |
| Project | Xcode **26**; `project.yml` for **XcodeGen** (`xcodegen generate`) |

Primary design goal from the original spec: **minimal friction** — no mandatory onboarding; add users and exercises from the record flow as needed.

---

## Data model (SwiftData)

| Model | Role |
|-------|------|
| **User** | `id`, `name`, `createdAt`, optional `photoData` / `avatarSymbol`; cascade-deletes related records. |
| **Exercise** | `id`, `name`, `exerciseType` (strength, distance, repsOnly, timed), `createdAt`; cascade-deletes related records. |
| **WorkoutRecord** | `weight`, `reps`, `series`, `date`; optional `distance`, `isIndoor`, `seconds`; links to `User` and `Exercise`. |
| **PersonalBest** | Cached best stats per **user + exercise**; updated on save/edit/delete via `PersonalBest.recompute`. |

---

## Repository layout

```
TopWeight/
├── TopWeightApp.swift          # App entry, modelContainer
├── Models/
│   ├── User.swift
│   ├── Exercise.swift          # ExerciseType
│   ├── WorkoutRecord.swift
│   └── PersonalBest.swift
└── Views/
    ├── MainTabView.swift       # Record | History | Tops | Evolution
    ├── RecordView.swift
    ├── HistoryView.swift
    ├── TopsView.swift
    ├── EvolutionView.swift
    ├── Components/             # StepperField, avatars, pickers, glass helper
    └── Sheets/                 # User / exercise / workout edit
```

---

## Building

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if needed.
2. From the repo root: `xcodegen generate`
3. Open `TopWeight.xcodeproj` in Xcode 26, select a destination, **Run**.

---

## Device testing (iPhone)

Deploying to a physical device is the best way to validate haptics, materials, and one-handed layout.

1. Connect the device, trust the computer if prompted.
2. In Xcode: **Product → Destination** → your iPhone.
3. **Product → Run** (⌘R). If needed: **Settings → General → VPN & Device Management** → trust the developer app.

**Tip:** If install fails, confirm the device runs **iOS 26+** and signing uses your **Team** under **Signing & Capabilities**.

---

## Roadmap ideas (not in the app yet)

- iCloud / CloudKit sync  
- Apple Watch companion  
- Social sharing, workout templates, unit toggle (e.g. lbs)  
- Broader use of system **Liquid Glass** APIs where you standardize on `.glassEffect()`

---

## Success criteria (current app)

- Log a workout in a **small number of taps** after users and exercises exist.
- **No forced setup** before the first record.
- **Reliable local data**: SwiftData survives relaunch; personal bests stay consistent after edits and deletes.
- **Visibility:** history by day, bests per user, and a simple **evolution** chart per exercise.
