# Recipe Card Context Menu Design Specifications

## Overview
A beautiful, iOS-native context menu popup that appears when the user long-presses a recipe card. The menu combines the visual language of iOS action sheets with the app's existing glass-morphism aesthetic.

---

## Design Philosophy
- **Approach**: Refined, minimal, and distinctly iOS-native
- **Tone**: Clean, functional, with subtle warmth from the app's orange accent
- **Differentiation**: Spring-based animations with staggered reveals create a premium, tactile feel

---

## Color Palette

### Background Colors
| Element | Light Mode | Dark Mode | Notes |
|---------|------------|-----------|-------|
| Backdrop overlay | `UIColor.blackColor` at 0.85 alpha | Same | Consistent with `MRRImagePopupViewController` |
| Menu card surface | `UIColor.whiteColor` | `[UIColor colorWithWhite:0.14 alpha:1.0]` | Matches `HomeSurfaceColor` pattern |
| Menu item highlight | `[UIColor colorWithWhite:0.96 alpha:1.0]` | `[UIColor colorWithWhite:0.22 alpha:1.0]` | 4% lighter than surface |

### Text & Icon Colors
| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| Primary text | `[UIColor colorWithWhite:0.10 alpha:1.0]` | `[UIColor colorWithWhite:0.95 alpha:1.0]` |
| Secondary text | `[UIColor colorWithWhite:0.46 alpha:1.0]` | `[UIColor colorWithWhite:0.72 alpha:1.0]` |
| Destructive (Delete) | `[UIColor systemRedColor]` | `[UIColor systemRedColor]` |
| Cancel text | Accent color: `[UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0]` | `[UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]` |

### Border & Shadow
| Property | Value |
|----------|-------|
| Menu border color | `[[UIColor colorWithWhite:0.10 alpha:1.0] colorWithAlphaComponent:0.12]` (light) / `[[UIColor colorWithWhite:0.95 alpha:1.0] colorWithAlphaComponent:0.12]` (dark) |
| Menu border width | 1.0 pt |
| Menu shadow color | `UIColor.blackColor` |
| Menu shadow opacity | 0.10 |
| Menu shadow radius | 20.0 pt |
| Menu shadow offset | `(0.0, 14.0)` |

---

## Layout Specifications

### Menu Container
| Property | Value |
|----------|-------|
| Maximum width | 280 pt |
| Corner radius | 24 pt |
| Horizontal padding (internal) | 16 pt |
| Vertical padding (internal) | 12 pt top, 16 pt bottom |

### Menu Items
| Property | Value |
|----------|-------|
| Height | 56 pt |
| Icon size | 24 pt |
| Icon-to-label spacing | 16 pt |
| Label font | `[UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium]` |
| Divider height | 0.5 pt |
| Divider color | `[[UIColor colorWithWhite:0.10 alpha:1.0] colorWithAlphaComponent:0.08]` (light) |

### SF Symbol Icons
| Action | Icon Name | Weight |
|--------|-----------|--------|
| Edit Recipe | `square.and.pencil` | `UIFontWeightMedium` |
| Delete Recipe | `trash` | `UIFontWeightMedium` |
| Share Recipe | `square.and.arrow.up` | `UIFontWeightMedium` |
| Cancel | `xmark.circle` | `UIFontWeightMedium` |

---

## Animation Specifications

### Entry Animation Sequence

#### 1. Backdrop Fade
```objective-c
[UIView animateWithDuration:0.25
                      delay:0.0
                    options:UIViewAnimationOptionCurveEaseOut
                 animations:^{
                     dimmingView.alpha = 0.85;
                 }
                 completion:nil];
```

#### 2. Menu Card Scale + Fade (Spring)
```objective-c
// Initial state
menuContainer.transform = CGAffineTransformMakeScale(0.85, 0.85);
menuContainer.alpha = 0.0;

// Animate to final
[UIView animateWithDuration:0.45
                      delay:0.05
     usingSpringWithDamping:0.75
      initialSpringVelocity:0.5
                    options:UIViewAnimationOptionCurveEaseOut
                 animations:^{
                     menuContainer.transform = CGAffineTransformIdentity;
                     menuContainer.alpha = 1.0;
                 }
                 completion:nil];
```

#### 3. Menu Items Stagger Animation
```objective-c
// Each item animates in sequence
NSTimeInterval baseDelay = 0.15;
NSTimeInterval staggerDelay = 0.04;

for (NSUInteger i = 0; i < menuItems.count; i++) {
    UIView *item = menuItems[i];
    
    // Initial state
    item.transform = CGAffineTransformMakeTranslation(0, 20);
    item.alpha = 0.0;
    
    [UIView animateWithDuration:0.35
                          delay:baseDelay + (staggerDelay * i)
         usingSpringWithDamping:0.80
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         item.transform = CGAffineTransformIdentity;
                         item.alpha = 1.0;
                     }
                     completion:nil];
}
```

### Long-Press Card Animation
```objective-c
// Scale down during long-press
[UIView animateWithDuration:0.20
                      delay:0.0
                    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                 animations:^{
                     recipeCard.transform = CGAffineTransformMakeScale(0.96, 0.96);
                     recipeCard.alpha = 0.92;
                 }
                 completion:nil];

// Restore on release
[UIView animateWithDuration:0.25
                      delay:0.0
     usingSpringWithDamping:0.85
      initialSpringVelocity:0.4
                    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                 animations:^{
                     recipeCard.transform = CGAffineTransformIdentity;
                     recipeCard.alpha = 1.0;
                 }
                 completion:nil];
```

### Tap Highlight Animation
```objective-c
// Highlight on touch down
[UIView animateWithDuration:0.12
                      delay:0.0
                    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                 animations:^{
                     menuItem.backgroundColor = highlightColor;
                 }
                 completion:nil];

// Restore on touch up
[UIView animateWithDuration:0.18
                      delay:0.0
                    options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                 animations:^{
                     menuItem.backgroundColor = [UIColor clearColor];
                 }
                 completion:nil];
```

### Exit Animation (Dismissal)
```objective-c
// Menu slides down + fades
[UIView animateWithDuration:0.25
                      delay:0.0
                    options:UIViewAnimationOptionCurveEaseIn
                 animations:^{
                     menuContainer.transform = CGAffineTransformMakeScale(0.95, 0.95);
                     menuContainer.alpha = 0.0;
                     dimmingView.alpha = 0.0;
                 }
                 completion:^(BOOL finished) {
                     [self dismiss];
                 }];
```

---

## Interaction Behavior

### Trigger
- **Gesture**: UILongPressGestureRecognizer with 0.5s minimum press duration
- **Location**: Centered on the tapped recipe card
- **Haptic**: `UIImpactFeedbackGenerator` with `UIImpactFeedbackStyleLight` on menu appearance

### Dismissal Triggers
1. Tap outside menu bounds
2. Selection of any menu option
3. Device orientation change (optional)

### Accessibility
```objective-c
// Menu container
menuContainer.accessibilityViewIsModal = YES;

// Menu items
editItem.accessibilityLabel = @"Edit Recipe";
editItem.accessibilityHint = @"Double tap to edit this recipe";
deleteItem.accessibilityLabel = @"Delete Recipe";
deleteItem.accessibilityHint = @"Double tap to delete this recipe";
deleteItem.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitDestructive;
shareItem.accessibilityLabel = @"Share Recipe";
shareItem.accessibilityHint = @"Double tap to share this recipe";
cancelItem.accessibilityLabel = @"Cancel";
cancelItem.accessibilityHint = @"Double tap to close this menu";
```

---

## Visual Hierarchy

### Z-Index Layers (Top to Bottom)
1. Menu card container (z-index: 100)
2. Backdrop dimming view (z-index: 50)
3. Original recipe card (z-index: 10, scaled during interaction)
4. Background content (z-index: 1)

### Component Structure
```
MRRRecipeContextMenuViewController
├── dimmingView (UIVisualEffectView + dark overlay)
└── menuContainer (UIView)
    ├── stackView (UIStackView, vertical, 0 spacing)
    │   ├── editItem (MRRContextMenuItem)
    │   ├── divider1 (UIView)
    │   ├── deleteItem (MRRContextMenuItem)
    │   ├── divider2 (UIView)
    │   ├── shareItem (MRRContextMenuItem)
    │   ├── divider3 (UIView)
    │   └── cancelItem (MRRContextMenuItem)
    └── shadow layer

MRRContextMenuItem (UIView)
├── iconImageView (UIImageView, 24pt)
└── titleLabel (UILabel)
```

---

## Implementation Notes

### Memory Management (MRR)
```objective-c
@interface MRRRecipeContextMenuViewController : UIViewController {
  UIView *_dimmingView;        // retained
  UIView *_menuContainer;      // retained
  NSArray *_menuItems;         // retained
  id<MRRRecipeContextMenuDelegate> _delegate; // assigned
}

- (void)dealloc {
  [_dimmingView release];
  [_menuContainer release];
  [_menuItems release];
  [super dealloc];
}
```

### Delegate Protocol
```objective-c
@protocol MRRRecipeContextMenuDelegate <NSObject>
@required
- (void)contextMenuDidSelectEdit:(MRRRecipeContextMenuViewController *)menu;
- (void)contextMenuDidSelectDelete:(MRRRecipeContextMenuViewController *)menu;
- (void)contextMenuDidSelectShare:(MRRRecipeContextMenuViewController *)menu;
- (void)contextMenuDidCancel:(MRRRecipeContextMenuViewController *)menu;
@end
```

### Usage Example
```objective-c
// In HomeRecipeCardCell
- (void)setupLongPressGesture {
    UILongPressGestureRecognizer *longPress = 
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self addGestureRecognizer:longPress];
    [longPress release];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        // Trigger haptic
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
        [feedback release];
        
        // Present menu
        MRRRecipeContextMenuViewController *menu = 
            [[MRRRecipeContextMenuViewController alloc] initWithRecipe:self.recipe];
        menu.delegate = self.delegate;
        menu.modalPresentationStyle = UIModalPresentationOverFullScreen;
        menu.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        
        UIViewController *presentingVC = [self mrr_nearestViewController];
        [presentingVC presentViewController:menu animated:NO completion:nil];
        [menu release];
    }
}
```

---

## Animation Timing Reference

| Animation Phase | Duration | Delay | Damping | Velocity |
|-----------------|----------|-------|---------|----------|
| Backdrop fade | 0.25s | 0.0s | N/A (ease-out) | N/A |
| Menu scale + fade | 0.45s | 0.05s | 0.75 | 0.5 |
| Menu item stagger | 0.35s | 0.15s + (0.04s × index) | 0.80 | 0.3 |
| Card press down | 0.20s | 0.0s | N/A (linear) | N/A |
| Card press release | 0.25s | 0.0s | 0.85 | 0.4 |
| Item highlight | 0.12s | 0.0s | N/A | N/A |
| Item unhighlight | 0.18s | 0.0s | N/A | N/A |
| Menu dismiss | 0.25s | 0.0s | N/A (ease-in) | N/A |

---

## File Locations

```
MRR Project/Features/RecipeContextMenu/
├── MRRRecipeContextMenuViewController.h
├── MRRRecipeContextMenuViewController.m
├── MRRContextMenuItem.h
└── MRRContextMenuItem.m
```

---

*Design specifications generated for iOS MRR Learning Project*
*Compliant with existing MRRLiquidGlassStyling patterns and HomeCollectionViewCells animation conventions*
