# iOS MRR Learning Project

An Objective-C iOS project for studying Manual Retain-Release (MRR) with a polished first-launch onboarding flow.

## Current Flow

- Logged-out launch: show `OnboardingViewController` inside a hidden `UINavigationController`
- Onboarding displays the `Culina` brand header, app icon, looping recipe carousel, and auth entry points
- `Sign up with email` pushes a dedicated full-screen sign-up screen with separate fields for first name, last name, email, and password
- `Sign in` pushes a dedicated full-screen sign-in screen with email/password plus a live `Forgot Password?` flow that sends a Firebase reset email and returns to onboarding after confirmation
- `Continue with Google` and `Continue with Apple` remain visible as planned stub actions for the current email-first milestone
- Auth success routes into `HomeViewController`, which shows the active account summary, auth provider, email verification status, and a destructive `Log Out` button inside the screen body
- Logging out clears the auth session and returns the app to onboarding

The recipe detail flow still exists for onboarding exploration and still writes the legacy onboarding-complete flag, but the app root is now determined by the authentication session instead of that flag.

## Project Structure

- `MRR Project/App`
  Root app wiring, `AppDelegate`, and `main.m`
- `MRR Project/Features/Authentication`
  Firebase-backed auth abstraction, auth session model, and error mapping
- `MRR Project/Features/Home`
  Minimal signed-in home screen, email verification summary, and logout flow
- `MRR Project/Resources`
  Shared application resources, including `Info.plist` and `Assets.xcassets`
- `MRR Project/Features/Onboarding`
  Onboarding layout, pushed email auth screens, carousel cells, recipe detail presentation, and auth CTA integration
- `MRR ProjectTests`
  Launch-flow tests plus onboarding, auth, and home interaction regressions

## Tech Stack

### Runtime Stack

| Stack | Used for | Where it shows up | Notes |
| --- | --- | --- | --- |
| `Objective-C` with Manual Retain-Release | Core application language and explicit memory-management practice | Entire app target under `MRR Project/` | The app intentionally keeps `CLANG_ENABLE_OBJC_ARC = NO` so retain/release behavior stays visible and educational. |
| `UIKit` programmatic UI | All screens, navigation, layout, and interactions | `OnboardingViewController`, `MRREmailAuthenticationViewController`, `HomeViewController`, `OnboardingRecipeDetailViewController` | No storyboards or xibs are used anywhere in the app. |
| `UINavigationController` | Logged-out navigation shell | Built in `AppDelegate.m` for the onboarding flow | Keeps sign-up and sign-in as pushed onboarding-owned screens. |
| `Firebase Authentication` | Live email/password authentication and session state | `MRRFirebaseAuthenticationController` and `MRRAuthSession` | This is the live auth provider for the current milestone. It also drives the root flow by checking `currentUser`. |
| `GoogleSignIn` | Prepared provider integration for future Google auth rollout | `AppDelegate.m` URL handling and Firebase auth wiring | The package is already wired into the project, but the onboarding button is intentionally stubbed in the current email-first milestone. |
| `AuthenticationServices` | Planned Apple sign-in integration path | Referenced from onboarding stub behavior | Apple sign-in is intentionally shipped as a structured stub until capability and developer-account setup are ready. |
| `NSUserDefaults` | Small local persistence for recipe-onboarding completion | `OnboardingStateController` | This flag is kept for the recipe detail flow, but it no longer decides the app root. |
| `Assets.xcassets` named colors and images | Shared theming and onboarding visuals | `MRR Project/Resources/Assets.xcassets` | The onboarding UI and auth screens reuse the same asset-backed color system for light and dark appearance. |

### Quality and Tooling Stack

| Stack | Used for | Where it shows up | Notes |
| --- | --- | --- | --- |
| `XCTest` | Unit and UI-structure regression coverage | `MRR ProjectTests/` | Covers root routing, onboarding, pushed auth screens, home summary, logout flow, and carousel behavior. |
| `GitHub Actions` | Remote batch test and code coverage execution | `.github/workflows/ios-tests-coverage.yml` | Runs the iOS test suite with coverage enabled and uploads `.xcresult` plus `xccov` artifacts. |
| `clang-format` | Objective-C formatting | `.clang-format`, `scripts/format-objc.sh`, `.githooks/pre-commit` | Uses Google-based formatting rules with a `ColumnLimit` of `150`. |
| `xcodebuild analyze` | Objective-C static analysis lint pass | `scripts/lint-objc.sh` | Used by the pre-commit hook so analyzer findings block a bad commit. |
| `Git pre-commit hook` | Local guardrail before commits | `.githooks/pre-commit` | Formats staged Objective-C files, re-stages them, then runs the analyzer. |

### Why This Stack Fits the Project

- `Objective-C MRR` keeps the educational goal of the repo intact instead of hiding memory management behind ARC.
- `UIKit` programmatic UI matches the repo's learning focus and keeps onboarding/auth layouts fully inspectable in code.
- `FirebaseAuth` gives a realistic portfolio-grade auth flow without requiring a custom backend from day one.
- The project is structured so later additions like live Google auth, Apple auth, or subscription wiring can plug into the existing auth/session layer instead of forcing a rewrite.

## Onboarding Highlights

- Programmatic onboarding layout with dynamic sizing across common iPhone viewports
- Looping carousel with guarded initial centering to prevent launch-time jump behavior
- Dedicated pushed `Sign Up` and `Sign In` screens that stay under the onboarding feature instead of a shared modal card
- Keyboard-aware auth screens with tap-to-dismiss behavior, scroll insets, and focused-field visibility handling
- Shared backdrop styling with a fade mask so carousel text areas blend into recipe imagery
- Light and dark appearance support through named colors in `Assets.xcassets`
- Stable accessibility identifiers for onboarding auth CTAs, pushed email auth screens, home, carousel cells, and recipe detail content

## Requirements

- Xcode 15+
- macOS with an iOS Simulator runtime

## Build

1. Open [MRR Project.xcodeproj](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/MRR%20Project.xcodeproj).
2. Select the `MRR Project` scheme.
3. If Xcode does not resolve the packages automatically, add these package products manually from Xcode:
   `FirebaseAuth`, `GoogleSignIn`
   with an iOS 12-compatible pairing such as `Firebase 10.29.x` and `GoogleSignIn 7.1.x`.
4. Run on an iOS Simulator.

## Auth Setup

The current milestone is email-first, but the project is already wired to grow into multi-provider auth later.

1. Add `GoogleService-Info.plist` to the `MRR Project` app target so Firebase can initialize correctly.
2. Enable `Email/Password` inside Firebase Authentication. This is the only provider that is live in the current onboarding flow.
3. Enable `Google` and add the `REVERSED_CLIENT_ID` value from `GoogleService-Info.plist` into `CFBundleURLTypes` in [Info.plist](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/MRR%20Project/Resources/Info.plist) if you want the project ready for the later Google rollout.
4. Keep Apple sign-in as stubbed UI until the Apple capability and Developer Program setup are available.

Without Firebase configuration, the app will still build, and the email screens will surface setup-aware auth errors instead of failing silently.

## Tests

The active unit-test coverage focuses on root flow, onboarding presentation, auth entry, and logout behavior:

- logged-out launch shows onboarding
- logged-in launch shows home
- authenticating from onboarding replaces the root with home
- logging out replaces the root with onboarding
- pushed sign-up and sign-in presentation flow
- email auth validation, success flow, and keyboard-aware layout behavior
- Google stub alert presentation
- Apple stub alert presentation
- home email-verification summary and logout confirmation flow
- carousel centering, recentering, and auto-scroll behavior
- recipe detail presentation and `Start Cooking` completion flow
- onboarding accessibility identifiers and carousel backdrop styling

Remote coverage runs automatically through [ios-tests-coverage.yml](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/.github/workflows/ios-tests-coverage.yml). The workflow executes the full `MRR ProjectTests` target on GitHub Actions with code coverage enabled, then uploads the `.xcresult` bundle plus `xccov` text/JSON reports as artifacts.

For a matching local batch run, use:

```bash
./scripts/run-tests-with-coverage.sh
```

## Git Hooks

- The repository includes a tracked pre-commit hook at [.githooks/pre-commit](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/.githooks/pre-commit).
- Install it once per clone with:

```bash
./scripts/install-git-hooks.sh
```

- The hook formats staged Objective-C files with `clang-format` using the tracked [.clang-format](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/.clang-format) rules, which are based on Google style with a `ColumnLimit` of `150`.
- After formatting, the hook re-stages those files and runs `./scripts/lint-objc.sh` before the commit is allowed to proceed.

## VSCode Save Behavior

- Objective-C and Objective-C++ files format automatically on `Save` and `Save All` through `clangd` and the tracked [.clang-format](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/.clang-format) file.
- Syntax diagnostics come from `clangd` directly in the editor and `Problems` panel.
- The heavier project-wide static analyzer remains manual through `./scripts/lint-objc.sh`; it is intentionally not bound to every save.

## Assets

- `MRR Project/Resources/Assets.xcassets` is the active asset catalog for the app icon, named colors, onboarding recipe imagery, and the onboarding brand icon.
- `swift scripts/generate-assets.swift` regenerates the current placeholder assets if they need to be refreshed.

## Notes

- The app target intentionally keeps `CLANG_ENABLE_OBJC_ARC = NO`.
- The app target is pinned back to an iOS 12 deployment target.
- For iOS 12 compatibility, the project should stay on the pre-Firebase-11 line, paired with a GoogleSignIn version that still resolves against `GoogleUtilities 7.x`.
- Sign-up currently collects first and last name for UI completeness, but the live auth session still persists email/password identity only.
- The test target may use ARC-backed XCTest conveniences.
- UI is programmatic; there are no storyboards or xibs.
- Repo-specific agent guidance lives in `AGENTS.md`.
