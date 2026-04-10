#import "YoursViewController.h"

#import <objc/runtime.h>

#import "../../Persistence/UserRecipes/MRRUserRecipePhotoStorage.h"
#import "../../Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../../Persistence/UserRecipes/Models/MRRUserRecipeSnapshot.h"
#import "../../Persistence/UserRecipes/Sync/MRRUserRecipesCloudSyncing.h"
#import "MRRImagePopupViewController.h"
#import "MRRRecipeCardContextMenuViewController.h"
#import "MRRYoursRecipeEditorViewController.h"

static NSErrorDomain const MRRYoursViewControllerErrorDomain = @"MRRYoursViewControllerErrorDomain";
static NSString *const MRRYoursViewControllerLogPrefix = @"[YoursViewController]";

static UIColor *MRRYoursDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRYoursNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRYoursDynamicFallbackColor(lightColor, darkColor);
}

static UIColor *MRRYoursCanvasColor(void) {
  return MRRYoursNamedColor(@"BackgroundColor", [UIColor colorWithRed:0.98 green:0.97 blue:0.95 alpha:1.0],
                            [UIColor colorWithRed:0.10 green:0.11 blue:0.12 alpha:1.0]);
}

static UIColor *MRRYoursSurfaceColor(void) {
  return MRRYoursNamedColor(@"HomeSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0], [UIColor colorWithWhite:0.14 alpha:1.0]);
}

static UIColor *MRRYoursMutedSurfaceColor(void) {
  return MRRYoursNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.95 alpha:1.0], [UIColor colorWithWhite:0.18 alpha:1.0]);
}

static UIColor *MRRYoursBorderColor(void) {
  return MRRYoursNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0], [UIColor colorWithWhite:0.24 alpha:1.0]);
}

static UIColor *MRRYoursPrimaryTextColor(void) {
  return MRRYoursNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRYoursSecondaryTextColor(void) {
  return MRRYoursNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.45 alpha:1.0], [UIColor colorWithWhite:0.70 alpha:1.0]);
}

static UIColor *MRRYoursAccentColor(void) {
  return MRRYoursNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static UIColor *MRRYoursDeleteColor(void) {
  return MRRYoursDynamicFallbackColor([UIColor colorWithRed:0.87 green:0.21 blue:0.19 alpha:1.0], [UIColor colorWithRed:1.0
                                                                                                                  green:0.42
                                                                                                                   blue:0.40
                                                                                                                  alpha:1.0]);
}

static CGFloat MRRYoursSelectionToolbarWidth(void) { return 228.0; }

static CGFloat MRRYoursDeleteButtonWidth(void) { return 180.0; }

static NSString *const MRRYoursRecipeCardIdentifierPrefix = @"yours.recipeCard.";
static NSString *const MRRYoursRecipeCoverImageIdentifierPrefix = @"yours.recipeCoverImage.";
static NSString *const MRRYoursRecipeDeleteButtonIdentifierPrefix = @"yours.deleteButton.";
static NSString *const MRRYoursRecipeThumbnailsIdentifierPrefix = @"yours.recipeThumbnails.";
static NSString *const MRRYoursRecipeThumbnailIdentifierPrefix = @"yours.recipeThumbnail.";
static NSString *const MRRYoursRecipeThumbnailsToggleIdentifierPrefix = @"yours.recipeThumbnailsToggle.";
static CGFloat const MRRYoursRecipeThumbnailSize = 62.0;
static CGFloat const MRRYoursRecipeThumbnailSpacing = 10.0;
static CGFloat const MRRYoursRecipeThumbnailsHeaderHeight = 36.0;

@interface YoursViewController () <UIContextMenuInteractionDelegate>

@property(nonatomic, copy, nullable) NSString *sessionUserID;
@property(nonatomic, retain, nullable) MRRUserRecipesStore *userRecipesStore;
@property(nonatomic, retain, nullable) id<MRRUserRecipesCloudSyncing> syncEngine;
@property(nonatomic, retain) id<MRRUserRecipePhotoStorage> photoStorage;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIView *contentView;
@property(nonatomic, retain) UIStackView *cardsStackView;
@property(nonatomic, retain) UILabel *emptyStateLabel;
@property(nonatomic, retain) UIButton *emptyStateButton;
@property(nonatomic, copy) NSArray<MRRUserRecipeSnapshot *> *recipes;
@property(nonatomic, retain) NSMutableSet<NSString *> *expandedRecipeIDs;
@property(nonatomic, retain) NSMutableDictionary<NSString *, NSLayoutConstraint *> *thumbnailsHeightConstraints;
@property(nonatomic, retain) NSMutableSet<NSString *> *selectedRecipeIDs;
@property(nonatomic, assign) BOOL isSelectionMode;
@property(nonatomic, retain) UIView *selectionToolbar;
@property(nonatomic, retain) NSLayoutConstraint *selectionToolbarBottomConstraint;
@property(nonatomic, retain) UIBarButtonItem *addBarButtonItem;
@property(nonatomic, retain) UIBarButtonItem *editBarButtonItem;
@property(nonatomic, retain) UIBarButtonItem *doneBarButtonItem;
@property(nonatomic, retain) UIButton *deleteToolbarButton;
@property(nonatomic, retain) UIView *pressedCardView;

- (instancetype)initWithSessionUserID:(nullable NSString *)sessionUserID
                     userRecipesStore:(nullable MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(nullable id<MRRUserRecipesCloudSyncing>)syncEngine
                         photoStorage:(nullable id<MRRUserRecipePhotoStorage>)photoStorage;
- (void)buildViewHierarchy;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (UIButton *)actionButtonWithTitle:(NSString *)title filled:(BOOL)filled;
- (void)loadRecipesFromStore;
- (void)reloadContent;
- (UIView *)emptyStateView;
- (UIView *)recipeCardViewForRecipe:(MRRUserRecipeSnapshot *)recipe;
- (nullable MRRUserRecipeSnapshot *)recipeForIdentifier:(nullable NSString *)recipeIdentifier;
- (nullable NSString *)recipeIdentifierFromButton:(UIButton *)button prefix:(NSString *)prefix;
- (NSString *)metadataTextForRecipe:(MRRUserRecipeSnapshot *)recipe;
- (NSString *)updatedTextForRecipe:(MRRUserRecipeSnapshot *)recipe;
- (void)presentEditorForRecipe:(nullable MRRUserRecipeSnapshot *)recipe;
- (BOOL)deleteRecipeWithIdentifier:(NSString *)recipeIdentifier error:(NSError *_Nullable *_Nullable)error;
- (void)presentValidationError:(NSError *)error title:(NSString *)title;
- (void)handleAddButtonTapped:(id)sender;
- (void)handleEditButtonTapped:(id)sender;
- (void)handleDoneButtonTapped:(id)sender;
- (void)handleDeleteButtonTapped:(UIButton *)sender;
- (void)handleDeleteToolbarButtonTapped:(id)sender;
- (void)performBulkDelete;
- (void)updateNavigationBarButtons;
- (void)updateAllCardsSelectionVisibility;
- (void)updateToolbarVisibility;
- (void)handleImageTapped:(UITapGestureRecognizer *)recognizer;
- (void)presentImagePopupWithImage:(UIImage *)image;
- (void)handleThumbnailsToggleTapped:(UIButton *)sender;
- (void)userRecipesStoreDidChange:(NSNotification *)notification;
- (void)handleSelectButtonTapped:(UIButton *)sender;
- (void)updateCardSelectionVisuals:(NSString *)recipeID;
- (void)handleCardTappedForSelection:(UITapGestureRecognizer *)gesture;
- (UIImage *)circularImageWithSize:(CGSize)size fillColor:(UIColor *)fillColor strokeColor:(UIColor *)strokeColor;

@end

@implementation YoursViewController

- (instancetype)init {
  return [self initWithSessionUserID:nil userRecipesStore:nil syncEngine:nil];
}

- (instancetype)initWithSessionUserID:(NSString *)sessionUserID
                     userRecipesStore:(MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(id<MRRUserRecipesCloudSyncing>)syncEngine {
  return [self initWithSessionUserID:sessionUserID userRecipesStore:userRecipesStore syncEngine:syncEngine photoStorage:nil];
}

- (instancetype)initWithSessionUserID:(NSString *)sessionUserID
                     userRecipesStore:(MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(id<MRRUserRecipesCloudSyncing>)syncEngine
                         photoStorage:(id<MRRUserRecipePhotoStorage>)photoStorage {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _sessionUserID = [sessionUserID copy];
    _userRecipesStore = [userRecipesStore retain];
    _syncEngine = [syncEngine retain];
    _photoStorage = [(photoStorage ?: [[[MRRLocalUserRecipePhotoStorage alloc] init] autorelease]) retain];
    _recipes = [[NSArray alloc] init];
    _expandedRecipeIDs = [[NSMutableSet alloc] init];
    _selectedRecipeIDs = [[NSMutableSet alloc] init];
    _isSelectionMode = NO;
    _thumbnailsHeightConstraints = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_pressedCardView release];
  [_thumbnailsHeightConstraints release];
  [_expandedRecipeIDs release];
  [_recipes release];
  [_emptyStateButton release];
  [_emptyStateLabel release];
  [_cardsStackView release];
  [_contentView release];
  [_scrollView release];
  [_photoStorage release];
  [_syncEngine release];
  [_userRecipesStore release];
  [_sessionUserID release];
  [_deleteToolbarButton release];
  [_doneBarButtonItem release];
  [_editBarButtonItem release];
  [_addBarButtonItem release];
  [_selectionToolbarBottomConstraint release];
  [_selectionToolbar release];
  [_selectedRecipeIDs release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  NSLog(@"%@ viewDidLoad - sessionUserID: %@, userRecipesStore: %@", MRRYoursViewControllerLogPrefix, self.sessionUserID ?: @"nil",
        self.userRecipesStore ? @"provided" : @"nil");

  self.title = @"Yours";
  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"yours.view";
  self.view.backgroundColor = MRRYoursCanvasColor();

  // Navigation bar buttons are set up based on state
  [self updateNavigationBarButtons];

  if (self.userRecipesStore != nil) {
    NSLog(@"%@ Registering for MRRUserRecipesStoreDidChangeNotification", MRRYoursViewControllerLogPrefix);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userRecipesStoreDidChange:)
                                                 name:MRRUserRecipesStoreDidChangeNotification
                                               object:self.userRecipesStore];
  } else {
    NSLog(@"%@ WARNING: userRecipesStore is nil - notification observer NOT registered", MRRYoursViewControllerLogPrefix);
  }

  [self buildViewHierarchy];
  [self loadRecipesFromStore];
  [self reloadContent];
  [self updateNavigationBarButtons];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  NSLog(@"%@ viewWillAppear - loading recipes from store", MRRYoursViewControllerLogPrefix);
  [self.navigationController setNavigationBarHidden:NO animated:animated];
  [self loadRecipesFromStore];
  [self reloadContent];
  [self updateNavigationBarButtons];
}

- (void)updateNavigationBarButtons {
  if (self.isSelectionMode) {
    // In selection mode: show Done button
    if (self.doneBarButtonItem == nil) {
      self.doneBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                              target:self
                                                                              action:@selector(handleDoneButtonTapped:)] autorelease];
      self.doneBarButtonItem.accessibilityIdentifier = @"yours.doneButton";
    }
    self.doneBarButtonItem.accessibilityLabel = @"Exit selection mode";
    self.doneBarButtonItem.accessibilityHint = @"Double-tap to cancel selection";
    self.doneBarButtonItem.tintColor = MRRYoursAccentColor();
    self.navigationItem.rightBarButtonItems = @[ self.doneBarButtonItem ];

    // Show selection count on left if items selected
    if (self.selectedRecipeIDs.count > 0) {
      NSString *countText = [NSString stringWithFormat:@"%lu selected", (unsigned long)self.selectedRecipeIDs.count];
      self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:countText style:UIBarButtonItemStylePlain target:nil
                                                                               action:nil] autorelease];
      self.navigationItem.leftBarButtonItem.enabled = NO;
    } else {
      self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Select Items"
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:nil
                                                                               action:nil] autorelease];
      self.navigationItem.leftBarButtonItem.enabled = NO;
    }
  } else {
    if (self.addBarButtonItem == nil) {
      self.addBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                             target:self
                                                                             action:@selector(handleAddButtonTapped:)] autorelease];
      self.addBarButtonItem.accessibilityIdentifier = @"yours.addButton";
    }
    self.addBarButtonItem.accessibilityLabel = @"Add recipe";
    self.addBarButtonItem.accessibilityHint = @"Double-tap to create a new recipe";
    self.addBarButtonItem.tintColor = MRRYoursAccentColor();

    // Not in selection mode: keep Add available and pair it with Edit when recipes exist
    if (self.recipes.count > 0) {
      if (self.editBarButtonItem == nil) {
        self.editBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                target:self
                                                                                action:@selector(handleEditButtonTapped:)] autorelease];
        self.editBarButtonItem.accessibilityIdentifier = @"yours.editButton";
      }
      self.editBarButtonItem.accessibilityLabel = @"Enter selection mode";
      self.editBarButtonItem.accessibilityHint = @"Double-tap to select multiple recipes";
      self.editBarButtonItem.tintColor = MRRYoursAccentColor();
      self.navigationItem.rightBarButtonItems = @[ self.addBarButtonItem, self.editBarButtonItem ];
    } else {
      self.navigationItem.rightBarButtonItems = @[ self.addBarButtonItem ];
    }

    // Clear left bar button item
    self.navigationItem.leftBarButtonItem = nil;
  }
}

- (void)buildViewHierarchy {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.alwaysBounceVertical = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  [self.view addSubview:scrollView];
  self.scrollView = scrollView;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  [scrollView addSubview:contentView];
  self.contentView = contentView;

  UIStackView *cardsStackView = [[[UIStackView alloc] init] autorelease];
  cardsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  cardsStackView.axis = UILayoutConstraintAxisVertical;
  cardsStackView.spacing = 18.0;
  cardsStackView.accessibilityIdentifier = @"yours.cardsStack";
  [contentView addSubview:cardsStackView];
  self.cardsStackView = cardsStackView;

  UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor], [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
    [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
    [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
    [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
    [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],

    [cardsStackView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20.0],
    [cardsStackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24.0],
    [cardsStackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
    [cardsStackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-28.0]
  ]];

  // Add a floating action bar for selection mode (hidden by default)
  UIView *toolbar = [[[UIView alloc] init] autorelease];
  toolbar.translatesAutoresizingMaskIntoConstraints = NO;
  toolbar.hidden = YES;
  toolbar.alpha = 0.0;
  toolbar.transform = CGAffineTransformMakeTranslation(0.0, 12.0);
  toolbar.accessibilityIdentifier = @"yours.selectionToolbar";
  toolbar.accessibilityLabel = @"Selection actions";
  toolbar.backgroundColor = MRRYoursSurfaceColor();
  toolbar.layer.cornerRadius = 26.0;
  toolbar.layer.borderWidth = 1.0;
  toolbar.layer.borderColor = MRRYoursBorderColor().CGColor;
  toolbar.layer.shadowColor = [UIColor blackColor].CGColor;
  toolbar.layer.shadowOffset = CGSizeMake(0.0, 10.0);
  toolbar.layer.shadowRadius = 22.0;
  toolbar.layer.shadowOpacity = 0.10;
  [self.view addSubview:toolbar];
  self.selectionToolbar = [toolbar retain];

  UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
  deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
  deleteButton.layer.cornerRadius = 18.0;
  deleteButton.backgroundColor = [MRRYoursDeleteColor() colorWithAlphaComponent:0.10];
  deleteButton.contentEdgeInsets = UIEdgeInsetsMake(12.0, 22.0, 12.0, 22.0);
  deleteButton.titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:17.0 weight:UIFontWeightSemibold];
  deleteButton.titleLabel.numberOfLines = 1;
  deleteButton.titleLabel.lineBreakMode = NSLineBreakByClipping;
  deleteButton.titleLabel.adjustsFontSizeToFitWidth = NO;
  deleteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  [deleteButton setTitle:@"Delete" forState:UIControlStateNormal];
  [deleteButton setTitleColor:MRRYoursDeleteColor() forState:UIControlStateNormal];
  [deleteButton setTitleColor:[MRRYoursDeleteColor() colorWithAlphaComponent:0.38] forState:UIControlStateDisabled];
  deleteButton.accessibilityIdentifier = @"yours.deleteToolbarButton";
  deleteButton.accessibilityHint = @"Double-tap to delete selected recipes";
  [deleteButton addTarget:self action:@selector(handleDeleteToolbarButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [toolbar addSubview:deleteButton];
  self.deleteToolbarButton = [deleteButton retain];

  self.selectionToolbarBottomConstraint = [[toolbar.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor
                                                                                constant:-14.0] retain];
  [NSLayoutConstraint activateConstraints:@[
    [toolbar.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [toolbar.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
    [toolbar.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0],
    [toolbar.widthAnchor constraintEqualToConstant:MRRYoursSelectionToolbarWidth()],
    [toolbar.heightAnchor constraintGreaterThanOrEqualToConstant:72.0], self.selectionToolbarBottomConstraint,

    [deleteButton.topAnchor constraintEqualToAnchor:toolbar.topAnchor constant:12.0],
    [deleteButton.centerXAnchor constraintEqualToAnchor:toolbar.centerXAnchor],
    [deleteButton.widthAnchor constraintEqualToConstant:MRRYoursDeleteButtonWidth()],
    [deleteButton.bottomAnchor constraintEqualToAnchor:toolbar.bottomAnchor constant:-12.0]
  ]];
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.font = font;
  label.textColor = color;
  label.adjustsFontForContentSizeCategory = YES;
  return label;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title filled:(BOOL)filled {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  [button setTitle:title forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
  button.layer.cornerRadius = 12.0;
  button.contentEdgeInsets = UIEdgeInsetsMake(10.0, 14.0, 10.0, 14.0);
  button.backgroundColor = filled ? MRRYoursAccentColor() : MRRYoursMutedSurfaceColor();
  [button setTitleColor:(filled ? [UIColor whiteColor] : MRRYoursPrimaryTextColor()) forState:UIControlStateNormal];
  [button.heightAnchor constraintGreaterThanOrEqualToConstant:42.0].active = YES;
  return button;
}

- (void)loadRecipesFromStore {
  NSLog(@"%@ loadRecipesFromStore - userRecipesStore: %@, sessionUserID: '%@'", MRRYoursViewControllerLogPrefix,
        self.userRecipesStore ? @"provided" : @"nil", self.sessionUserID ?: @"nil");

  NSArray<MRRUserRecipeSnapshot *> *recipes = @[];
  if (self.userRecipesStore != nil && self.sessionUserID.length > 0) {
    NSError *fetchError = nil;
    NSArray<MRRUserRecipeSnapshot *> *fetchedRecipes = [self.userRecipesStore userRecipesForUserID:self.sessionUserID error:&fetchError];
    if (fetchError == nil && fetchedRecipes != nil) {
      recipes = fetchedRecipes;
      NSLog(@"%@ Loaded %lu recipes from store", MRRYoursViewControllerLogPrefix, (unsigned long)recipes.count);
    } else {
      NSLog(@"%@ FAILED to load recipes - error: %@", MRRYoursViewControllerLogPrefix, fetchError ?: @"unknown");
    }
  } else {
    NSLog(@"%@ SKIPPING load - userRecipesStore: %@, sessionUserID.length: %lu", MRRYoursViewControllerLogPrefix,
          self.userRecipesStore ? @"provided" : @"nil", (unsigned long)self.sessionUserID.length);
  }
  self.recipes = recipes;
}

- (void)reloadContent {
  NSLog(@"%@ reloadContent - %lu recipes to display", MRRYoursViewControllerLogPrefix, (unsigned long)self.recipes.count);

  while (self.cardsStackView.arrangedSubviews.count > 0) {
    UIView *subview = self.cardsStackView.arrangedSubviews.firstObject;
    [self.cardsStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  if (self.recipes.count == 0) {
    NSLog(@"%@ Showing empty state view", MRRYoursViewControllerLogPrefix);
    [self.cardsStackView addArrangedSubview:[self emptyStateView]];
    return;
  }

  for (MRRUserRecipeSnapshot *recipe in self.recipes) {
    [self.cardsStackView addArrangedSubview:[self recipeCardViewForRecipe:recipe]];
  }
  NSLog(@"%@ Displayed %lu recipe cards", MRRYoursViewControllerLogPrefix, (unsigned long)self.recipes.count);
}

- (UIView *)emptyStateView {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.backgroundColor = MRRYoursSurfaceColor();
  containerView.layer.cornerRadius = 24.0;
  containerView.layer.borderWidth = 1.0;
  containerView.layer.borderColor = MRRYoursBorderColor().CGColor;

  UILabel *titleLabel = [self labelWithFont:[UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold] color:MRRYoursPrimaryTextColor()];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.textAlignment = NSTextAlignmentCenter;
  titleLabel.numberOfLines = 0;
  titleLabel.text = @"You haven't created any recipes yet.";
  titleLabel.accessibilityIdentifier = @"yours.emptyStateLabel";
  [containerView addSubview:titleLabel];
  self.emptyStateLabel = titleLabel;

  UILabel *subtitleLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular] color:MRRYoursSecondaryTextColor()];
  subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  subtitleLabel.textAlignment = NSTextAlignmentCenter;
  subtitleLabel.numberOfLines = 0;
  subtitleLabel.text = @"Create your first recipe and we'll keep it in Core Data while syncing URL-based media metadata when available.";
  [containerView addSubview:subtitleLabel];

  UIButton *createButton = [self actionButtonWithTitle:@"Create Recipe" filled:YES];
  createButton.accessibilityIdentifier = @"yours.emptyStateButton";
  [createButton addTarget:self action:@selector(handleAddButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [containerView addSubview:createButton];
  self.emptyStateButton = createButton;

  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:28.0],
    [titleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:24.0],
    [titleLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-24.0],

    [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12.0],
    [subtitleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:24.0],
    [subtitleLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-24.0],

    [createButton.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:20.0],
    [createButton.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
    [createButton.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-28.0]
  ]];

  return containerView;
}

- (UIView *)recipeCardViewForRecipe:(MRRUserRecipeSnapshot *)recipe {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.backgroundColor = MRRYoursSurfaceColor();
  containerView.layer.cornerRadius = 22.0;
  containerView.layer.borderWidth = 1.0;
  containerView.layer.borderColor = MRRYoursBorderColor().CGColor;
  containerView.accessibilityIdentifier = [MRRYoursRecipeCardIdentifierPrefix stringByAppendingString:recipe.recipeID];

  // Add shadow for press animation effect
  containerView.layer.shadowColor = [UIColor blackColor].CGColor;
  containerView.layer.shadowOffset = CGSizeMake(0.0, 4.0);
  containerView.layer.shadowRadius = 8.0;
  containerView.layer.shadowOpacity = 0.14;

  // Cover image view for recipe photo (main/large image)
  UIImageView *coverImageView = [[[UIImageView alloc] init] autorelease];
  coverImageView.translatesAutoresizingMaskIntoConstraints = NO;
  coverImageView.contentMode = UIViewContentModeScaleAspectFill;
  coverImageView.clipsToBounds = YES;
  coverImageView.layer.cornerRadius = 16.0;
  coverImageView.backgroundColor = MRRYoursMutedSurfaceColor();
  coverImageView.userInteractionEnabled = YES;
  coverImageView.accessibilityIdentifier = [MRRYoursRecipeCoverImageIdentifierPrefix stringByAppendingString:recipe.recipeID];
  [containerView addSubview:coverImageView];

  // Load cover image if available (first photo)
  MRRUserRecipePhotoSnapshot *coverPhoto = recipe.coverPhotoSnapshot;
  UIImage *coverImage = nil;
  if (coverPhoto != nil && coverPhoto.localRelativePath.length > 0) {
    coverImage = [self.photoStorage imageForRelativePath:coverPhoto.localRelativePath];
    if (coverImage != nil) {
      coverImageView.image = coverImage;
    }
  }

  // Add tap gesture to cover image for popup
  if (coverImage != nil) {
    UITapGestureRecognizer *coverTapGesture = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleImageTapped:)] autorelease];
    [coverImageView addGestureRecognizer:coverTapGesture];
  }

  // Add additional photos (excluding cover) as a clean horizontal strip.
  NSArray<MRRUserRecipePhotoSnapshot *> *photos = recipe.photos;
  NSArray<MRRUserRecipePhotoSnapshot *> *additionalPhotos = photos.count > 1 ? [photos subarrayWithRange:NSMakeRange(1, photos.count - 1)] : @[];
  BOOL hasAdditionalPhotos = additionalPhotos.count > 0;
  BOOL isExpanded = [self.expandedRecipeIDs containsObject:recipe.recipeID];

  // Toggle header view for sub-images (only if there are additional photos)
  UIButton *toggleHeaderButton = nil;
  if (hasAdditionalPhotos) {
    toggleHeaderButton = [UIButton buttonWithType:UIButtonTypeSystem];
    toggleHeaderButton.translatesAutoresizingMaskIntoConstraints = NO;
    toggleHeaderButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    toggleHeaderButton.accessibilityIdentifier = [MRRYoursRecipeThumbnailsToggleIdentifierPrefix stringByAppendingString:recipe.recipeID];
    [toggleHeaderButton addTarget:self action:@selector(handleThumbnailsToggleTapped:) forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:toggleHeaderButton];

    // Create chevron icon and count label
    UIImage *chevronImage = nil;
    if (@available(iOS 13.0, *)) {
      chevronImage = [UIImage systemImageNamed:isExpanded ? @"chevron.down" : @"chevron.right"];
    }
    [toggleHeaderButton setImage:chevronImage forState:UIControlStateNormal];

    NSString *countText =
        [NSString stringWithFormat:@"%lu additional photo%@", (unsigned long)additionalPhotos.count, additionalPhotos.count == 1 ? @"" : @"s"];
    [toggleHeaderButton setTitle:countText forState:UIControlStateNormal];
    toggleHeaderButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [toggleHeaderButton setTitleColor:MRRYoursSecondaryTextColor() forState:UIControlStateNormal];
    toggleHeaderButton.tintColor = MRRYoursSecondaryTextColor();
    toggleHeaderButton.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8.0);
    toggleHeaderButton.titleEdgeInsets = UIEdgeInsetsMake(0, 8.0, 0, -8.0);
  }

  // Scrollable container for stacked photo thumbnails
  UIScrollView *thumbnailsScrollView = [[[UIScrollView alloc] init] autorelease];
  thumbnailsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
  thumbnailsScrollView.showsHorizontalScrollIndicator = NO;
  thumbnailsScrollView.alwaysBounceHorizontal = YES;
  thumbnailsScrollView.clipsToBounds = YES;
  thumbnailsScrollView.accessibilityIdentifier = [MRRYoursRecipeThumbnailsIdentifierPrefix stringByAppendingString:recipe.recipeID];
  [containerView addSubview:thumbnailsScrollView];

  // Inner content view for scroll view
  UIStackView *thumbnailsStackView = [[[UIStackView alloc] init] autorelease];
  thumbnailsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  thumbnailsStackView.axis = UILayoutConstraintAxisHorizontal;
  thumbnailsStackView.alignment = UIStackViewAlignmentCenter;
  thumbnailsStackView.distribution = UIStackViewDistributionFill;
  thumbnailsStackView.spacing = MRRYoursRecipeThumbnailSpacing;
  [thumbnailsScrollView addSubview:thumbnailsStackView];

  CGFloat thumbnailsContentHeight = hasAdditionalPhotos ? MRRYoursRecipeThumbnailSize : 0.0;
  [NSLayoutConstraint activateConstraints:@[
    [thumbnailsStackView.topAnchor constraintEqualToAnchor:thumbnailsScrollView.contentLayoutGuide.topAnchor],
    [thumbnailsStackView.leadingAnchor constraintEqualToAnchor:thumbnailsScrollView.contentLayoutGuide.leadingAnchor],
    [thumbnailsStackView.trailingAnchor constraintEqualToAnchor:thumbnailsScrollView.contentLayoutGuide.trailingAnchor],
    [thumbnailsStackView.bottomAnchor constraintEqualToAnchor:thumbnailsScrollView.contentLayoutGuide.bottomAnchor],
    [thumbnailsStackView.heightAnchor constraintEqualToConstant:thumbnailsContentHeight],
    [thumbnailsStackView.widthAnchor constraintGreaterThanOrEqualToAnchor:thumbnailsScrollView.frameLayoutGuide.widthAnchor]
  ]];

  // Store height constraint for animation
  NSLayoutConstraint *thumbnailsHeightConstraint = [thumbnailsScrollView.heightAnchor constraintEqualToConstant:0];
  thumbnailsHeightConstraint.active = YES;
  if (hasAdditionalPhotos) {
    self.thumbnailsHeightConstraints[recipe.recipeID] = thumbnailsHeightConstraint;
    thumbnailsHeightConstraint.constant = isExpanded ? MRRYoursRecipeThumbnailSize : 0;
  }

  if (hasAdditionalPhotos) {
    for (NSUInteger i = 0; i < additionalPhotos.count; i++) {
      MRRUserRecipePhotoSnapshot *photo = additionalPhotos[i];

      // Container for shadow - elevated/lifted effect
      UIView *thumbnailContainer = [[[UIView alloc] init] autorelease];
      thumbnailContainer.translatesAutoresizingMaskIntoConstraints = NO;
      thumbnailContainer.backgroundColor = MRRYoursMutedSurfaceColor();
      thumbnailContainer.layer.shadowColor = [UIColor blackColor].CGColor;
      thumbnailContainer.layer.shadowOffset = CGSizeMake(0, 4);
      thumbnailContainer.layer.shadowRadius = 8.0;
      thumbnailContainer.layer.shadowOpacity = 0.14;
      thumbnailContainer.layer.masksToBounds = NO;
      thumbnailContainer.accessibilityIdentifier =
          [NSString stringWithFormat:@"%@%@.%lu", MRRYoursRecipeThumbnailIdentifierPrefix, recipe.recipeID, (unsigned long)i];
      [thumbnailContainer.widthAnchor constraintEqualToConstant:MRRYoursRecipeThumbnailSize].active = YES;
      [thumbnailContainer.heightAnchor constraintEqualToConstant:MRRYoursRecipeThumbnailSize].active = YES;
      [thumbnailsStackView addArrangedSubview:thumbnailContainer];

      UIImageView *thumbnailView = [[[UIImageView alloc] init] autorelease];
      thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
      thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
      thumbnailView.clipsToBounds = YES;
      thumbnailView.layer.cornerRadius = 12.0;
      thumbnailView.backgroundColor = MRRYoursMutedSurfaceColor();
      thumbnailView.userInteractionEnabled = YES;
      [thumbnailContainer addSubview:thumbnailView];

      [NSLayoutConstraint activateConstraints:@[
        [thumbnailView.topAnchor constraintEqualToAnchor:thumbnailContainer.topAnchor],
        [thumbnailView.leadingAnchor constraintEqualToAnchor:thumbnailContainer.leadingAnchor],
        [thumbnailView.trailingAnchor constraintEqualToAnchor:thumbnailContainer.trailingAnchor],
        [thumbnailView.bottomAnchor constraintEqualToAnchor:thumbnailContainer.bottomAnchor]
      ]];

      if (photo.localRelativePath.length > 0) {
        UIImage *image = [self.photoStorage imageForRelativePath:photo.localRelativePath];
        if (image != nil) {
          thumbnailView.image = image;
          UITapGestureRecognizer *thumbnailTapGesture = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                 action:@selector(handleImageTapped:)] autorelease];
          [thumbnailView addGestureRecognizer:thumbnailTapGesture];
        }
      }
    }

    UIView *trailingSpacer = [[[UIView alloc] init] autorelease];
    trailingSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    [trailingSpacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [trailingSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [thumbnailsStackView addArrangedSubview:trailingSpacer];
  }

  UILabel *titleLabel = [self labelWithFont:[UIFont systemFontOfSize:22.0 weight:UIFontWeightSemibold] color:MRRYoursPrimaryTextColor()];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.text = recipe.title;
  titleLabel.numberOfLines = 0;
  [containerView addSubview:titleLabel];

  UILabel *subtitleLabel = [self labelWithFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium] color:MRRYoursSecondaryTextColor()];
  subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  subtitleLabel.text = recipe.subtitle.length > 0 ? recipe.subtitle : @"No subtitle";
  subtitleLabel.numberOfLines = 0;
  [containerView addSubview:subtitleLabel];

  UILabel *metadataLabel = [self labelWithFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold] color:MRRYoursAccentColor()];
  metadataLabel.translatesAutoresizingMaskIntoConstraints = NO;
  metadataLabel.text = [self metadataTextForRecipe:recipe];
  metadataLabel.numberOfLines = 0;
  [containerView addSubview:metadataLabel];

  UILabel *summaryLabel = [self labelWithFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular] color:MRRYoursPrimaryTextColor()];
  summaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
  summaryLabel.text = recipe.summaryText.length > 0 ? recipe.summaryText : @"No summary yet.";
  summaryLabel.numberOfLines = 0;
  [containerView addSubview:summaryLabel];

  UILabel *updatedLabel = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium] color:MRRYoursSecondaryTextColor()];
  updatedLabel.translatesAutoresizingMaskIntoConstraints = NO;
  updatedLabel.text = [self updatedTextForRecipe:recipe];
  updatedLabel.numberOfLines = 0;
  [containerView addSubview:updatedLabel];

  // Setup context menu based on iOS version
  if (@available(iOS 13.0, *)) {
    // Use native UIContextMenuInteraction for modern iOS
    UIContextMenuInteraction *interaction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
    [containerView addInteraction:interaction];
    [interaction release];  // View retains the interaction
  } else {
    // iOS 12 fallback: Use custom long-press gesture
    UILongPressGestureRecognizer *longPressGesture =
        [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleRecipeCardLongPress:)] autorelease];
    longPressGesture.minimumPressDuration = 0.3;  // Optimized for faster response
    longPressGesture.cancelsTouchesInView = YES;
    [containerView addGestureRecognizer:longPressGesture];
  }

  // Add selection checkmark overlay (hidden by default)
  UIButton *selectButton = [UIButton buttonWithType:UIButtonTypeCustom];
  selectButton.translatesAutoresizingMaskIntoConstraints = NO;
  selectButton.accessibilityIdentifier = [NSString stringWithFormat:@"yours.selectButton.%@", recipe.recipeID];

  // Accessibility
  selectButton.accessibilityLabel = [NSString stringWithFormat:@"Select %@", recipe.title ?: @"recipe"];
  selectButton.accessibilityHint = @"Double-tap to toggle selection";
  selectButton.accessibilityTraits = UIAccessibilityTraitButton;

  // Set checkmark images (selected/unselected states)
  UIImage *uncheckedImage = nil;
  UIImage *checkedImage = nil;
  if (@available(iOS 13.0, *)) {
    uncheckedImage = [UIImage systemImageNamed:@"circle"];
    checkedImage = [UIImage systemImageNamed:@"checkmark.circle.fill"];
  } else {
    // Fallback for iOS 12 - create simple circle images
    uncheckedImage = [self circularImageWithSize:CGSizeMake(28, 28) fillColor:[UIColor clearColor] strokeColor:MRRYoursAccentColor()];
    checkedImage = [self circularImageWithSize:CGSizeMake(28, 28) fillColor:MRRYoursAccentColor() strokeColor:MRRYoursAccentColor()];
  }

  [selectButton setImage:uncheckedImage forState:UIControlStateNormal];
  [selectButton setImage:checkedImage forState:UIControlStateSelected];
  selectButton.tintColor = MRRYoursAccentColor();
  selectButton.layer.cornerRadius = 16.0;
  selectButton.alpha = 0.0;  // Hidden by default, shown in selection mode
  selectButton.hidden = YES;

  // Store recipeID as associated object for tap handling
  objc_setAssociatedObject(selectButton, @selector(recipeID), recipe.recipeID, OBJC_ASSOCIATION_COPY_NONATOMIC);

  [selectButton addTarget:self action:@selector(handleSelectButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [containerView addSubview:selectButton];

  // Constraints for select button (top-right corner)
  [NSLayoutConstraint activateConstraints:@[
    [selectButton.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:12.0],
    [selectButton.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-12.0],
    [selectButton.widthAnchor constraintEqualToConstant:32.0], [selectButton.heightAnchor constraintEqualToConstant:32.0]
  ]];

  // Update selection state if already selected
  BOOL isSelected = [self.selectedRecipeIDs containsObject:recipe.recipeID];
  selectButton.selected = isSelected;
  selectButton.backgroundColor = isSelected ? MRRYoursAccentColor() : [UIColor clearColor];
  selectButton.alpha = self.isSelectionMode ? 1.0 : 0.0;
  selectButton.hidden = !self.isSelectionMode;

  // Add tap gesture to card for selection mode
  UITapGestureRecognizer *cardTapGesture = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(handleCardTappedForSelection:)] autorelease];
  cardTapGesture.cancelsTouchesInView = NO;  // Allow other gestures to work
  [containerView addGestureRecognizer:cardTapGesture];

  [NSLayoutConstraint activateConstraints:@[
    [coverImageView.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:20.0],
    [coverImageView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:20.0],
    [coverImageView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-20.0],
    [coverImageView.heightAnchor constraintEqualToConstant:180.0],
  ]];

  // Layout for toggle header and thumbnails (conditional)
  NSMutableArray<NSLayoutConstraint *> *dynamicConstraints = [NSMutableArray array];

  if (hasAdditionalPhotos && toggleHeaderButton != nil) {
    [dynamicConstraints addObjectsFromArray:@[
      [toggleHeaderButton.topAnchor constraintEqualToAnchor:coverImageView.bottomAnchor constant:12.0],
      [toggleHeaderButton.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:20.0],
      [toggleHeaderButton.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-20.0],
      [toggleHeaderButton.heightAnchor constraintEqualToConstant:MRRYoursRecipeThumbnailsHeaderHeight],

      [thumbnailsScrollView.topAnchor constraintEqualToAnchor:toggleHeaderButton.bottomAnchor constant:4.0],
      [thumbnailsScrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:20.0],
      [thumbnailsScrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-20.0],

      [titleLabel.topAnchor constraintEqualToAnchor:thumbnailsScrollView.bottomAnchor constant:12.0],
    ]];
  } else {
    [dynamicConstraints addObjectsFromArray:@[
      [thumbnailsScrollView.topAnchor constraintEqualToAnchor:coverImageView.bottomAnchor constant:0],
      [thumbnailsScrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:20.0],
      [thumbnailsScrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-20.0],

      [titleLabel.topAnchor constraintEqualToAnchor:thumbnailsScrollView.bottomAnchor constant:12.0],
    ]];
  }

  [dynamicConstraints addObjectsFromArray:@[
    [titleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:20.0],
    [titleLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-20.0],

    [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
    [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
    [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

    [metadataLabel.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:14.0],
    [metadataLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
    [metadataLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

    [summaryLabel.topAnchor constraintEqualToAnchor:metadataLabel.bottomAnchor constant:12.0],
    [summaryLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
    [summaryLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],

    [updatedLabel.topAnchor constraintEqualToAnchor:summaryLabel.bottomAnchor constant:14.0],
    [updatedLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
    [updatedLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
    [updatedLabel.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-20.0]
  ]];

  [NSLayoutConstraint activateConstraints:dynamicConstraints];

  return containerView;
}

- (nullable MRRUserRecipeSnapshot *)recipeForIdentifier:(NSString *)recipeIdentifier {
  if (recipeIdentifier.length == 0) {
    return nil;
  }
  for (MRRUserRecipeSnapshot *recipe in self.recipes) {
    if ([recipe.recipeID isEqualToString:recipeIdentifier]) {
      return recipe;
    }
  }
  return nil;
}

- (nullable NSString *)recipeIdentifierFromButton:(UIButton *)button prefix:(NSString *)prefix {
  NSString *identifier = button.accessibilityIdentifier ?: @"";
  if (![identifier hasPrefix:prefix]) {
    return nil;
  }
  return [identifier substringFromIndex:prefix.length];
}

- (NSString *)metadataTextForRecipe:(MRRUserRecipeSnapshot *)recipe {
  NSString *mealType = [MRRUserRecipeSnapshot normalizedMealTypeFromString:recipe.mealType];
  NSString *capitalizedMealType = [mealType.capitalizedString copy];
  NSString *metadata = [NSString stringWithFormat:@"%@  •  %@  •  %@", capitalizedMealType, recipe.durationText, recipe.servingsText];
  [capitalizedMealType release];
  return metadata;
}

- (NSString *)updatedTextForRecipe:(MRRUserRecipeSnapshot *)recipe {
  NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
  formatter.dateStyle = NSDateFormatterMediumStyle;
  formatter.timeStyle = NSDateFormatterShortStyle;
  return [NSString stringWithFormat:@"Updated %@", [formatter stringFromDate:recipe.localModifiedAt]];
}

- (UIImage *)circularImageWithSize:(CGSize)size fillColor:(UIColor *)fillColor strokeColor:(UIColor *)strokeColor {
  UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
  CGContextRef context = UIGraphicsGetCurrentContext();

  CGRect rect = CGRectMake(2, 2, size.width - 4, size.height - 4);
  CGContextSetFillColorWithColor(context, fillColor.CGColor);
  CGContextSetStrokeColorWithColor(context, strokeColor.CGColor);
  CGContextSetLineWidth(context, 2.0);

  CGContextFillEllipseInRect(context, rect);
  CGContextStrokeEllipseInRect(context, rect);

  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)presentEditorForRecipe:(MRRUserRecipeSnapshot *)recipe {
  if (recipe != nil) {
    NSLog(@"%@ presentEditorForRecipe - Editing existing recipe: %@ (ID: %@)", MRRYoursViewControllerLogPrefix, recipe.title ?: @"untitled",
          recipe.recipeID ?: @"nil");
  } else {
    NSLog(@"%@ presentEditorForRecipe - Creating NEW recipe", MRRYoursViewControllerLogPrefix);
  }

  NSLog(@"%@ Editor dependencies - sessionUserID: %@, userRecipesStore: %@, syncEngine: %@", MRRYoursViewControllerLogPrefix,
        self.sessionUserID ?: @"nil", self.userRecipesStore ? @"provided" : @"nil", self.syncEngine ? @"provided" : @"nil");

  MRRYoursRecipeEditorViewController *editorViewController = [[[MRRYoursRecipeEditorViewController alloc] initWithSessionUserID:self.sessionUserID
                                                                                                               userRecipesStore:self.userRecipesStore
                                                                                                                     syncEngine:self.syncEngine
                                                                                                                   photoStorage:self.photoStorage
                                                                                                                 existingRecipe:recipe] autorelease];
  [self.navigationController pushViewController:editorViewController animated:YES];
  NSLog(@"%@ Editor pushed to navigation stack", MRRYoursViewControllerLogPrefix);
}

- (BOOL)deleteRecipeWithIdentifier:(NSString *)recipeIdentifier error:(NSError **)error {
  if (self.userRecipesStore == nil || self.sessionUserID.length == 0 || recipeIdentifier.length == 0) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRYoursViewControllerErrorDomain
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : @"Recipe could not be removed."}];
    }
    return NO;
  }

  BOOL didDelete = [self.userRecipesStore removeRecipeForUserID:self.sessionUserID recipeID:recipeIdentifier error:error];
  if (didDelete) {
    [self.photoStorage removeImagesForRecipeID:recipeIdentifier error:nil];
    [self.syncEngine requestImmediateSyncForUserID:self.sessionUserID];
  }
  return didDelete;
}

- (void)presentValidationError:(NSError *)error title:(NSString *)title {
  NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : @"Please try again in a moment.";
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
  UIViewController *presenter = self.presentedViewController ?: self;
  [presenter presentViewController:alertController animated:YES completion:nil];
}

- (void)handleAddButtonTapped:(id)sender {
#pragma unused(sender)
  NSLog(@"%@ handleAddButtonTapped - User wants to add new recipe", MRRYoursViewControllerLogPrefix);
  NSLog(@"%@ Current state - sessionUserID: %@, userRecipesStore: %@", MRRYoursViewControllerLogPrefix, self.sessionUserID ?: @"nil",
        self.userRecipesStore ? @"provided" : @"nil");
  [self presentEditorForRecipe:nil];
}

- (void)handleEditButtonTapped:(id)sender {
#pragma unused(sender)
  // Enter selection mode
  self.isSelectionMode = YES;
  [self updateNavigationBarButtons];
  [self updateAllCardsSelectionVisibility];
  [self updateToolbarVisibility];
}

- (void)handleDoneButtonTapped:(id)sender {
#pragma unused(sender)
  // Exit selection mode
  self.isSelectionMode = NO;
  [self.selectedRecipeIDs removeAllObjects];
  [self updateNavigationBarButtons];
  [self updateAllCardsSelectionVisibility];
  [self updateToolbarVisibility];

  // Announce exit for VoiceOver
  UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"Selection mode exited");
}

- (void)updateAllCardsSelectionVisibility {
  // Announce mode change for VoiceOver
  if (self.isSelectionMode) {
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, @"Selection mode enabled. Tap recipes to select.");
  }

  for (UIView *cardView in self.cardsStackView.arrangedSubviews) {
    NSString *cardIdentifier = cardView.accessibilityIdentifier ?: @"";
    NSString *recipeID = [cardIdentifier stringByReplacingOccurrencesOfString:MRRYoursRecipeCardIdentifierPrefix withString:@""];

    // Find the select button in this card
    for (UIView *subview in cardView.subviews) {
      if ([subview isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)subview;
        NSString *identifier = button.accessibilityIdentifier ?: @"";
        if ([identifier hasPrefix:@"yours.selectButton."]) {
          // Update visibility
          button.alpha = self.isSelectionMode ? 1.0 : 0.0;
          button.hidden = !self.isSelectionMode;

          // Update selection state
          BOOL isSelected = [self.selectedRecipeIDs containsObject:recipeID];
          button.selected = isSelected;
        }
      }
    }

    // Update card border
    [self updateCardSelectionVisuals:recipeID];
  }
}

- (void)updateToolbarVisibility {
  // Show toolbar in selection mode when there are selected items
  BOOL shouldShowToolbar = self.isSelectionMode && self.selectedRecipeIDs.count > 0;
  NSString *deleteTitle = shouldShowToolbar ? [NSString stringWithFormat:@"Delete (%lu)", (unsigned long)self.selectedRecipeIDs.count] : @"Delete";
  UIEdgeInsets scrollInsets = self.scrollView.contentInset;
  scrollInsets.bottom = shouldShowToolbar ? 116.0 : 0.0;
  UIEdgeInsets indicatorInsets = self.scrollView.scrollIndicatorInsets;
  indicatorInsets.bottom = scrollInsets.bottom;

  [UIView performWithoutAnimation:^{
    [self.deleteToolbarButton setTitle:deleteTitle forState:UIControlStateNormal];
    [self.selectionToolbar layoutIfNeeded];
  }];

  // Update toolbar visibility with animation
  if (shouldShowToolbar) {
    self.selectionToolbar.hidden = NO;
  }
  [UIView animateWithDuration:0.25
      animations:^{
        self.selectionToolbar.alpha = shouldShowToolbar ? 1.0 : 0.0;
        self.selectionToolbar.transform = shouldShowToolbar ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 12.0);
        self.scrollView.contentInset = scrollInsets;
        self.scrollView.scrollIndicatorInsets = indicatorInsets;
      }
      completion:^(BOOL finished) {
        if (finished) {
          self.selectionToolbar.hidden = !shouldShowToolbar;
        }
      }];
  if (!shouldShowToolbar) {
    self.selectionToolbarBottomConstraint.constant = -14.0;
  }

  // Update delete button title with count
  if (self.selectedRecipeIDs.count > 0) {
    self.deleteToolbarButton.enabled = YES;
    // Update accessibility label with count
    NSString *accessibilityLabel = [NSString
        stringWithFormat:@"Delete %lu recipe%@", (unsigned long)self.selectedRecipeIDs.count, self.selectedRecipeIDs.count == 1 ? @"" : @"s"];
    self.deleteToolbarButton.accessibilityLabel = accessibilityLabel;
  } else {
    self.deleteToolbarButton.enabled = NO;
  }
}

- (void)handleDeleteToolbarButtonTapped:(id)sender {
#pragma unused(sender)

  NSUInteger count = self.selectedRecipeIDs.count;
  if (count == 0) {
    return;
  }

  NSString *title = [NSString stringWithFormat:@"Delete %lu Recipe%@?", (unsigned long)count, count == 1 ? @"" : @"s"];
  NSString *message = [NSString
      stringWithFormat:@"This will permanently delete %lu recipe%@. This action cannot be undone.", (unsigned long)count, count == 1 ? @"" : @"s"];

  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"yours.bulkDeleteAlert";

  [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

  [alertController addAction:[UIAlertAction actionWithTitle:@"Delete"
                                                      style:UIAlertActionStyleDestructive
                                                    handler:^(UIAlertAction *action) {
                                                      [self performBulkDelete];
                                                    }]];

  UIViewController *presenter = self.presentedViewController ?: self;
  [presenter presentViewController:alertController animated:YES completion:nil];
}

- (void)performBulkDelete {
  NSLog(@"%@ performBulkDelete - deleting %lu recipes", MRRYoursViewControllerLogPrefix, (unsigned long)self.selectedRecipeIDs.count);

  NSMutableArray<NSError *> *errors = [NSMutableArray array];
  NSUInteger successCount = 0;

  // Delete each selected recipe
  for (NSString *recipeID in self.selectedRecipeIDs) {
    NSError *error = nil;
    BOOL deleted = [self deleteRecipeWithIdentifier:recipeID error:&error];
    if (deleted) {
      successCount++;
    } else if (error != nil) {
      [errors addObject:error];
    }
  }

  // Log results
  NSLog(@"%@ Bulk delete complete - %lu succeeded, %lu failed", MRRYoursViewControllerLogPrefix, (unsigned long)successCount,
        (unsigned long)errors.count);

  // Show error if any deletions failed
  if (errors.count > 0) {
    NSError *firstError = errors.firstObject;
    NSString *errorTitle = errors.count == 1 ? @"Couldn't Delete Recipe" : @"Couldn't Delete Some Recipes";
    [self presentValidationError:firstError title:errorTitle];
  }

  // Exit selection mode and refresh
  self.isSelectionMode = NO;
  [self.selectedRecipeIDs removeAllObjects];
  [self updateNavigationBarButtons];
  [self updateAllCardsSelectionVisibility];
  [self updateToolbarVisibility];

  // Reload recipes
  [self loadRecipesFromStore];
  [self reloadContent];
}

- (void)handleDeleteButtonTapped:(UIButton *)sender {
  NSString *recipeIdentifier = [self recipeIdentifierFromButton:sender prefix:MRRYoursRecipeDeleteButtonIdentifierPrefix];
  MRRUserRecipeSnapshot *recipe = [self recipeForIdentifier:recipeIdentifier];
  if (recipe == nil) {
    return;
  }

  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Delete Recipe?"
                                                                           message:@"This removes the recipe locally and queues a Firestore delete."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"yours.deleteAlert";
  [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [alertController addAction:[UIAlertAction actionWithTitle:@"Delete"
                                                      style:UIAlertActionStyleDestructive
                                                    handler:^(__unused UIAlertAction *action) {
                                                      NSError *error = nil;
                                                      if (![self deleteRecipeWithIdentifier:recipe.recipeID error:&error] && error != nil) {
                                                        [self presentValidationError:error title:@"Couldn't delete recipe"];
                                                      }
                                                    }]];
  UIViewController *presenter = self.presentedViewController ?: self;
  [presenter presentViewController:alertController animated:YES completion:nil];
}

- (void)handleImageTapped:(UITapGestureRecognizer *)recognizer {
  UIImageView *imageView = (UIImageView *)recognizer.view;
  UIImage *image = imageView.image;
  if (image == nil) {
    return;
  }
  [self presentImagePopupWithImage:image];
}

- (void)handleRecipeCardLongPress:(UILongPressGestureRecognizer *)gesture {
  // Handle different states of the long press
  switch (gesture.state) {
    case UIGestureRecognizerStateBegan: {
      // Get recipe from gesture view
      UIView *cardView = gesture.view;
      NSString *cardID = cardView.accessibilityIdentifier ?: @"";
      NSString *recipeID = [cardID stringByReplacingOccurrencesOfString:MRRYoursRecipeCardIdentifierPrefix withString:@""];
      MRRUserRecipeSnapshot *recipe = [self recipeForIdentifier:recipeID];

      if (recipe == nil) {
        return;
      }

      // Animate card press down with scale transform
      [self animateCardPressDown:cardView];

      // Present beautiful animated context menu
      [self presentContextMenuForRecipe:recipe fromCardView:cardView];
      break;
    }

    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled: {
      // Animate card release
      UIView *cardView = gesture.view;
      [self animateCardPressRelease:cardView];
      break;
    }

    default:
      break;
  }
}

- (void)animateCardPressDown:(UIView *)cardView {
  // Scale down animation with spring anticipation
  [UIView animateWithDuration:0.20
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     cardView.transform = CGAffineTransformMakeScale(0.96, 0.96);
                     cardView.alpha = 0.92;
                     // Enhance shadow during press
                     cardView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
                     cardView.layer.shadowRadius = 12.0;
                     cardView.layer.shadowOpacity = 0.22;
                   }
                   completion:nil];
}

- (void)animateCardPressRelease:(UIView *)cardView {
  // Spring back animation
  [UIView animateWithDuration:0.25
                        delay:0.0
       usingSpringWithDamping:0.85
        initialSpringVelocity:0.4
                      options:UIViewAnimationOptionBeginFromCurrentState
                   animations:^{
                     cardView.transform = CGAffineTransformIdentity;
                     cardView.alpha = 1.0;
                     // Restore original shadow
                     cardView.layer.shadowOffset = CGSizeMake(0.0, 4.0);
                     cardView.layer.shadowRadius = 8.0;
                     cardView.layer.shadowOpacity = 0.14;
                   }
                   completion:nil];
}

- (void)presentContextMenuForRecipe:(MRRUserRecipeSnapshot *)recipe fromCardView:(UIView *)cardView {
  // Create context menu with recipe title
  MRRRecipeCardContextMenuViewController *contextMenu =
      [[[MRRRecipeCardContextMenuViewController alloc] initWithRecipeTitle:recipe.title] autorelease];

  __weak typeof(self) weakSelf = self;
  __weak MRRUserRecipeSnapshot *weakRecipe = recipe;

  // Add Edit action
  [contextMenu addActionWithTitle:@"Edit Recipe"
                        imageName:@"square.and.pencil"
                    isDestructive:NO
                          handler:^{
                            __strong typeof(weakSelf) strongSelf = weakSelf;
                            __strong MRRUserRecipeSnapshot *strongRecipe = weakRecipe;
                            if (strongSelf && strongRecipe) {
                              [strongSelf presentEditorForRecipe:strongRecipe];
                            }
                          }];

  // Add Share action (if iOS 13+)
  if (@available(iOS 13.0, *)) {
    [contextMenu addActionWithTitle:@"Share Recipe"
                          imageName:@"square.and.arrow.up"
                      isDestructive:NO
                            handler:^{
                              __strong typeof(weakSelf) strongSelf = weakSelf;
                              __strong MRRUserRecipeSnapshot *strongRecipe = weakRecipe;
                              if (strongSelf && strongRecipe) {
                                [strongSelf shareRecipe:strongRecipe];
                              }
                            }];
  }

  // Add Delete action
  [contextMenu addActionWithTitle:@"Delete Recipe"
                        imageName:@"trash"
                    isDestructive:YES
                          handler:^{
                            __strong typeof(weakSelf) strongSelf = weakSelf;
                            __strong MRRUserRecipeSnapshot *strongRecipe = weakRecipe;
                            if (strongSelf && strongRecipe) {
                              [strongSelf showDeleteConfirmationForRecipe:strongRecipe];
                            }
                          }];

  // Set cancel handler to animate card release
  contextMenu.cancelHandler = ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf) {
      [strongSelf animateCardPressRelease:cardView];
    }
  };

  // Present the menu
  [self presentViewController:contextMenu animated:YES completion:nil];
}

#pragma mark - UIContextMenuInteractionDelegate (iOS 13+)
// Provides native context menu support for modern iOS devices

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location API_AVAILABLE(ios(13.0)) {
#pragma unused(location)
  // Get the card view from the interaction
  UIView *cardView = interaction.view;
  NSString *cardID = cardView.accessibilityIdentifier ?: @"";
  NSString *recipeID = [cardID stringByReplacingOccurrencesOfString:MRRYoursRecipeCardIdentifierPrefix withString:@""];
  MRRUserRecipeSnapshot *recipe = [self recipeForIdentifier:recipeID];

  if (recipe == nil) {
    return nil;
  }

  // Store recipeID in configuration identifier for later retrieval
  __weak typeof(self) weakSelf = self;
  NSString *recipeIDCopy = [recipeID copy];

  UIContextMenuConfiguration *configuration = [UIContextMenuConfiguration
      configurationWithIdentifier:recipeIDCopy
                  previewProvider:nil
                   actionProvider:^UIMenu *_Nullable(NSArray<UIMenuElement *> *_Nonnull suggestedActions) {
#pragma unused(suggestedActions)
                     __strong typeof(weakSelf) strongSelf = weakSelf;
                     if (!strongSelf) {
                       return nil;
                     }

                     // Get recipe from stored ID
                     MRRUserRecipeSnapshot *menuRecipe = [strongSelf recipeForIdentifier:recipeIDCopy];
                     if (!menuRecipe) {
                       return nil;
                     }

                     // Build menu actions
                     NSMutableArray<UIAction *> *actions = [NSMutableArray array];

                     // Edit action
                     UIAction *editAction = [UIAction actionWithTitle:@"Edit Recipe"
                                                                image:[UIImage systemImageNamed:@"square.and.pencil"]
                                                           identifier:nil
                                                              handler:^(__kindof UIAction *_Nonnull action) {
#pragma unused(action)
                                                                __strong typeof(weakSelf) editStrongSelf = weakSelf;
                                                                if (editStrongSelf) {
                                                                  MRRUserRecipeSnapshot *editRecipe =
                                                                      [editStrongSelf recipeForIdentifier:recipeIDCopy];
                                                                  if (editRecipe) {
                                                                    [editStrongSelf presentEditorForRecipe:editRecipe];
                                                                  }
                                                                }
                                                              }];
                     [actions addObject:editAction];

                     // Share action
                     UIAction *shareAction = [UIAction actionWithTitle:@"Share Recipe"
                                                                 image:[UIImage systemImageNamed:@"square.and.arrow.up"]
                                                            identifier:nil
                                                               handler:^(__kindof UIAction *_Nonnull action) {
#pragma unused(action)
                                                                 __strong typeof(weakSelf) shareStrongSelf = weakSelf;
                                                                 if (shareStrongSelf) {
                                                                   MRRUserRecipeSnapshot *shareRecipe =
                                                                       [shareStrongSelf recipeForIdentifier:recipeIDCopy];
                                                                   if (shareRecipe) {
                                                                     [shareStrongSelf shareRecipe:shareRecipe];
                                                                   }
                                                                 }
                                                               }];
                     [actions addObject:shareAction];

                     // Delete action (destructive)
                     UIAction *deleteAction = [UIAction actionWithTitle:@"Delete Recipe"
                                                                  image:[UIImage systemImageNamed:@"trash"]
                                                             identifier:nil
                                                                handler:^(__kindof UIAction *_Nonnull action) {
#pragma unused(action)
                                                                  __strong typeof(weakSelf) deleteStrongSelf = weakSelf;
                                                                  if (deleteStrongSelf) {
                                                                    MRRUserRecipeSnapshot *deleteRecipe =
                                                                        [deleteStrongSelf recipeForIdentifier:recipeIDCopy];
                                                                    if (deleteRecipe) {
                                                                      [deleteStrongSelf showDeleteConfirmationForRecipe:deleteRecipe];
                                                                    }
                                                                  }
                                                                }];
                     deleteAction.attributes = UIMenuElementAttributesDestructive;
                     [actions addObject:deleteAction];

                     return [UIMenu menuWithTitle:@"" children:actions];
                   }];

  [recipeIDCopy release];
  return configuration;
}

- (UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
    previewForHighlightingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration API_AVAILABLE(ios(13.0)) {
#pragma unused(configuration)
  UIView *cardView = interaction.view;

  // Use the card view itself as the preview
  UITargetedPreview *preview = [[UITargetedPreview alloc] initWithView:cardView];
  return [preview autorelease];
}

- (void)shareRecipe:(MRRUserRecipeSnapshot *)recipe {
  // Create share items
  NSMutableArray *items = [NSMutableArray array];
  [items addObject:recipe.title];
  if (recipe.summaryText.length > 0) {
    [items addObject:recipe.summaryText];
  }

  UIActivityViewController *activityVC = [[[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil] autorelease];

  // For iPad support
  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    activityVC.popoverPresentationController.sourceView = self.view;
    activityVC.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1.0, 1.0);
    activityVC.popoverPresentationController.permittedArrowDirections = 0;
  }

  [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)showDeleteConfirmationForRecipe:(MRRUserRecipeSnapshot *)recipe {
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Delete Recipe?"
                                                                           message:@"This removes the recipe locally and queues a Firestore delete."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
  alertController.view.accessibilityIdentifier = @"yours.deleteAlert";
  [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [alertController addAction:[UIAlertAction actionWithTitle:@"Delete"
                                                      style:UIAlertActionStyleDestructive
                                                    handler:^(UIAlertAction *action) {
                                                      NSError *error = nil;
                                                      if (![self deleteRecipeWithIdentifier:recipe.recipeID error:&error] && error != nil) {
                                                        [self presentValidationError:error title:@"Couldn't delete recipe"];
                                                      }
                                                    }]];
  UIViewController *presenter = self.presentedViewController ?: self;
  [presenter presentViewController:alertController animated:YES completion:nil];
}

- (void)handleSelectButtonTapped:(UIButton *)sender {
  // Get recipeID from associated object
  NSString *recipeID = objc_getAssociatedObject(sender, @selector(recipeID));

  if (recipeID.length == 0) {
    return;
  }

  // Toggle selection
  BOOL isSelected = [self.selectedRecipeIDs containsObject:recipeID];
  if (isSelected) {
    [self.selectedRecipeIDs removeObject:recipeID];
    sender.selected = NO;
  } else {
    [self.selectedRecipeIDs addObject:recipeID];
    sender.selected = YES;
  }

  // Update accessibility
  BOOL nowSelected = !isSelected;
  MRRUserRecipeSnapshot *recipe = [self recipeForIdentifier:recipeID];
  if (nowSelected) {
    sender.accessibilityLabel = [NSString stringWithFormat:@"Deselect %@", recipe.title ?: @"recipe"];
    sender.accessibilityValue = @"Selected";
    sender.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSelected;
  } else {
    sender.accessibilityLabel = [NSString stringWithFormat:@"Select %@", recipe.title ?: @"recipe"];
    sender.accessibilityValue = nil;
    sender.accessibilityTraits = UIAccessibilityTraitButton;
  }

  // Announce selection change for VoiceOver
  NSString *announcement =
      nowSelected
          ? [NSString stringWithFormat:@"%@ selected. %lu items selected.", recipe.title ?: @"Recipe", (unsigned long)self.selectedRecipeIDs.count]
          : [NSString stringWithFormat:@"%@ deselected. %lu items selected.", recipe.title ?: @"Recipe", (unsigned long)self.selectedRecipeIDs.count];
  UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, announcement);

  // Update UI
  [self updateNavigationBarButtons];           // Update selection count on left
  [self updateToolbarVisibility];              // Show/hide toolbar
  [self updateCardSelectionVisuals:recipeID];  // Update card border
}

- (void)updateCardSelectionVisuals:(NSString *)recipeID {
  // Find the card view for this recipe
  for (UIView *cardView in self.cardsStackView.arrangedSubviews) {
    NSString *cardIdentifier = cardView.accessibilityIdentifier ?: @"";
    if ([cardIdentifier isEqualToString:[MRRYoursRecipeCardIdentifierPrefix stringByAppendingString:recipeID]]) {
      // Update card border to indicate selection
      BOOL isSelected = [self.selectedRecipeIDs containsObject:recipeID];
      if (isSelected && self.isSelectionMode) {
        cardView.layer.borderColor = MRRYoursAccentColor().CGColor;
        cardView.layer.borderWidth = 2.0;
      } else {
        cardView.layer.borderColor = MRRYoursBorderColor().CGColor;
        cardView.layer.borderWidth = 1.0;
      }

      for (UIView *subview in cardView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
          UIButton *button = (UIButton *)subview;
          if ([button.accessibilityIdentifier isEqualToString:[NSString stringWithFormat:@"yours.selectButton.%@", recipeID]]) {
            button.selected = isSelected;
            button.backgroundColor = (isSelected && self.isSelectionMode) ? MRRYoursAccentColor() : [UIColor clearColor];
            break;
          }
        }
      }
      break;
    }
  }
}

- (void)handleCardTappedForSelection:(UITapGestureRecognizer *)gesture {
  if (!self.isSelectionMode) {
    return;  // Only handle taps in selection mode
  }

  UIView *cardView = gesture.view;
  NSString *cardIdentifier = cardView.accessibilityIdentifier ?: @"";
  NSString *recipeID = [cardIdentifier stringByReplacingOccurrencesOfString:MRRYoursRecipeCardIdentifierPrefix withString:@""];

  if (recipeID.length == 0) {
    return;
  }

  // Find the select button and toggle it
  for (UIView *subview in cardView.subviews) {
    if ([subview isKindOfClass:[UIButton class]]) {
      UIButton *button = (UIButton *)subview;
      NSString *identifier = button.accessibilityIdentifier ?: @"";
      if ([identifier isEqualToString:[NSString stringWithFormat:@"yours.selectButton.%@", recipeID]]) {
        // Simulate button tap
        [self handleSelectButtonTapped:button];
        break;
      }
    }
  }
}

- (void)presentImagePopupWithImage:(UIImage *)image {
  MRRImagePopupViewController *popupViewController = [[[MRRImagePopupViewController alloc] initWithImage:image] autorelease];
  [self presentViewController:popupViewController animated:YES completion:nil];
}

- (void)handleThumbnailsToggleTapped:(UIButton *)sender {
  NSString *recipeID = [self recipeIdentifierFromButton:sender prefix:MRRYoursRecipeThumbnailsToggleIdentifierPrefix];
  if (recipeID.length == 0) {
    return;
  }

  BOOL isCurrentlyExpanded = [self.expandedRecipeIDs containsObject:recipeID];
  BOOL shouldExpand = !isCurrentlyExpanded;

  NSLog(@"%@ handleThumbnailsToggleTapped - recipeID: %@, %@", MRRYoursViewControllerLogPrefix, recipeID,
        shouldExpand ? @"expanding" : @"collapsing");

  // Update state
  if (shouldExpand) {
    [self.expandedRecipeIDs addObject:recipeID];
  } else {
    [self.expandedRecipeIDs removeObject:recipeID];
  }

  // Update chevron icon
  UIImage *chevronImage = nil;
  if (@available(iOS 13.0, *)) {
    chevronImage = [UIImage systemImageNamed:shouldExpand ? @"chevron.down" : @"chevron.right"];
  }
  [sender setImage:chevronImage forState:UIControlStateNormal];

  // Animate height constraint
  NSLayoutConstraint *heightConstraint = self.thumbnailsHeightConstraints[recipeID];
  if (heightConstraint != nil) {
    [UIView animateWithDuration:0.25
                     animations:^{
                       heightConstraint.constant = shouldExpand ? MRRYoursRecipeThumbnailSize : 0;
                       [sender.superview layoutIfNeeded];
                     }];
  }
}

- (void)userRecipesStoreDidChange:(NSNotification *)notification {
  NSLog(@"%@ Received MRRUserRecipesStoreDidChangeNotification - notification.object: %@", MRRYoursViewControllerLogPrefix,
        notification.object ?: @"nil");

  if (notification.object != self.userRecipesStore) {
    NSLog(@"%@ WARNING: Notification object mismatch - ignoring (expected: %@, got: %@)", MRRYoursViewControllerLogPrefix,
          self.userRecipesStore ?: @"nil", notification.object ?: @"nil");
    return;
  }
  NSLog(@"%@ Reloading content due to store change notification", MRRYoursViewControllerLogPrefix);
  [self loadRecipesFromStore];
  [self reloadContent];
}

@end
