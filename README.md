# iOS MRR Learning Project

An Objective-C iOS project for studying Manual Retain-Release (MRR) with a polished first-launch onboarding flow.

## Current Flow

- First launch: show `OnboardingViewController`
- Onboarding displays the `Culina` brand header, app icon, looping recipe carousel, and auth CTA placeholders
- Tapping a carousel card presents `OnboardingRecipeDetailViewController`
- Tapping `Start Cooking` in the detail modal completes onboarding and persists a flag in `NSUserDefaults`
- Next launches: continue showing `OnboardingViewController`

The onboarding screen is no longer a static placeholder. It now carries the active app experience.

## Project Structure

- `MRR Project/App`
  Root app wiring, `AppDelegate`, and `main.m`
- `MRR Project/Resources`
  Shared application resources, including `Info.plist` and `Assets.xcassets`
- `MRR Project/Features/Onboarding`
  First-launch state persistence, onboarding layout, carousel cells, and recipe detail presentation
- `MRR ProjectTests`
  Launch-flow tests plus onboarding layout and interaction regressions

## Onboarding Highlights

- Programmatic onboarding layout with dynamic sizing across common iPhone viewports
- Looping carousel with guarded initial centering to prevent launch-time jump behavior
- Shared backdrop styling with a fade mask so carousel text areas blend into recipe imagery
- Light and dark appearance support through named colors in `Assets.xcassets`
- Stable accessibility identifiers for root onboarding UI, carousel cells, and recipe detail content

## Requirements

- Xcode 15+
- macOS with an iOS Simulator runtime

## Build

1. Open [MRR Project.xcodeproj](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/MRR%20Project.xcodeproj).
2. Select the `MRR Project` scheme.
3. Run on an iOS Simulator.

## Tests

The active unit-test coverage focuses on both root flow and onboarding presentation details:

- first launch shows onboarding
- finishing onboarding persists the completion flag
- returning users still land on onboarding
- the app no longer routes into a tab-bar-based learning flow
- carousel centering, recentering, and auto-scroll behavior
- recipe detail presentation and `Start Cooking` completion flow
- onboarding accessibility identifiers and carousel backdrop styling

## VSCode Save Behavior

- Objective-C and Objective-C++ files format automatically on `Save` and `Save All` through `clangd` and the tracked [.clang-format](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/.clang-format) file.
- Syntax diagnostics come from `clangd` directly in the editor and `Problems` panel.
- The heavier project-wide static analyzer remains manual through `./scripts/lint-objc.sh`; it is intentionally not bound to every save.

## Assets

- `MRR Project/Resources/Assets.xcassets` is the active asset catalog for the app icon, named colors, onboarding recipe imagery, and the onboarding brand icon.
- `swift scripts/generate-assets.swift` regenerates the current placeholder assets if they need to be refreshed.

## Notes

- The app target intentionally keeps `CLANG_ENABLE_OBJC_ARC = NO`.
- The test target may use ARC-backed XCTest conveniences.
- UI is programmatic; there are no storyboards or xibs.
- Repo-specific agent guidance lives in `AGENTS.md`.
