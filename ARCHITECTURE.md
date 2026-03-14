# Architecture Analysis

## Scope

This document reflects the current application after the old `MainMenu` screen was removed and the onboarding flow evolved into an email-first authentication entry point.

The user-facing runtime now contains four main screens:

- `OnboardingViewController` as the logged-out root
- `MRREmailAuthenticationViewController` pushed in either `Sign Up` or `Sign In` mode
- `HomeViewController` as the authenticated root
- `OnboardingRecipeDetailViewController` as a modal recipe-exploration step

The app shell also owns one shared asset catalog:

- `Resources/Assets.xcassets` for `AppIcon`, `OnboardingAppIcon`, named colors, and onboarding recipe imagery

## Executive Summary

The application is a small state-aware iOS app centered on a polished onboarding surface, a Firebase-backed authentication session, and a retained recipe-exploration flow.

`AppDelegate` is the composition root. On launch, it configures Firebase when possible, asks the authentication controller for a current session, and installs either the onboarding navigation stack or the signed-in home screen as the window root. `OnboardingViewController` owns the branded onboarding UI, looping carousel, auth CTA entry points, and recipe-detail presentation. Its email CTAs push `MRREmailAuthenticationViewController`, which handles separate full-screen sign-up and sign-in layouts while keeping that UI under the onboarding feature. `HomeViewController` shows the active session summary, including provider and `emailVerified` state, and delegates sign-out back to the app root.

`OnboardingStateController` still persists whether the recipe flow reached `Start Cooking`, but that flag is now separate from launch routing. The root flow is driven by the auth session instead.

## Top-Level Module Map

```mermaid
flowchart TB
  main["App/main.m<br/>manual NSAutoreleasePool + UIApplicationMain"]
  plist["Resources/Info.plist"]
  assets["Resources/Assets.xcassets"]
  app["App/AppDelegate<br/>composition root + root flow"]
  auth["Features/Authentication/MRRFirebaseAuthenticationController"]
  session["Features/Authentication/MRRAuthSession"]
  onboardingState["Features/Onboarding/Data/OnboardingStateController"]
  onboardingVC["Features/Onboarding/Presentation/OnboardingViewController"]
  emailAuthVC["Features/Onboarding/Presentation/MRREmailAuthenticationViewController"]
  onboardingDetailVC["Features/Onboarding/Presentation/OnboardingRecipeDetailViewController"]
  carouselCell["Features/Onboarding/Presentation/OnboardingRecipeCarouselCell"]
  homeVC["Features/Home/HomeViewController"]
  tests["MRR ProjectTests/AppLaunchFlowTests + OnboardingAuthFlowTests + HomeViewControllerTests + OnboardingViewControllerTests"]

  main --> app
  plist --> app
  plist --> auth
  assets --> onboardingVC
  assets --> emailAuthVC
  assets --> onboardingDetailVC
  assets --> carouselCell
  app --> auth
  auth --> session
  app --> onboardingState
  app --> onboardingVC
  app --> homeVC
  onboardingVC --> onboardingState
  onboardingVC --> emailAuthVC
  onboardingVC --> onboardingDetailVC
  onboardingVC --> carouselCell
  homeVC --> auth
  homeVC --> session
  tests -.verifies.-> app
  tests -.verifies.-> onboardingVC
  tests -.verifies.-> emailAuthVC
  tests -.verifies.-> homeVC
  tests -.verifies.-> onboardingDetailVC
```

## Runtime Flow

```mermaid
sequenceDiagram
  participant main as main.m
  participant app as AppDelegate
  participant auth as MRRFirebaseAuthenticationController
  participant state as OnboardingStateController
  participant onboarding as OnboardingViewController
  participant email as MRREmailAuthenticationViewController
  participant home as HomeViewController
  participant detail as OnboardingRecipeDetailViewController

  main->>app: UIApplicationMain(...)
  app->>auth: currentSession()
  alt authenticated session exists
    auth-->>app: MRRAuthSession
    app->>home: buildHomeViewControllerWithSession()
    home->>auth: signOut()
    auth-->>app: session cleared
    app->>onboarding: buildOnboardingViewController()
  else no authenticated session
    auth-->>app: nil
    app->>onboarding: buildOnboardingViewController()
    onboarding->>email: push Sign Up / Sign In screen
    email->>auth: signUpWithEmail / signInWithEmail
    auth-->>app: authenticated session available
    app->>home: replace root with HomeViewController
    onboarding->>detail: present recipe detail
    detail-->>onboarding: Start Cooking
    onboarding->>state: markOnboardingCompleted()
    onboarding->>detail: dismiss modal
  end
```

## Root Composition Graph

```mermaid
flowchart TB
  app["AppDelegate"]
  window["UIWindow"]
  auth["MRRFirebaseAuthenticationController"]
  session["MRRAuthSession"]
  state["OnboardingStateController"]
  nav["UINavigationController (hidden bar)"]
  onboarding["OnboardingViewController"]
  email["MRREmailAuthenticationViewController"]
  detail["OnboardingRecipeDetailViewController"]
  home["HomeViewController"]
  defaults["NSUserDefaults"]
  firebase["FirebaseAuth currentUser"]

  app --> window
  app --> auth
  app --> state
  state --> defaults
  auth --> firebase
  auth --> session
  app --> nav
  nav --> onboarding
  onboarding --> state
  onboarding --> email
  onboarding --> detail
  app --> home
  home --> auth
  home --> session
```

## Persistence ERD

```mermaid
erDiagram
  USER_DEFAULTS {
    string suite_name
    bool has_completed_onboarding
  }

  ONBOARDING_STATE_CONTROLLER {
    bool hasCompletedOnboarding
  }

  AUTH_SESSION {
    string firebase_uid
    string email
    bool email_verified
    int provider_type
  }

  APP_DELEGATE {
    UIWindow window
  }

  FIREBASE_AUTH {
    string current_user_uid
  }

  USER_DEFAULTS ||--|| ONBOARDING_STATE_CONTROLLER : backs
  ONBOARDING_STATE_CONTROLLER ||--|| APP_DELEGATE : injects_state
  FIREBASE_AUTH ||--o| AUTH_SESSION : materializes
  AUTH_SESSION ||--|| APP_DELEGATE : drives_root_flow
```

## Object Relationship Diagram

```mermaid
classDiagram
  class AppDelegate {
    +window
    +application:didFinishLaunchingWithOptions:
  }

  class MRRFirebaseAuthenticationController {
    +currentSession()
    +signUpWithEmail()
    +signInWithEmail()
    +signOut()
  }

  class MRRAuthSession {
    +email
    +providerType
    +emailVerified
  }

  class OnboardingStateController {
    +hasCompletedOnboarding()
    +markOnboardingCompleted()
  }

  class OnboardingViewController

  class MRREmailAuthenticationViewController

  class HomeViewController

  class OnboardingRecipeDetailViewController

  AppDelegate --> MRRFirebaseAuthenticationController
  MRRFirebaseAuthenticationController --> MRRAuthSession
  AppDelegate --> OnboardingStateController
  AppDelegate --> OnboardingViewController
  AppDelegate --> HomeViewController
  OnboardingViewController --> OnboardingStateController
  OnboardingViewController --> MRREmailAuthenticationViewController
  OnboardingViewController --> OnboardingRecipeDetailViewController
  HomeViewController --> MRRFirebaseAuthenticationController
  HomeViewController --> MRRAuthSession
```

## File Responsibilities

| File | Responsibility | Key relationship |
| --- | --- | --- |
| `MRR Project/App/main.m` | Application bootstrap with manual autorelease pool | Starts UIKit lifecycle |
| `MRR Project/App/AppDelegate.h` | Public app delegate contract | Exposes injectable initializer for tests |
| `MRR Project/App/AppDelegate.m` | Composition root and root-controller installation | Chooses onboarding navigation stack or home based on the current auth session |
| `MRR Project/Resources/Info.plist` | Application metadata and launch configuration | Referenced directly by build settings |
| `MRR Project/Resources/Assets.xcassets` | Shared app icon, named colors, and onboarding illustration | Used by the current programmatic UI |
| `MRR Project/Features/Authentication/MRRAuthenticationController.h` | Auth abstraction used by the app shell and tests | Keeps Firebase behind a mockable interface |
| `MRR Project/Features/Authentication/MRRFirebaseAuthenticationController.m` | Firebase-backed auth implementation | Builds `MRRAuthSession` from `FIRAuth` and handles email auth actions |
| `MRR Project/Features/Authentication/MRRAuthSession.m` | Immutable auth-session value object | Carries `email`, provider, and `emailVerified` into the UI |
| `MRR Project/Features/Authentication/MRRAuthErrorMapper.m` | Maps auth errors into user-facing copy | Shared by onboarding auth and home logout errors |
| `MRR Project/Features/Onboarding/Data/OnboardingStateController.h` | Declares onboarding persistence API | Used by `AppDelegate` |
| `MRR Project/Features/Onboarding/Data/OnboardingStateController.m` | Stores onboarding recipe completion in `NSUserDefaults` | Legacy onboarding state kept separate from auth-based root flow |
| `MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.h` | Declares the onboarding controller initializer | Accepts injected onboarding state |
| `MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingViewController.m` | Builds branded onboarding layout, looping carousel, auth CTA entry points, and recipe-detail flow | Owns push-based email auth navigation and launch centering safeguards |
| `MRR Project/Features/Onboarding/Presentation/ViewControllers/MRREmailAuthenticationViewController.m` | Renders full-screen sign-up and sign-in screens | Handles email/password validation, keyboard-aware scrolling, and auth submission |
| `MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h` | Declares recipe-detail delegate callbacks | Reports close and `Start Cooking` actions |
| `MRR Project/Features/Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.m` | Renders modal recipe detail content | Triggers onboarding completion through the onboarding controller |
| `MRR Project/Features/Onboarding/Presentation/Views/OnboardingRecipeCarouselCell.h` | Declares the onboarding carousel cell | Used by `OnboardingViewController` collection view |
| `MRR Project/Features/Onboarding/Presentation/Views/OnboardingRecipeCarouselCell.m` | Renders adaptive recipe cards, shared backdrop styling, and fade mask blending | Provides stable accessibility identifiers per recipe |
| `MRR Project/Features/Home/HomeViewController.m` | Renders the authenticated home summary | Shows provider, email, `emailVerified`, and logout confirmation flow |
| `MRR ProjectTests/AppLaunchFlowTests.m` | Verifies launch-state behavior | Covers onboarding/home root routing and sign-out transitions |
| `MRR ProjectTests/OnboardingAuthFlowTests.m` | Verifies pushed auth-screen behavior | Covers sign-up/sign-in entry, keyboard-aware layout, and auth success transitions |
| `MRR ProjectTests/HomeViewControllerTests.m` | Verifies home summary and logout interactions | Covers accessibility identifiers, email verification label, and logout confirmation |
| `MRR ProjectTests/OnboardingViewControllerTests.m` | Verifies onboarding layout, carousel behavior, detail presentation, and accessibility | Covers centering, recentering, backdrop styling, and completion flow |

## Active Dependencies

The runtime dependency chain is intentionally small:

`AppDelegate -> MRRFirebaseAuthenticationController -> FirebaseAuth currentUser`

`AppDelegate -> OnboardingStateController -> NSUserDefaults`

`AppDelegate -> UINavigationController -> OnboardingViewController -> MRREmailAuthenticationViewController`

`AppDelegate -> HomeViewController`

`OnboardingViewController -> UICollectionView -> OnboardingRecipeCarouselCell`

`OnboardingViewController -> OnboardingStateController`

`OnboardingViewController -> OnboardingRecipeDetailViewController`

`HomeViewController -> MRRAuthSession`

`Assets.xcassets -> OnboardingViewController / OnboardingRecipeDetailViewController / OnboardingRecipeCarouselCell`

There is no tab bar, no standalone post-onboarding menu, and no coordinator layer.

## Testing Coverage

```mermaid
flowchart LR
  launch["AppLaunchFlowTests"]
  auth["OnboardingAuthFlowTests"]
  home["HomeViewControllerTests"]
  onboarding["OnboardingViewControllerTests"]
  first["first launch -> onboarding nav root"]
  signedIn["logged-in launch -> home"]
  authPush["sign up / sign in push flow"]
  authSuccess["email auth success -> home"]
  homeSummary["provider + emailVerified summary"]
  logout["logout confirmation -> onboarding"]
  detail["recipe tap -> recipe detail modal"]
  finish["Start Cooking -> persist flag + dismiss detail"]
  carousel["carousel centering + recentering + autoscroll"]
  a11y["accessibility identifiers + backdrop styling"]

  launch --> first
  launch --> signedIn
  auth --> authPush
  auth --> authSuccess
  home --> homeSummary
  home --> logout
  onboarding --> detail
  onboarding --> finish
  onboarding --> carousel
  onboarding --> a11y
```

## Architectural Notes

- The app target uses Manual Retain-Release. Application code must continue balancing retained objects explicitly.
- Root navigation is state-based, not coordinator-based. This keeps the app small and direct.
- The onboarding feature now owns the dedicated sign-up and sign-in screens, so auth entry remains visually and structurally close to the onboarding surface.
- Email/password is the only live onboarding auth path in the current milestone. Google and Apple stay visible as structured stubs.
- The onboarding carousel uses virtual looping plus guarded initial positioning so auto-scroll does not jump on launch.
- The auth screens are keyboard-aware: they use scroll insets, tap-to-dismiss, and focused-field visibility handling.
- Light and dark appearance rely on named colors from the shared asset catalog.
- Accessibility identifiers are a maintained part of the onboarding, auth, and home debug/test contract.
- The repository now includes a tracked GitHub Actions coverage workflow and a tracked pre-commit hook for Objective-C formatting and linting.

## Conclusion

The current architecture is a minimal onboarding-and-auth application. `AppDelegate` remains the composition root, `OnboardingViewController` remains the logged-out entry surface, `MRREmailAuthenticationViewController` handles pushed full-screen email auth, and `HomeViewController` represents the authenticated state. The result is a small runtime surface that still keeps the polished carousel, recipe-detail exploration flow, adaptive theming, and a stronger auth/test/tooling story than the earlier onboarding-only variant.
