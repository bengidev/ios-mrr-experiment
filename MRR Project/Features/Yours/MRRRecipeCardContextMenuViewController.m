#import "MRRRecipeCardContextMenuViewController.h"

#pragma mark - Constants

static CGFloat const MRRContextMenuBackdropAlpha = 0.85;
static CGFloat const MRRContextMenuCornerRadius = 24.0;
static CGFloat const MRRContextMenuItemHeight = 56.0;
static CGFloat const MRRContextMenuIconSize = 24.0;
static CGFloat const MRRContextMenuPadding = 16.0;
static CGFloat const MRRContextMenuMaxWidth = 280.0;
static CGFloat const MRRContextMenuShadowRadius = 20.0;
static CGFloat const MRRContextMenuShadowOpacity = 0.18;
static CGFloat const MRRContextMenuInitialScale = 0.88;
static CGFloat const MRRContextMenuSpringDamping = 0.75;
static CGFloat const MRRContextMenuSpringVelocity = 0.5;
static CGFloat const MRRContextMenuAnimationDuration = 0.45;
static CGFloat const MRRContextMenuItemStaggerDelay = 0.04;  // 40ms between items

@interface MRRRecipeCardContextMenuAction : NSObject
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *imageName;
@property(nonatomic, assign, readonly) BOOL isDestructive;
@property(nonatomic, copy, readonly) void (^handler)(void);
+ (instancetype)actionWithTitle:(NSString *)title imageName:(NSString *)imageName isDestructive:(BOOL)isDestructive handler:(void (^)(void))handler;
@end

@implementation MRRRecipeCardContextMenuAction

+ (instancetype)actionWithTitle:(NSString *)title imageName:(NSString *)imageName isDestructive:(BOOL)isDestructive handler:(void (^)(void))handler {
  MRRRecipeCardContextMenuAction *action = [[[self alloc] init] autorelease];
  if (action) {
    action->_title = [title copy];
    action->_imageName = [imageName copy];
    action->_isDestructive = isDestructive;
    action->_handler = [handler copy];
  }
  return action;
}

- (void)dealloc {
  [_title release];
  [_imageName release];
  [_handler release];
  [super dealloc];
}

@end

@interface MRRRecipeCardContextMenuViewController ()

@property(nonatomic, retain) NSMutableArray<MRRRecipeCardContextMenuAction *> *actions;
@property(nonatomic, retain) UIVisualEffectView *blurView;
@property(nonatomic, retain) UIView *dimmingView;
@property(nonatomic, retain) UIView *menuContainerView;
@property(nonatomic, retain) NSMutableArray<UIView *> *menuItemViews;
@property(nonatomic, retain) NSString *recipeTitle;

- (void)setupBlurBackground;
- (void)setupMenuContainer;
- (void)buildMenuItems;
- (UIView *)menuItemViewForAction:(MRRRecipeCardContextMenuAction *)action index:(NSUInteger)index total:(NSUInteger)total;
- (void)animatePresentation;
- (void)animateDismissalWithCompletion:(void (^)(void))completion;
- (void)handleBackdropTap:(UITapGestureRecognizer *)recognizer;
- (void)handleMenuItemTap:(UITapGestureRecognizer *)recognizer;
- (void)triggerHapticFeedback;
- (UIColor *)primaryTextColor;
- (UIColor *)destructiveColor;
- (UIColor *)menuBackgroundColor;

@end

@implementation MRRRecipeCardContextMenuViewController

- (instancetype)initWithRecipeTitle:(NSString *)recipeTitle {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _recipeTitle = [recipeTitle copy];
    _actions = [[NSMutableArray alloc] init];
    _menuItemViews = [[NSMutableArray alloc] init];

    self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  }
  return self;
}

- (void)dealloc {
  [_recipeTitle release];
  [_actions release];
  [_blurView release];
  [_dimmingView release];
  [_menuContainerView release];
  [_menuItemViews release];
  [_cancelHandler release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = [UIColor clearColor];

  [self setupBlurBackground];
  [self setupMenuContainer];
  [self buildMenuItems];

  // Initial state - menu is hidden
  self.menuContainerView.alpha = 0.0;
  self.menuContainerView.transform = CGAffineTransformMakeScale(MRRContextMenuInitialScale, MRRContextMenuInitialScale);

  // Trigger haptic feedback
  [self triggerHapticFeedback];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  // Animate presentation
  [self animatePresentation];
}

#pragma mark - Setup

- (void)setupBlurBackground {
  // Dimming view
  UIView *dimmingView = [[[UIView alloc] init] autorelease];
  dimmingView.translatesAutoresizingMaskIntoConstraints = NO;
  dimmingView.backgroundColor = [UIColor blackColor];
  dimmingView.alpha = 0.0;
  [self.view addSubview:dimmingView];
  self.dimmingView = dimmingView;

  // Blur effect view
  UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
  UIVisualEffectView *blurView = [[[UIVisualEffectView alloc] initWithEffect:blurEffect] autorelease];
  blurView.translatesAutoresizingMaskIntoConstraints = NO;
  blurView.alpha = 0.0;
  [self.view addSubview:blurView];
  self.blurView = blurView;

  // Tap gesture to dismiss
  UITapGestureRecognizer *tapGesture = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackdropTap:)] autorelease];
  [blurView.contentView addGestureRecognizer:tapGesture];

  // Constraints
  [NSLayoutConstraint activateConstraints:@[
    [dimmingView.topAnchor constraintEqualToAnchor:self.view.topAnchor], [dimmingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [dimmingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [dimmingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [blurView.topAnchor constraintEqualToAnchor:self.view.topAnchor], [blurView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [blurView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor], [blurView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
  ]];
}

- (void)setupMenuContainer {
  UIView *menuContainer = [[[UIView alloc] init] autorelease];
  menuContainer.translatesAutoresizingMaskIntoConstraints = NO;
  menuContainer.backgroundColor = [self menuBackgroundColor];
  menuContainer.layer.cornerRadius = MRRContextMenuCornerRadius;
  menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
  menuContainer.layer.shadowOffset = CGSizeMake(0.0, 14.0);
  menuContainer.layer.shadowRadius = MRRContextMenuShadowRadius;
  menuContainer.layer.shadowOpacity = MRRContextMenuShadowOpacity;

  // Add subtle border
  menuContainer.layer.borderWidth = 0.5;
  menuContainer.layer.borderColor = [[self primaryTextColor] colorWithAlphaComponent:0.12].CGColor;

  [self.view addSubview:menuContainer];
  self.menuContainerView = menuContainer;

  // Center constraints
  [NSLayoutConstraint activateConstraints:@[
    [menuContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [menuContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    [menuContainer.widthAnchor constraintLessThanOrEqualToConstant:MRRContextMenuMaxWidth],
    [menuContainer.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:40.0],
    [menuContainer.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-40.0]
  ]];
}

- (void)buildMenuItems {
  if (self.actions.count == 0) {
    return;
  }

  UIView *previousView = nil;

  for (NSUInteger i = 0; i < self.actions.count; i++) {
    MRRRecipeCardContextMenuAction *action = self.actions[i];
    UIView *itemView = [self menuItemViewForAction:action index:i total:self.actions.count];

    [self.menuContainerView addSubview:itemView];
    [self.menuItemViews addObject:itemView];

    // Initial state for stagger animation
    itemView.alpha = 0.0;
    itemView.transform = CGAffineTransformMakeTranslation(0.0, 20.0);

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
      [itemView.leadingAnchor constraintEqualToAnchor:self.menuContainerView.leadingAnchor],
      [itemView.trailingAnchor constraintEqualToAnchor:self.menuContainerView.trailingAnchor],
      [itemView.heightAnchor constraintEqualToConstant:MRRContextMenuItemHeight]
    ]];

    if (previousView == nil) {
      [itemView.topAnchor constraintEqualToAnchor:self.menuContainerView.topAnchor].active = YES;
    } else {
      [itemView.topAnchor constraintEqualToAnchor:previousView.bottomAnchor].active = YES;
    }

    previousView = itemView;
  }

  // Bottom constraint for last item
  if (previousView != nil) {
    [previousView.bottomAnchor constraintEqualToAnchor:self.menuContainerView.bottomAnchor].active = YES;
  }
}

- (UIView *)menuItemViewForAction:(MRRRecipeCardContextMenuAction *)action index:(NSUInteger)index total:(NSUInteger)total {
  UIView *itemView = [[[UIView alloc] init] autorelease];
  itemView.translatesAutoresizingMaskIntoConstraints = NO;
  itemView.backgroundColor = [UIColor clearColor];
  itemView.tag = index;  // Store index for tap handling

  // Tap gesture
  UITapGestureRecognizer *tapGesture = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuItemTap:)] autorelease];
  [itemView addGestureRecognizer:tapGesture];

  // Separator (except for first item)
  if (index > 0) {
    UIView *separator = [[[UIView alloc] init] autorelease];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [[self primaryTextColor] colorWithAlphaComponent:0.08];
    [itemView addSubview:separator];

    [NSLayoutConstraint activateConstraints:@[
      [separator.topAnchor constraintEqualToAnchor:itemView.topAnchor],
      [separator.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor constant:MRRContextMenuPadding],
      [separator.trailingAnchor constraintEqualToAnchor:itemView.trailingAnchor constant:-MRRContextMenuPadding],
      [separator.heightAnchor constraintEqualToConstant:0.5]
    ]];
  }

  // Icon
  UIImageView *iconView = [[[UIImageView alloc] init] autorelease];
  iconView.translatesAutoresizingMaskIntoConstraints = NO;
  iconView.contentMode = UIViewContentModeScaleAspectFit;
  iconView.tintColor = action.isDestructive ? [self destructiveColor] : [self primaryTextColor];

  if (action.imageName.length > 0) {
    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
      image = [UIImage systemImageNamed:action.imageName];
    }
    iconView.image = image;
  }

  [itemView addSubview:iconView];

  // Label
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
  label.textColor = action.isDestructive ? [self destructiveColor] : [self primaryTextColor];
  label.text = action.title;

  [itemView addSubview:label];

  // Constraints
  [NSLayoutConstraint activateConstraints:@[
    [iconView.leadingAnchor constraintEqualToAnchor:itemView.leadingAnchor constant:MRRContextMenuPadding],
    [iconView.centerYAnchor constraintEqualToAnchor:itemView.centerYAnchor], [iconView.widthAnchor constraintEqualToConstant:MRRContextMenuIconSize],
    [iconView.heightAnchor constraintEqualToConstant:MRRContextMenuIconSize],

    [label.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:12.0],
    [label.centerYAnchor constraintEqualToAnchor:itemView.centerYAnchor],
    [label.trailingAnchor constraintLessThanOrEqualToAnchor:itemView.trailingAnchor constant:-MRRContextMenuPadding]
  ]];

  return itemView;
}

#pragma mark - Animation

/**
 * Animates the presentation of the context menu with backdrop fade,
 * container spring animation, and staggered item appearance.
 * Optimized for quick response with minimal delays.
 */
- (void)animatePresentation {
  // Animate backdrop
  [UIView animateWithDuration:0.25
                        delay:0.0
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     self.dimmingView.alpha = MRRContextMenuBackdropAlpha;
                     self.blurView.alpha = 1.0;
                   }
                   completion:nil];

  // Animate menu container with spring - start immediately
  [UIView animateWithDuration:MRRContextMenuAnimationDuration
                        delay:0.0
       usingSpringWithDamping:MRRContextMenuSpringDamping
        initialSpringVelocity:MRRContextMenuSpringVelocity
                      options:UIViewAnimationOptionBeginFromCurrentState
                   animations:^{
                     self.menuContainerView.alpha = 1.0;
                     self.menuContainerView.transform = CGAffineTransformIdentity;
                   }
                   completion:nil];

  // Animate menu items with stagger
  for (NSUInteger i = 0; i < self.menuItemViews.count; i++) {
    UIView *itemView = self.menuItemViews[i];
    CGFloat delay = 0.05 + (i * MRRContextMenuItemStaggerDelay);

    [UIView animateWithDuration:0.35
                          delay:delay
         usingSpringWithDamping:0.80
          initialSpringVelocity:0.3
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                       itemView.alpha = 1.0;
                       itemView.transform = CGAffineTransformIdentity;
                     }
                     completion:nil];
  }
}

- (void)animateDismissalWithCompletion:(void (^)(void))completion {
  // Animate menu out
  [UIView animateWithDuration:0.25
      delay:0.0
      options:UIViewAnimationOptionCurveEaseIn
      animations:^{
        self.menuContainerView.alpha = 0.0;
        self.menuContainerView.transform = CGAffineTransformMakeScale(0.92, 0.92);
        self.dimmingView.alpha = 0.0;
        self.blurView.alpha = 0.0;
      }
      completion:^(BOOL finished) {
        if (completion) {
          completion();
        }
      }];
}

#pragma mark - Actions

- (void)addActionWithTitle:(NSString *)title imageName:(NSString *)imageName isDestructive:(BOOL)isDestructive handler:(void (^)(void))handler {
  MRRRecipeCardContextMenuAction *action = [MRRRecipeCardContextMenuAction actionWithTitle:title
                                                                                 imageName:imageName
                                                                             isDestructive:isDestructive
                                                                                   handler:handler];
  [self.actions addObject:action];
}

#pragma mark - Gesture Handlers

- (void)handleBackdropTap:(UITapGestureRecognizer *)recognizer {
  if (self.cancelHandler) {
    [self animateDismissalWithCompletion:^{
      self.cancelHandler();
    }];
  } else {
    [self animateDismissalWithCompletion:^{
      [self dismissViewControllerAnimated:NO completion:nil];
    }];
  }
}

- (void)handleMenuItemTap:(UITapGestureRecognizer *)recognizer {
  NSUInteger index = recognizer.view.tag;
  if (index >= self.actions.count) {
    return;
  }

  MRRRecipeCardContextMenuAction *action = self.actions[index];

  // Highlight animation
  UIView *itemView = recognizer.view;
  [UIView animateWithDuration:0.12
      animations:^{
        itemView.alpha = 0.6;
      }
      completion:^(BOOL finished) {
        [UIView animateWithDuration:0.12
            animations:^{
              itemView.alpha = 1.0;
            }
            completion:^(BOOL finished) {
              // Dismiss and execute handler
              [self animateDismissalWithCompletion:^{
                if (action.handler) {
                  action.handler();
                }
              }];
            }];
      }];
}

#pragma mark - Haptic Feedback

- (void)triggerHapticFeedback {
  if (@available(iOS 10.0, *)) {
    UIImpactFeedbackGenerator *generator = [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] autorelease];
    [generator prepare];
    [generator impactOccurred];
  }
}

#pragma mark - Colors

- (UIColor *)primaryTextColor {
  if (@available(iOS 13.0, *)) {
    return [UIColor labelColor];
  }
  return [UIColor colorWithWhite:0.10 alpha:1.0];
}

- (UIColor *)destructiveColor {
  return [UIColor systemRedColor];
}

- (UIColor *)menuBackgroundColor {
  if (@available(iOS 13.0, *)) {
    return [UIColor systemBackgroundColor];
  }
  return [UIColor whiteColor];
}

@end
