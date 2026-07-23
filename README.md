<div align="center">

# Training La

**A local-first iOS app for planning, logging, and reviewing your strength training.**

![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white)
![License](https://img.shields.io/badge/License-Apache--2.0-blue)

</div>

---

Training La helps you schedule what to train, log every set as you go, and look back at how a lift has
progressed over time — no account, no backend, no network required. All data lives on-device.

## Features

- **Exercise library** — build your own catalog of movements (name, muscle group, equipment) and
  reusable workout templates, and apply them across schedules and sessions.
- **Templates** — save reusable workout blueprints (no date, always editable); apply one when you
  start training to spin up that day's plan. (Recurring schedules — e.g. push/pull/legs — are planned.)
- **Scheduling** — plan a workout for a specific date, from a template or by hand.
- **Workout tracking** — log weight and reps set-by-set, with a built-in rest timer and an
  exercise-complete prompt when a planned exercise is done. Works equally well for a scheduled
  workout or an unplanned one.
- **History** — browse past sessions by date, or drill into a single exercise to see every set
  you've ever logged for it.
- **Theme** — light / dark / follow system.

## Project status

This is a **v0, feasibility-stage, single-user, local-only build**: no login, no sync, no remote
API. The goal is to validate the core loop — *define an exercise → (optionally) schedule it → log
it set-by-set → review the history* — before any backend work begins. See
[`PROJECT_PLAN.md`](./PROJECT_PLAN.md) for the full roadmap (a Go backend with account sync is
planned for v1).

## Architecture

Training La follows **Clean Architecture**, split into one local Swift Package per domain
(`Spec`, `Plan`, `Training`, `History`, `Settings`), each with its own `Domain` / `Data` /
`Presentation` layers. The domain layer is plain Swift with no framework imports, so business
logic can be unit-tested without SwiftUI, SwiftData, or a simulator. See
[`ARCHITECTURE.md`](./ARCHITECTURE.md) for the full breakdown, including the data model and
cross-domain boundaries.

## Tech stack

| | |
|---|---|
| Language | Swift 6.0 |
| UI | SwiftUI |
| Persistence | SwiftData (on-device) |
| Modules | Local Swift Packages (SPM), one per domain |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml` → `.xcodeproj`, not checked into git) |
| Tests | [Swift Testing](https://developer.apple.com/documentation/testing) |

## Getting started

**Requirements:** Xcode 16+ (the full app, not just the Command Line Tools — `swift test` needs the
bundled Testing framework), and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
git clone git@github.com:wly-p/training-la.git
cd training-la
xcodegen generate
open TrainingLa.xcodeproj
```

Then pick the **TrainingLa-Dev** scheme and run.

## Testing

```sh
make test-unit    # unit tests for all 6 packages (swift test, no simulator needed)
make test-uitest  # UI tests, on a simulator
make test-e2e     # against a real backend — not applicable yet in v0, placeholder for now
make test         # test-unit + test-uitest
```

`DEVICE` and `HEADLESS` (which simulator to use, and whether to show its window) are configurable —
see [`Config.xcconfig`](./Config.xcconfig). More detail on how unit tests and UI tests are wired up
in Xcode lives in [`ARCHITECTURE.md`](./ARCHITECTURE.md#測試).

## License

[Apache-2.0](./LICENSE)
