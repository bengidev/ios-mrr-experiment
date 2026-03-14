# iOS MRR Learning Project

An Objective-C iOS project for studying Manual Retain-Release (MRR) with a polished first-launch onboarding flow.

## Current Flow

- Logged-out launch: show `OnboardingViewController`
- Onboarding displays the `Culina` brand header, app icon, looping recipe carousel, and live auth entry points
- `Sign up with email` opens a dedicated email auth modal with `Create Account` and `Sign In` modes
- `Continue with Google` runs the native Google flow, then exchanges the credential into Firebase Auth
- `Continue with Apple` is intentionally shipped as a structured stub until Apple Developer Program setup is available
- Auth success routes into `HomeViewController`, which shows the active account summary and a destructive `Log Out` button inside the screen body
- Logging out clears the auth session and returns the app to onboarding

The recipe detail flow still exists for onboarding exploration, but the app root is now determined by the authentication session instead of the old onboarding-complete flag.

## Project Structure

- `MRR Project/App`
  Root app wiring, `AppDelegate`, and `main.m`
- `MRR Project/Features/Authentication`
  Firebase-backed auth abstraction, email auth modal, auth session model, and error mapping
- `MRR Project/Features/Home`
  Minimal signed-in home screen and logout flow
- `MRR Project/Resources`
  Shared application resources, including `Info.plist` and `Assets.xcassets`
- `MRR Project/Features/Onboarding`
  Onboarding layout, carousel cells, recipe detail presentation, and auth CTA integration
- `MRR ProjectTests`
  Launch-flow tests plus onboarding, auth, and home interaction regressions

## Onboarding Highlights

- Programmatic onboarding layout with dynamic sizing across common iPhone viewports
- Looping carousel with guarded initial centering to prevent launch-time jump behavior
- Shared backdrop styling with a fade mask so carousel text areas blend into recipe imagery
- Light and dark appearance support through named colors in `Assets.xcassets`
- Stable accessibility identifiers for onboarding auth CTAs, email auth modal, home, carousel cells, and recipe detail content

## Requirements

- Xcode 15+
- macOS with an iOS Simulator runtime

## Build

1. Open [MRR Project.xcodeproj](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/MRR%20Project.xcodeproj).
2. Select the `MRR Project` scheme.
3. If Xcode does not resolve the packages automatically, add these package products manually from Xcode:
   `FirebaseCore`, `FirebaseAuth`, `GoogleSignIn`
   with an iOS 12-compatible pairing such as `Firebase 10.29.x` and `GoogleSignIn 7.1.x`.
4. Run on an iOS Simulator.

## Auth Setup

The new auth flow needs a real Firebase + Google setup before live sign-in works:

1. Add `GoogleService-Info.plist` to the `MRR Project` app target.
2. Enable `Email/Password` and `Google` inside Firebase Authentication.
3. Add the `REVERSED_CLIENT_ID` value from `GoogleService-Info.plist` into `CFBundleURLTypes` in [Info.plist](/Users/beng/Documents/iOS%20Projects/iOS%20MRR%20Learning%20Project/ios_mrr_learning_project/MRR%20Project/Resources/Info.plist).
4. Keep Apple sign-in as stubbed UI until the Apple capability and Developer Program setup are available.

Without that configuration, the app will still build, and the onboarding buttons will surface setup-aware auth errors instead of failing silently.

## Tests

The active unit-test coverage focuses on root flow, onboarding presentation, auth entry, and logout behavior:

- logged-out launch shows onboarding
- logged-in launch shows home
- authenticating from onboarding replaces the root with home
- logging out replaces the root with onboarding
- email auth modal presentation and success flow
- Google account-linking fallback presentation
- Apple stub alert presentation
- home logout confirmation flow
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
- The app target is pinned back to an iOS 12 deployment target.
- For iOS 12 compatibility, the project should stay on the pre-Firebase-11 line, paired with a GoogleSignIn version that still resolves against `GoogleUtilities 7.x`.
- The test target may use ARC-backed XCTest conveniences.
- UI is programmatic; there are no storyboards or xibs.
- Repo-specific agent guidance lives in `AGENTS.md`.
