#import "YoursViewController.h"

#import "../../Persistence/UserRecipes/MRRUserRecipePhotoStorage.h"
#import "../../Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../../Persistence/UserRecipes/Models/MRRUserRecipeSnapshot.h"
#import "../../Persistence/UserRecipes/Sync/MRRUserRecipesCloudSyncing.h"
#import "MRRImagePopupViewController.h"
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

static NSString *const MRRYoursRecipeCardIdentifierPrefix = @"yours.recipeCard.";
static NSString *const MRRYoursRecipeCoverImageIdentifierPrefix = @"yours.recipeCoverImage.";
static NSString *const MRRYoursRecipeEditButtonIdentifierPrefix = @"yours.editButton.";
static NSString *const MRRYoursRecipeDeleteButtonIdentifierPrefix = @"yours.deleteButton.";
static NSString *const MRRYoursRecipeThumbnailsIdentifierPrefix = @"yours.recipeThumbnails.";
static NSString *const MRRYoursRecipeThumbnailIdentifierPrefix = @"yours.recipeThumbnail.";
static CGFloat const MRRYoursRecipeThumbnailSize = 62.0;
static CGFloat const MRRYoursRecipeThumbnailSpacing = 10.0;

@interface YoursViewController ()

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
- (void)handleEditButtonTapped:(UIButton *)sender;
- (void)handleDeleteButtonTapped:(UIButton *)sender;
- (void)handleImageTapped:(UITapGestureRecognizer *)recognizer;
- (void)presentImagePopupWithImage:(UIImage *)image;
- (void)userRecipesStoreDidChange:(NSNotification *)notification;

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
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  NSLog(@"%@ viewDidLoad - sessionUserID: %@, userRecipesStore: %@", 
        MRRYoursViewControllerLogPrefix,
        self.sessionUserID ?: @"nil",
        self.userRecipesStore ? @"provided" : @"nil");

  self.title = @"Yours";
  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"yours.view";
  self.view.backgroundColor = MRRYoursCanvasColor();

  UIBarButtonItem *addButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                              target:self
                                                                              action:@selector(handleAddButtonTapped:)] autorelease];
  addButton.accessibilityIdentifier = @"yours.addButton";
  self.navigationItem.rightBarButtonItem = addButton;

  if (self.userRecipesStore != nil) {
    NSLog(@"%@ Registering for MRRUserRecipesStoreDidChangeNotification", MRRYoursViewControllerLogPrefix);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userRecipesStoreDidChange:)
                                                 name:MRRUserRecipesStoreDidChangeNotification
                                               object:self.userRecipesStore];
  }

  [self buildViewHierarchy];
  [self loadRecipesFromStore];
  [self reloadContent];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  NSLog(@"%@ viewWillAppear - loading recipes from store", MRRYoursViewControllerLogPrefix);
  [self.navigationController setNavigationBarHidden:NO animated:animated];
  [self loadRecipesFromStore];
  [self reloadContent];
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
  NSLog(@"%@ loadRecipesFromStore - userRecipesStore: %@, sessionUserID: '%@'", 
        MRRYoursViewControllerLogPrefix,
        self.userRecipesStore ? @"provided" : @"nil",
        self.sessionUserID ?: @"nil");
  
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
    NSLog(@"%@ SKIPPING load - userRecipesStore: %@, sessionUserID.length: %lu", 
          MRRYoursViewControllerLogPrefix,
          self.userRecipesStore ? @"provided" : @"nil",
          (unsigned long)self.sessionUserID.length);
  }
  self.recipes = recipes;
}

- (void)reloadContent {
  while (self.cardsStackView.arrangedSubviews.count > 0) {
    UIView *subview = self.cardsStackView.arrangedSubviews.firstObject;
    [self.cardsStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  if (self.recipes.count == 0) {
    [self.cardsStackView addArrangedSubview:[self emptyStateView]];
    return;
  }

  for (MRRUserRecipeSnapshot *recipe in self.recipes) {
    [self.cardsStackView addArrangedSubview:[self recipeCardViewForRecipe:recipe]];
  }
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
    UITapGestureRecognizer *coverTapGesture = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                      action:@selector(handleImageTapped:)] autorelease];
    [coverImageView addGestureRecognizer:coverTapGesture];
  }

  // Scrollable container for stacked photo thumbnails
  UIScrollView *thumbnailsScrollView = [[[UIScrollView alloc] init] autorelease];
  thumbnailsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
  thumbnailsScrollView.showsHorizontalScrollIndicator = NO;
  thumbnailsScrollView.alwaysBounceHorizontal = YES;
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

  [NSLayoutConstraint activateConstraints:@[
    [thumbnailsStackView.topAnchor constraintEqualToAnchor:thumbnailsScrollView.contentLayoutGuide.topAnchor],
    [thumbnailsStackView.leadingAnchor constraintEqualToAnchor:thumbnailsScrollView.contentLayoutGuide.leadingAnchor],
    [thumbnailsStackView.trailingAnchor constraintEqualToAnchor:thumbnailsScrollView.contentLayoutGuide.trailingAnchor],
    [thumbnailsStackView.bottomAnchor constraintEqualToAnchor:thumbnailsScrollView.contentLayoutGuide.bottomAnchor],
    [thumbnailsStackView.heightAnchor constraintEqualToAnchor:thumbnailsScrollView.frameLayoutGuide.heightAnchor],
    [thumbnailsStackView.widthAnchor constraintGreaterThanOrEqualToAnchor:thumbnailsScrollView.frameLayoutGuide.widthAnchor]
  ]];

  // Add additional photos (excluding cover) as a clean horizontal strip.
  NSArray<MRRUserRecipePhotoSnapshot *> *photos = recipe.photos;
  NSArray<MRRUserRecipePhotoSnapshot *> *additionalPhotos = photos.count > 1 ? [photos subarrayWithRange:NSMakeRange(1, photos.count - 1)] : @[];

  if (additionalPhotos.count > 0) {

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

    [thumbnailsScrollView.heightAnchor constraintEqualToConstant:MRRYoursRecipeThumbnailSize].active = YES;
  } else {
    [thumbnailsScrollView.heightAnchor constraintEqualToConstant:0].active = YES;
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

  UIStackView *actionsStackView = [[[UIStackView alloc] init] autorelease];
  actionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  actionsStackView.axis = UILayoutConstraintAxisHorizontal;
  actionsStackView.spacing = 12.0;
  actionsStackView.distribution = UIStackViewDistributionFillEqually;
  [containerView addSubview:actionsStackView];

  UIButton *editButton = [self actionButtonWithTitle:@"Edit" filled:NO];
  editButton.accessibilityIdentifier = [MRRYoursRecipeEditButtonIdentifierPrefix stringByAppendingString:recipe.recipeID];
  [editButton addTarget:self action:@selector(handleEditButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [actionsStackView addArrangedSubview:editButton];

  UIButton *deleteButton = [self actionButtonWithTitle:@"Delete" filled:NO];
  deleteButton.backgroundColor = [UIColor colorWithRed:0.79 green:0.21 blue:0.17 alpha:0.12];
  [deleteButton setTitleColor:[UIColor colorWithRed:0.79 green:0.21 blue:0.17 alpha:1.0] forState:UIControlStateNormal];
  deleteButton.accessibilityIdentifier = [MRRYoursRecipeDeleteButtonIdentifierPrefix stringByAppendingString:recipe.recipeID];
  [deleteButton addTarget:self action:@selector(handleDeleteButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [actionsStackView addArrangedSubview:deleteButton];

  [NSLayoutConstraint activateConstraints:@[
    [coverImageView.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:20.0],
    [coverImageView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:20.0],
    [coverImageView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-20.0],
    [coverImageView.heightAnchor constraintEqualToConstant:180.0],

    [thumbnailsScrollView.topAnchor constraintEqualToAnchor:coverImageView.bottomAnchor constant:12.0],
    [thumbnailsScrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:20.0],
    [thumbnailsScrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-20.0],

    [titleLabel.topAnchor constraintEqualToAnchor:thumbnailsScrollView.bottomAnchor constant:12.0],
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

    [actionsStackView.topAnchor constraintEqualToAnchor:updatedLabel.bottomAnchor constant:18.0],
    [actionsStackView.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
    [actionsStackView.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
    [actionsStackView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-20.0]
  ]];

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

- (void)presentEditorForRecipe:(MRRUserRecipeSnapshot *)recipe {
  MRRYoursRecipeEditorViewController *editorViewController = [[[MRRYoursRecipeEditorViewController alloc] initWithSessionUserID:self.sessionUserID
                                                                                                               userRecipesStore:self.userRecipesStore
                                                                                                                     syncEngine:self.syncEngine
                                                                                                                   photoStorage:self.photoStorage
                                                                                                                 existingRecipe:recipe] autorelease];
  [self.navigationController pushViewController:editorViewController animated:YES];
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
  [self presentEditorForRecipe:nil];
}

- (void)handleEditButtonTapped:(UIButton *)sender {
  MRRUserRecipeSnapshot *recipe = [self recipeForIdentifier:[self recipeIdentifierFromButton:sender prefix:MRRYoursRecipeEditButtonIdentifierPrefix]];
  if (recipe == nil) {
    return;
  }
  [self presentEditorForRecipe:recipe];
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

- (void)presentImagePopupWithImage:(UIImage *)image {
  MRRImagePopupViewController *popupViewController = [[[MRRImagePopupViewController alloc] initWithImage:image] autorelease];
  [self presentViewController:popupViewController animated:YES completion:nil];
}

- (void)userRecipesStoreDidChange:(NSNotification *)notification {
  if (notification.object != self.userRecipesStore) {
    return;
  }
  [self loadRecipesFromStore];
  [self reloadContent];
}

@end
