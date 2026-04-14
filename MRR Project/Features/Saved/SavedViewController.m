#import "SavedViewController.h"

#import "../../Persistence/SavedRecipes/MRRSavedRecipesStore.h"
#import "../../Persistence/SavedRecipes/Models/MRRSavedRecipeSnapshot.h"
#import "../../Persistence/SavedRecipes/Sync/MRRSavedRecipesCloudSyncing.h"
#import "../Onboarding/Presentation/ViewControllers/OnboardingRecipeDetailViewController.h"

static UIColor *MRRSavedDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return darkColor;
      }
      return lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRSavedNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRSavedDynamicFallbackColor(lightColor, darkColor);
}

static UIColor *MRRSavedCanvasColor(void) {
  return MRRSavedNamedColor(@"BackgroundColor", [UIColor colorWithRed:0.98 green:0.97 blue:0.95 alpha:1.0],
                            [UIColor colorWithRed:0.10 green:0.11 blue:0.12 alpha:1.0]);
}

static UIColor *MRRSavedSurfaceColor(void) {
  return MRRSavedNamedColor(@"HomeSurfaceColor", [UIColor colorWithWhite:1.0 alpha:1.0], [UIColor colorWithWhite:0.14 alpha:1.0]);
}

static UIColor *MRRSavedMutedSurfaceColor(void) {
  return MRRSavedNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.95 alpha:1.0], [UIColor colorWithWhite:0.18 alpha:1.0]);
}

static UIColor *MRRSavedBorderColor(void) {
  return MRRSavedNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0], [UIColor colorWithWhite:0.24 alpha:1.0]);
}

static UIColor *MRRSavedPrimaryTextColor(void) {
  return MRRSavedNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRSavedSecondaryTextColor(void) {
  return MRRSavedNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.45 alpha:1.0], [UIColor colorWithWhite:0.70 alpha:1.0]);
}

static UIColor *MRRSavedHeartBubbleColor(void) {
  return MRRSavedNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                            [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static CGFloat const MRRSavedItemPressedAlpha = 0.92;

static NSString *const MRRSavedTableViewCellIdentifier = @"SavedRecipeListItem";
static NSString *const MRRSavedFavoriteButtonIdentifierPrefix = @"saved.favoriteButton.";

static UIImage *MRRSavedSymbolImage(NSString *systemName, CGFloat pointSize, CGFloat weight) {
  if (@available(iOS 13.0, *)) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:(UIImageSymbolWeight)weight];
    return [UIImage systemImageNamed:systemName withConfiguration:configuration];
  }

  return nil;
}

@interface MRRSavedRecipeListItemCell : UITableViewCell

@property(nonatomic, retain, readonly) UIView *itemContainerView;
@property(nonatomic, retain, readonly) UIImageView *thumbnailImageView;
@property(nonatomic, retain, readonly) UILabel *titleLabel;
@property(nonatomic, retain, readonly) UILabel *subtitleLabel;
@property(nonatomic, retain, readonly) UIButton *favoriteButton;

- (void)configureWithRecipe:(MRRSavedRecipeSnapshot *)recipe;
- (void)applyPressedAppearance:(BOOL)pressed;

@end

@implementation MRRSavedRecipeListItemCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if (self) {
    [self buildItemViewHierarchy];
  }

  return self;
}

- (void)dealloc {
  [_itemContainerView release];
  [_thumbnailImageView release];
  [_titleLabel release];
  [_subtitleLabel release];
  [_favoriteButton release];
  [super dealloc];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat availableWidth = CGRectGetWidth(self.titleLabel.bounds);
  if (availableWidth > 0.0) {
    self.titleLabel.preferredMaxLayoutWidth = availableWidth;
  }
}

- (void)buildItemViewHierarchy {
  self.backgroundColor = [UIColor clearColor];
  self.contentView.backgroundColor = [UIColor clearColor];
  self.selectionStyle = UITableViewCellSelectionStyleNone;

  UIView *itemContainerView = [[[UIView alloc] init] autorelease];
  itemContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  itemContainerView.backgroundColor = MRRSavedSurfaceColor();
  itemContainerView.layer.cornerRadius = 20.0;
  itemContainerView.layer.masksToBounds = YES;
  itemContainerView.accessibilityIdentifier = @"saved.listItem.container";
  [self.contentView addSubview:itemContainerView];
  _itemContainerView = [itemContainerView retain];

  UIView *thumbnailFrame = [[[UIView alloc] init] autorelease];
  thumbnailFrame.translatesAutoresizingMaskIntoConstraints = NO;
  thumbnailFrame.backgroundColor = MRRSavedMutedSurfaceColor();
  thumbnailFrame.layer.cornerRadius = 16.0;
  thumbnailFrame.layer.masksToBounds = YES;
  thumbnailFrame.accessibilityIdentifier = @"saved.listItem.thumbnailFrame";
  [itemContainerView addSubview:thumbnailFrame];

  UIImageView *thumbnailImageView = [[[UIImageView alloc] init] autorelease];
  thumbnailImageView.translatesAutoresizingMaskIntoConstraints = NO;
  thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
  thumbnailImageView.clipsToBounds = YES;
  thumbnailImageView.layer.cornerRadius = 16.0;
  thumbnailImageView.isAccessibilityElement = NO;
  thumbnailImageView.accessibilityIdentifier = @"saved.listItem.thumbnail";
  [thumbnailFrame addSubview:thumbnailImageView];
  _thumbnailImageView = [thumbnailImageView retain];

  UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
  titleLabel.textColor = MRRSavedPrimaryTextColor();
  titleLabel.numberOfLines = 0;
  titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
  titleLabel.adjustsFontForContentSizeCategory = YES;
  [titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  titleLabel.isAccessibilityElement = NO;
  titleLabel.accessibilityIdentifier = @"saved.listItem.title";
  [itemContainerView addSubview:titleLabel];
  _titleLabel = [titleLabel retain];

  UILabel *subtitleLabel = [[[UILabel alloc] init] autorelease];
  subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  subtitleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
  subtitleLabel.textColor = MRRSavedSecondaryTextColor();
  subtitleLabel.numberOfLines = 1;
  subtitleLabel.adjustsFontForContentSizeCategory = YES;
  [subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [subtitleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  subtitleLabel.isAccessibilityElement = NO;
  subtitleLabel.accessibilityIdentifier = @"saved.listItem.subtitle";
  [itemContainerView addSubview:subtitleLabel];
  _subtitleLabel = [subtitleLabel retain];

  UIButton *favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
  favoriteButton.translatesAutoresizingMaskIntoConstraints = NO;
  favoriteButton.accessibilityIdentifier = @"saved.listItem.removeButton";
  favoriteButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
  favoriteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
  [favoriteButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [favoriteButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [favoriteButton setImage:MRRSavedSymbolImage(@"xmark.circle.fill", 24.0, UIFontWeightMedium) forState:UIControlStateNormal];
  favoriteButton.tintColor = MRRSavedSecondaryTextColor();
  [itemContainerView addSubview:favoriteButton];
  _favoriteButton = [favoriteButton retain];

  [NSLayoutConstraint activateConstraints:@[
    [itemContainerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
    [itemContainerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20.0],
    [itemContainerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20.0],
    [itemContainerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],

    [thumbnailFrame.leadingAnchor constraintEqualToAnchor:itemContainerView.leadingAnchor constant:14.0],
    [thumbnailFrame.centerYAnchor constraintEqualToAnchor:itemContainerView.centerYAnchor],
    [thumbnailFrame.widthAnchor constraintEqualToConstant:68.0],
    [thumbnailFrame.heightAnchor constraintEqualToConstant:68.0],

    [thumbnailImageView.topAnchor constraintEqualToAnchor:thumbnailFrame.topAnchor],
    [thumbnailImageView.leadingAnchor constraintEqualToAnchor:thumbnailFrame.leadingAnchor],
    [thumbnailImageView.trailingAnchor constraintEqualToAnchor:thumbnailFrame.trailingAnchor],
    [thumbnailImageView.bottomAnchor constraintEqualToAnchor:thumbnailFrame.bottomAnchor],

    [favoriteButton.trailingAnchor constraintEqualToAnchor:itemContainerView.trailingAnchor constant:-14.0],
    [favoriteButton.centerYAnchor constraintEqualToAnchor:itemContainerView.centerYAnchor],
    [favoriteButton.widthAnchor constraintEqualToConstant:44.0],
    [favoriteButton.heightAnchor constraintEqualToConstant:44.0],

    [titleLabel.topAnchor constraintEqualToAnchor:itemContainerView.topAnchor constant:18.0],
    [titleLabel.leadingAnchor constraintEqualToAnchor:thumbnailFrame.trailingAnchor constant:14.0],
    [titleLabel.trailingAnchor constraintEqualToAnchor:favoriteButton.leadingAnchor constant:-10.0],

    [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4.0],
    [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
    [subtitleLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
    [subtitleLabel.bottomAnchor constraintEqualToAnchor:itemContainerView.bottomAnchor constant:-18.0]
  ]];
}

- (void)configureWithRecipe:(MRRSavedRecipeSnapshot *)recipe {
  self.titleLabel.text = recipe.title;

  NSString *subtitle = [NSString stringWithFormat:@"%@  •  %@", recipe.durationText, recipe.calorieText];
  self.subtitleLabel.text = subtitle;

  self.thumbnailImageView.image = [UIImage imageNamed:recipe.assetName];
  if (self.thumbnailImageView.image == nil) {
    self.thumbnailImageView.backgroundColor = MRRSavedMutedSurfaceColor();
  }

  self.accessibilityIdentifier = [NSString stringWithFormat:@"saved.recipeCard.%@", recipe.recipeID];
  self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", recipe.title, subtitle];
  self.accessibilityHint = @"Double tap to view recipe details.";
  self.accessibilityTraits = UIAccessibilityTraitButton;

  self.favoriteButton.selected = YES;
  self.favoriteButton.accessibilityLabel = [NSString stringWithFormat:@"Remove %@ from saved recipes", recipe.title ?: @"recipe"];
  self.favoriteButton.accessibilityHint = @"Double tap to remove this recipe from Saved.";
  self.favoriteButton.accessibilityValue = @"Saved";
  self.favoriteButton.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitSelected;
}

- (void)applyPressedAppearance:(BOOL)pressed {
  CGFloat alpha = pressed ? MRRSavedItemPressedAlpha : 1.0;
  if (UIAccessibilityIsReduceMotionEnabled()) {
    self.itemContainerView.alpha = alpha;
    return;
  }
  [UIView animateWithDuration:0.14
                        delay:0.0
                      options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                   animations:^{
                     self.itemContainerView.alpha = alpha;
                   }
                   completion:nil];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
  [super setHighlighted:highlighted animated:animated];
  [self applyPressedAppearance:highlighted];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
  [super setSelected:selected animated:animated];
  [self applyPressedAppearance:selected];
}

@end

@interface SavedViewController () <UITableViewDataSource, UITableViewDelegate, OnboardingRecipeDetailViewControllerDelegate>

@property(nonatomic, copy, nullable) NSString *sessionUserID;
@property(nonatomic, copy, nullable) NSString *presentedRecipeIdentifier;
@property(nonatomic, retain, nullable) MRRSavedRecipesStore *savedRecipesStore;
@property(nonatomic, retain, nullable) id<MRRSavedRecipesCloudSyncing> syncEngine;
@property(nonatomic, retain) UITableView *tableView;
@property(nonatomic, retain) UIView *emptyStateView;
@property(nonatomic, copy) NSArray<MRRSavedRecipeSnapshot *> *allRecipes;

- (void)buildViewHierarchy;
- (void)loadRecipesFromStore;
- (void)reloadTableView;
- (nullable MRRSavedRecipeSnapshot *)recipeAtIndexPath:(NSIndexPath *)indexPath;
- (void)presentRecipeDetailForSnapshot:(MRRSavedRecipeSnapshot *)snapshot;
- (void)presentRecipeDetailViewController:(OnboardingRecipeDetailViewController *)detailViewController;
- (BOOL)removeRecipeWithIdentifier:(NSString *)recipeIdentifier dismissIfPresented:(BOOL)dismissIfPresented;
- (void)presentPersistenceError:(NSError *)error title:(NSString *)title;
- (void)handleRemoveButtonTapped:(UIButton *)sender;
- (void)savedRecipesStoreDidChange:(NSNotification *)notification;

@end

@implementation SavedViewController

- (instancetype)init {
  return [self initWithSessionUserID:nil savedRecipesStore:nil syncEngine:nil];
}

- (instancetype)initWithSessionUserID:(NSString *)sessionUserID
                    savedRecipesStore:(MRRSavedRecipesStore *)savedRecipesStore
                           syncEngine:(id<MRRSavedRecipesCloudSyncing>)syncEngine {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    self.title = @"Saved";
    _sessionUserID = [sessionUserID copy];
    _savedRecipesStore = [savedRecipesStore retain];
    _syncEngine = [syncEngine retain];
    _allRecipes = [[NSArray alloc] init];
  }

  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_presentedRecipeIdentifier release];
  [_allRecipes release];
  [_tableView release];
  [_emptyStateView release];
  [_syncEngine release];
  [_savedRecipesStore release];
  [_sessionUserID release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }
  self.view.accessibilityIdentifier = @"saved.view";
  self.view.backgroundColor = MRRSavedCanvasColor();

  if (self.savedRecipesStore != nil) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(savedRecipesStoreDidChange:)
                                                 name:MRRSavedRecipesStoreDidChangeNotification
                                               object:self.savedRecipesStore];
  }

  [self buildViewHierarchy];
  [self loadRecipesFromStore];
  [self reloadTableView];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:NO animated:animated];
  [self loadRecipesFromStore];
  [self reloadTableView];
}

- (void)buildViewHierarchy {
  UITableView *tableView = [[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain] autorelease];
  tableView.translatesAutoresizingMaskIntoConstraints = NO;
  tableView.backgroundColor = [UIColor clearColor];
  tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  tableView.showsVerticalScrollIndicator = YES;
  tableView.alwaysBounceVertical = YES;
  tableView.delaysContentTouches = NO;
  tableView.dataSource = self;
  tableView.delegate = self;
  tableView.rowHeight = UITableViewAutomaticDimension;
  tableView.estimatedRowHeight = 96.0;
  tableView.accessibilityIdentifier = @"saved.tableView";
  [tableView registerClass:[MRRSavedRecipeListItemCell class] forCellReuseIdentifier:MRRSavedTableViewCellIdentifier];
  [self.view addSubview:tableView];
  self.tableView = tableView;

  UIView *emptyStateView = [self buildEmptyStateView];
  emptyStateView.translatesAutoresizingMaskIntoConstraints = NO;
  emptyStateView.hidden = YES;
  emptyStateView.accessibilityIdentifier = @"saved.emptyState";
  [self.view addSubview:emptyStateView];
  self.emptyStateView = emptyStateView;

  UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [tableView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
    [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [emptyStateView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-20.0],
    [emptyStateView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [emptyStateView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
  ]];
}

- (void)loadRecipesFromStore {
  NSMutableArray<MRRSavedRecipeSnapshot *> *recipes = [NSMutableArray array];

  if (self.savedRecipesStore != nil && self.sessionUserID.length > 0) {
    NSError *fetchError = nil;
    NSArray<MRRSavedRecipeSnapshot *> *fetchedSnapshots = [self.savedRecipesStore savedRecipesForUserID:self.sessionUserID error:&fetchError];
    if (fetchError == nil && fetchedSnapshots != nil) {
      [recipes addObjectsFromArray:fetchedSnapshots];
    }
  }

  self.allRecipes = recipes;
}

- (void)reloadTableView {
  BOOL isEmpty = (self.allRecipes.count == 0);
  self.tableView.hidden = isEmpty;
  self.emptyStateView.hidden = !isEmpty;

  [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.allRecipes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  MRRSavedRecipeListItemCell *cell = [tableView dequeueReusableCellWithIdentifier:MRRSavedTableViewCellIdentifier forIndexPath:indexPath];

  MRRSavedRecipeSnapshot *recipe = [self recipeAtIndexPath:indexPath];
  [cell configureWithRecipe:recipe];

  [cell.favoriteButton removeTarget:nil action:0 forControlEvents:UIControlEventAllEvents];
  [cell.favoriteButton addTarget:self action:@selector(handleRemoveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  cell.favoriteButton.accessibilityIdentifier = [NSString stringWithFormat:@"%@%@", MRRSavedFavoriteButtonIdentifierPrefix, recipe.recipeID];

  return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  MRRSavedRecipeSnapshot *snapshot = [self recipeAtIndexPath:indexPath];
  if (snapshot == nil) {
    return;
  }

  [self presentRecipeDetailForSnapshot:snapshot];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
  return YES;
}

#pragma mark - Helpers

- (nullable MRRSavedRecipeSnapshot *)recipeAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.allRecipes.count) {
    return nil;
  }

  return self.allRecipes[indexPath.row];
}

- (UIView *)buildEmptyStateView {
  UIView *container = [[[UIView alloc] init] autorelease];
  container.translatesAutoresizingMaskIntoConstraints = NO;
  container.backgroundColor = [UIColor clearColor];

  UIView *cardView = [[[UIView alloc] init] autorelease];
  cardView.translatesAutoresizingMaskIntoConstraints = NO;
  cardView.backgroundColor = MRRSavedSurfaceColor();
  cardView.layer.cornerRadius = 24.0;
  cardView.layer.borderWidth = 1.0;
  cardView.layer.borderColor = [MRRSavedBorderColor() CGColor];
  cardView.accessibilityIdentifier = @"saved.emptyState.card";
  [container addSubview:cardView];

  UIImageView *iconImageView = [[[UIImageView alloc] init] autorelease];
  iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
  iconImageView.contentMode = UIViewContentModeScaleAspectFit;
  iconImageView.tintColor = MRRSavedHeartBubbleColor();
  iconImageView.image = MRRSavedSymbolImage(@"bookmark", 36.0, UIFontWeightMedium);
  iconImageView.accessibilityIdentifier = @"saved.emptyState.icon";
  [cardView addSubview:iconImageView];

  UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
  titleLabel.textColor = MRRSavedPrimaryTextColor();
  titleLabel.numberOfLines = 0;
  titleLabel.textAlignment = NSTextAlignmentCenter;
  titleLabel.text = @"No saved recipes yet.";
  titleLabel.accessibilityIdentifier = @"saved.emptyState.title";
  [cardView addSubview:titleLabel];

  UILabel *subtitleLabel = [[[UILabel alloc] init] autorelease];
  subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  subtitleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
  subtitleLabel.textColor = MRRSavedSecondaryTextColor();
  subtitleLabel.numberOfLines = 0;
  subtitleLabel.textAlignment = NSTextAlignmentCenter;
  subtitleLabel.text = @"Recipes you save will appear here.";
  subtitleLabel.accessibilityIdentifier = @"saved.emptyState.subtitle";
  [cardView addSubview:subtitleLabel];

  [NSLayoutConstraint activateConstraints:@[
    [cardView.topAnchor constraintEqualToAnchor:container.topAnchor constant:16.0],
    [cardView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:24.0],
    [cardView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-24.0],
    [cardView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-16.0],

    [iconImageView.topAnchor constraintEqualToAnchor:cardView.topAnchor constant:32.0],
    [iconImageView.centerXAnchor constraintEqualToAnchor:cardView.centerXAnchor],
    [iconImageView.widthAnchor constraintEqualToConstant:44.0],
    [iconImageView.heightAnchor constraintEqualToConstant:44.0],

    [titleLabel.topAnchor constraintEqualToAnchor:iconImageView.bottomAnchor constant:16.0],
    [titleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
    [titleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],

    [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8.0],
    [subtitleLabel.leadingAnchor constraintEqualToAnchor:cardView.leadingAnchor constant:24.0],
    [subtitleLabel.trailingAnchor constraintEqualToAnchor:cardView.trailingAnchor constant:-24.0],
    [subtitleLabel.bottomAnchor constraintEqualToAnchor:cardView.bottomAnchor constant:-32.0]
  ]];

  return container;
}

- (void)presentRecipeDetailForSnapshot:(MRRSavedRecipeSnapshot *)snapshot {
  if (snapshot == nil || self.presentedViewController != nil) {
    return;
  }

  OnboardingRecipeDetailViewController *detailViewController =
      [[[OnboardingRecipeDetailViewController alloc] initWithRecipePreview:[snapshot recipePreviewRepresentation]
                                                            recipeDetail:[snapshot recipeDetailRepresentation]] autorelease];
  detailViewController.delegate = self;
  detailViewController.showsFavoriteButton = self.sessionUserID.length > 0;
  detailViewController.favoriteSelected = YES;
  detailViewController.favoriteButtonEnabled = YES;
  self.presentedRecipeIdentifier = snapshot.recipeID;
  [self presentRecipeDetailViewController:detailViewController];
}

- (void)presentRecipeDetailViewController:(OnboardingRecipeDetailViewController *)detailViewController {
  if (detailViewController == nil) {
    return;
  }

  UINavigationController *navigationController = [[[UINavigationController alloc] initWithRootViewController:detailViewController] autorelease];
  navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
  navigationController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
  [self presentViewController:navigationController animated:YES completion:nil];
}

- (BOOL)removeRecipeWithIdentifier:(NSString *)recipeIdentifier dismissIfPresented:(BOOL)dismissIfPresented {
  if (recipeIdentifier.length == 0 || self.savedRecipesStore == nil || self.sessionUserID.length == 0) {
    return NO;
  }

  NSError *removeError = nil;
  BOOL didRemove = [self.savedRecipesStore removeRecipeForUserID:self.sessionUserID recipeID:recipeIdentifier error:&removeError];
  if (!didRemove || removeError != nil) {
    [self presentPersistenceError:removeError title:@"Couldn't remove recipe"];
    return NO;
  }

  [self.syncEngine requestImmediateSyncForUserID:self.sessionUserID];
  [self loadRecipesFromStore];
  [self reloadTableView];

  if (dismissIfPresented && [self.presentedRecipeIdentifier isEqualToString:recipeIdentifier] && self.presentedViewController != nil) {
    self.presentedRecipeIdentifier = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
  }

  return YES;
}

- (void)presentPersistenceError:(NSError *)error title:(NSString *)title {
  NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : @"Please try again in a moment.";
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
  UIViewController *presenter = self.presentedViewController ?: self;
  [presenter presentViewController:alertController animated:YES completion:nil];
}

- (void)handleRemoveButtonTapped:(UIButton *)sender {
  NSString *identifier = sender.accessibilityIdentifier;
  if (![identifier hasPrefix:MRRSavedFavoriteButtonIdentifierPrefix]) {
    return;
  }

  NSString *recipeIdentifier = [identifier substringFromIndex:MRRSavedFavoriteButtonIdentifierPrefix.length];
  [self removeRecipeWithIdentifier:recipeIdentifier dismissIfPresented:NO];
}

- (void)savedRecipesStoreDidChange:(NSNotification *)notification {
  if (notification.object != nil && notification.object != self.savedRecipesStore) {
    return;
  }

  [self loadRecipesFromStore];
  [self reloadTableView];

  if (self.presentedRecipeIdentifier.length > 0) {
    BOOL stillExists = NO;
    for (MRRSavedRecipeSnapshot *recipe in self.allRecipes) {
      if ([recipe.recipeID isEqualToString:self.presentedRecipeIdentifier]) {
        stillExists = YES;
        break;
      }
    }

    if (!stillExists && self.presentedViewController != nil) {
      self.presentedRecipeIdentifier = nil;
      [self dismissViewControllerAnimated:YES completion:nil];
    }
  }
}

#pragma mark - OnboardingRecipeDetailViewControllerDelegate

- (void)recipeDetailViewControllerDidClose:(OnboardingRecipeDetailViewController *)viewController {
  self.presentedRecipeIdentifier = nil;
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)recipeDetailViewControllerDidStartCooking:(OnboardingRecipeDetailViewController *)viewController {
  self.presentedRecipeIdentifier = nil;
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)recipeDetailViewController:(OnboardingRecipeDetailViewController *)viewController didRequestFavoriteState:(BOOL)favorite {
  if (favorite) {
    viewController.favoriteSelected = YES;
    return;
  }

  NSString *recipeIdentifier = self.presentedRecipeIdentifier;
  if ([self removeRecipeWithIdentifier:recipeIdentifier dismissIfPresented:YES]) {
    viewController.favoriteSelected = NO;
  }
}

@end
