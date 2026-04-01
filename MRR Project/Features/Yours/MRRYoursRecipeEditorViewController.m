#import "MRRYoursRecipeEditorViewController.h"

#import "../../Layout/MRRLiquidGlassStyling.h"
#import "../../Persistence/UserRecipes/MRRUserRecipePhotoStorage.h"
#import "../../Persistence/UserRecipes/MRRUserRecipesStore.h"
#import "../../Persistence/UserRecipes/Models/MRRUserRecipeSnapshot.h"
#import "../../Persistence/UserRecipes/Sync/MRRUserRecipesCloudSyncing.h"

static NSErrorDomain const MRRYoursRecipeEditorValidationErrorDomain = @"MRRYoursRecipeEditorValidationErrorDomain";
static NSInteger const MRRYoursRecipeEditorMaximumPhotoCount = 5;
static CGFloat const MRRYoursRecipeEditorKeyboardGap = 18.0;
static CGFloat const MRRYoursRecipeEditorSectionContentTopInset = 58.0;

static UIColor *MRRYoursEditorDynamicFallbackColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
  }
  return lightColor;
}

static UIColor *MRRYoursEditorNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRYoursEditorDynamicFallbackColor(lightColor, darkColor);
}

static UIColor *MRRYoursEditorCanvasColor(void) {
  return MRRYoursEditorNamedColor(@"BackgroundColor", [UIColor colorWithRed:0.98 green:0.97 blue:0.95 alpha:1.0],
                                  [UIColor colorWithRed:0.10 green:0.11 blue:0.12 alpha:1.0]);
}

static UIColor *MRRYoursEditorMutedSurfaceColor(void) {
  return MRRYoursEditorNamedColor(@"HomeMutedSurfaceColor", [UIColor colorWithWhite:0.95 alpha:1.0], [UIColor colorWithWhite:0.18 alpha:1.0]);
}

static UIColor *MRRYoursEditorBorderColor(void) {
  return MRRYoursEditorNamedColor(@"HomeBorderColor", [UIColor colorWithWhite:0.90 alpha:1.0], [UIColor colorWithWhite:0.24 alpha:1.0]);
}

static UIColor *MRRYoursEditorPrimaryTextColor(void) {
  return MRRYoursEditorNamedColor(@"TextPrimaryColor", [UIColor colorWithWhite:0.10 alpha:1.0], [UIColor colorWithWhite:0.96 alpha:1.0]);
}

static UIColor *MRRYoursEditorSecondaryTextColor(void) {
  return MRRYoursEditorNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.45 alpha:1.0], [UIColor colorWithWhite:0.70 alpha:1.0]);
}

static UIColor *MRRYoursEditorAccentColor(void) {
  return MRRYoursEditorNamedColor(@"AccentColor", [UIColor colorWithRed:0.89 green:0.46 blue:0.24 alpha:1.0],
                                  [UIColor colorWithRed:0.96 green:0.70 blue:0.47 alpha:1.0]);
}

static UIColor *MRRYoursEditorSuccessColor(void) {
  return [UIColor colorWithRed:0.31 green:0.77 blue:0.43 alpha:1.0];
}

static UIColor *MRRYoursEditorInfoBlueColor(void) {
  return [UIColor colorWithRed:0.26 green:0.50 blue:0.95 alpha:1.0];
}

static UIColor *MRRYoursEditorErrorColor(void) {
  return [UIColor colorWithRed:0.79 green:0.21 blue:0.17 alpha:1.0];
}

static NSString *MRRYoursEditorTrimmedString(NSString *string) {
  return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSArray<NSString *> *MRRYoursEditorMealTypes(void) {
  return @[ MRRUserRecipeMealTypeBreakfast, MRRUserRecipeMealTypeLunch, MRRUserRecipeMealTypeDinner, MRRUserRecipeMealTypeDessert,
            MRRUserRecipeMealTypeSnack ];
}

static NSArray<NSString *> *MRRYoursEditorSuggestionTags(void) {
  return @[ @"Salad", @"Main Course", @"Drink" ];
}

@interface MRRYoursRecipePhotoDraft : NSObject

@property(nonatomic, copy) NSString *photoID;
@property(nonatomic, copy, nullable) NSString *remoteURLString;
@property(nonatomic, copy, nullable) NSString *localRelativePath;
@property(nonatomic, retain, nullable) UIImage *previewImage;

- (instancetype)initWithPhotoID:(NSString *)photoID
                remoteURLString:(nullable NSString *)remoteURLString
              localRelativePath:(nullable NSString *)localRelativePath
                   previewImage:(nullable UIImage *)previewImage;

@end

@implementation MRRYoursRecipePhotoDraft

- (instancetype)initWithPhotoID:(NSString *)photoID
                remoteURLString:(NSString *)remoteURLString
              localRelativePath:(NSString *)localRelativePath
                   previewImage:(UIImage *)previewImage {
  self = [super init];
  if (self) {
    _photoID = [photoID copy];
    _remoteURLString = [remoteURLString copy];
    _localRelativePath = [localRelativePath copy];
    _previewImage = [previewImage retain];
  }
  return self;
}

- (void)dealloc {
  [_previewImage release];
  [_localRelativePath release];
  [_remoteURLString release];
  [_photoID release];
  [super dealloc];
}

@end

@interface MRRYoursRecipeEditorViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, UITextViewDelegate>

@property(nonatomic, copy, nullable) NSString *sessionUserID;
@property(nonatomic, retain, nullable) MRRUserRecipesStore *userRecipesStore;
@property(nonatomic, retain, nullable) id<MRRUserRecipesCloudSyncing> syncEngine;
@property(nonatomic, retain, nullable) UIColor *previousNavigationBarTintColor;
@property(nonatomic, retain) id<MRRUserRecipePhotoStorage> photoStorage;
@property(nonatomic, retain, nullable) MRRUserRecipeSnapshot *existingRecipe;
@property(nonatomic, copy) NSString *draftRecipeID;
@property(nonatomic, assign) BOOL creatingRecipe;
@property(nonatomic, assign) BOOL didPersistRecipe;
@property(nonatomic, assign) NSInteger selectedPhotoIndex;
@property(nonatomic, assign) NSUInteger coverImageRequestToken;

@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIView *contentView;
@property(nonatomic, retain) UIStackView *contentStackView;
@property(nonatomic, retain) UIButton *bottomSaveButton;
@property(nonatomic, retain) UIStackView *photoActionsStackView;
@property(nonatomic, retain) UIBarButtonItem *saveBarButtonItem;

@property(nonatomic, retain) UIView *photoSectionView;
@property(nonatomic, retain) UIImageView *coverImageView;
@property(nonatomic, retain) UILabel *photoHelperLabel;
@property(nonatomic, retain) UIStackView *photoThumbnailsStackView;
@property(nonatomic, retain) UIButton *addPhotoButton;
@property(nonatomic, retain) UIButton *setCoverButton;
@property(nonatomic, retain) UIButton *removePhotoButton;

@property(nonatomic, retain) UIView *basicInfoSectionView;
@property(nonatomic, retain) UITextField *titleField;
@property(nonatomic, retain) UITextField *subtitleField;
@property(nonatomic, retain) UITextView *summaryTextView;
@property(nonatomic, retain) UILabel *basicInfoErrorLabel;

@property(nonatomic, retain) UIStackView *mealTypeButtonsStackView;
@property(nonatomic, retain) NSMutableDictionary<NSString *, UIButton *> *mealTypeButtonsByIdentifier;
@property(nonatomic, copy) NSString *selectedMealType;

@property(nonatomic, retain) UIStackView *tagButtonsStackView;
@property(nonatomic, retain) NSMutableDictionary<NSString *, UIButton *> *tagButtonsByValue;
@property(nonatomic, retain) NSOrderedSet<NSString *> *preservedTagValues;
@property(nonatomic, retain) NSArray<MRRUserRecipeStringSnapshot *> *preservedTools;

@property(nonatomic, retain) UITextField *cookTimeField;
@property(nonatomic, retain) UITextField *servingsField;
@property(nonatomic, retain) UITextField *caloriesField;

@property(nonatomic, retain) UIView *ingredientsSectionView;
@property(nonatomic, retain) UIStackView *ingredientsRowsStackView;
@property(nonatomic, retain) UILabel *ingredientsErrorLabel;

@property(nonatomic, retain) UIView *stepsSectionView;
@property(nonatomic, retain) UIStackView *stepsRowsStackView;
@property(nonatomic, retain) UILabel *stepsErrorLabel;

@property(nonatomic, retain) NSMutableArray<MRRYoursRecipePhotoDraft *> *photoDrafts;
@property(nonatomic, retain) NSMutableSet<NSString *> *removedLocalRelativePaths;
@property(nonatomic, retain) NSMutableSet<NSString *> *createdLocalRelativePaths;

- (void)buildViewHierarchy;
- (UIView *)sectionCardViewWithTitle:(NSString *)title accentColor:(UIColor *)accentColor accessibilityIdentifier:(NSString *)accessibilityIdentifier;
- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color;
- (UITextField *)styledTextFieldWithPlaceholder:(NSString *)placeholder keyboardType:(UIKeyboardType)keyboardType identifier:(NSString *)identifier;
- (UITextView *)styledTextViewWithIdentifier:(NSString *)identifier;
- (UIButton *)chipButtonWithTitle:(NSString *)title tintColor:(UIColor *)tintColor;
- (void)reloadPhotoUI;
- (void)reloadMealTypeSelection;
- (void)reloadTagSelection;
- (void)reloadIngredientRowsWithValues:(NSArray<NSString *> *)values;
- (void)reloadStepRowsWithValues:(NSArray<NSString *> *)values;
- (NSArray<NSString *> *)currentTextsFromRowsStackView:(UIStackView *)stackView;
- (nullable UIImage *)displayImageForPhotoDraft:(MRRYoursRecipePhotoDraft *)photoDraft;
- (void)reloadCoverImage;
- (void)handleSaveTapped:(id)sender;
- (BOOL)persistDraftWithError:(NSError *_Nullable *_Nullable)error;
- (NSArray<MRRUserRecipePhotoSnapshot *> *)resolvedPhotoSnapshotsWithError:(NSError *_Nullable *_Nullable)error;
- (NSArray<MRRUserRecipeIngredientSnapshot *> *)ingredientSnapshotsFromCurrentRows;
- (NSArray<MRRUserRecipeInstructionSnapshot *> *)instructionSnapshotsFromCurrentRows;
- (NSArray<MRRUserRecipeStringSnapshot *> *)tagSnapshotsForCurrentSelection;
- (NSInteger)resolvedIntegerValueFromText:(NSString *)text fallback:(NSInteger)fallback minimumValue:(NSInteger)minimumValue;
- (void)presentValidationError:(NSError *)error;
- (void)clearValidationErrors;
- (void)showValidationMessage:(NSString *)message onLabel:(UILabel *)label scrollTarget:(UIView *)scrollTarget;
- (void)presentPhotoPickerFromSourceView:(UIView *)sourceView;
- (BOOL)appendPhotoWithImage:(UIImage *)image error:(NSError *_Nullable *_Nullable)error;
- (void)handleAddPhotoTapped:(id)sender;
- (void)handleSetCoverTapped:(id)sender;
- (void)handleRemovePhotoTapped:(id)sender;
- (void)handleMealTypeButtonTapped:(UIButton *)sender;
- (void)handleTagButtonTapped:(UIButton *)sender;
- (void)handleIngredientAddTapped:(id)sender;
- (void)handleStepAddTapped:(id)sender;
- (void)handleRemoveIngredientTapped:(UIButton *)sender;
- (void)handleRemoveStepTapped:(UIButton *)sender;
- (void)handleThumbnailTapped:(UIButton *)sender;
- (void)applySelectedState:(BOOL)selected toChipButton:(UIButton *)button tintColor:(UIColor *)tintColor;
- (void)cleanupUnsavedLocalPhotosIfNeeded;

@end

@implementation MRRYoursRecipeEditorViewController

- (instancetype)initWithSessionUserID:(NSString *)sessionUserID
                     userRecipesStore:(MRRUserRecipesStore *)userRecipesStore
                           syncEngine:(id<MRRUserRecipesCloudSyncing>)syncEngine
                         photoStorage:(id<MRRUserRecipePhotoStorage>)photoStorage
                        existingRecipe:(MRRUserRecipeSnapshot *)existingRecipe {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _sessionUserID = [sessionUserID copy];
    _userRecipesStore = [userRecipesStore retain];
    _syncEngine = [syncEngine retain];
    _photoStorage = [(photoStorage ?: [[[MRRLocalUserRecipePhotoStorage alloc] init] autorelease]) retain];
    _existingRecipe = [existingRecipe retain];
    _creatingRecipe = existingRecipe == nil;
    _draftRecipeID = [(existingRecipe.recipeID.length > 0 ? existingRecipe.recipeID : [NSUUID UUID].UUIDString) copy];
    _selectedMealType = [(existingRecipe.mealType.length > 0 ? existingRecipe.mealType : MRRUserRecipeMealTypeSnack) copy];
    _mealTypeButtonsByIdentifier = [[NSMutableDictionary alloc] init];
    _tagButtonsByValue = [[NSMutableDictionary alloc] init];
    _photoDrafts = [[NSMutableArray alloc] init];
    _removedLocalRelativePaths = [[NSMutableSet alloc] init];
    _createdLocalRelativePaths = [[NSMutableSet alloc] init];

    NSMutableOrderedSet<NSString *> *preservedTagValues = [NSMutableOrderedSet orderedSet];
    NSSet<NSString *> *suggestionTagSet = [NSSet setWithArray:MRRYoursEditorSuggestionTags()];
    for (MRRUserRecipeStringSnapshot *tagSnapshot in existingRecipe.tags ?: @[]) {
      if (![suggestionTagSet containsObject:tagSnapshot.value]) {
        [preservedTagValues addObject:tagSnapshot.value];
      }
    }
    _preservedTagValues = [[preservedTagValues copy] retain];
    _preservedTools = [[existingRecipe.tools ?: @[] copy] retain];

    for (MRRUserRecipePhotoSnapshot *photoSnapshot in existingRecipe.photos ?: @[]) {
      UIImage *previewImage = nil;
      if (photoSnapshot.localRelativePath.length > 0) {
        NSURL *fileURL = [self.photoStorage fileURLForRelativePath:photoSnapshot.localRelativePath];
        if (fileURL.path.length > 0) {
          previewImage = [UIImage imageWithContentsOfFile:fileURL.path];
        }
      }
      MRRYoursRecipePhotoDraft *draft =
          [[[MRRYoursRecipePhotoDraft alloc] initWithPhotoID:photoSnapshot.photoID
                                              remoteURLString:photoSnapshot.remoteURLString
                                            localRelativePath:photoSnapshot.localRelativePath
                                                 previewImage:previewImage] autorelease];
      [self.photoDrafts addObject:draft];
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self cleanupUnsavedLocalPhotosIfNeeded];
  [_createdLocalRelativePaths release];
  [_removedLocalRelativePaths release];
  [_photoDrafts release];
  [_stepsErrorLabel release];
  [_stepsRowsStackView release];
  [_stepsSectionView release];
  [_ingredientsErrorLabel release];
  [_ingredientsRowsStackView release];
  [_ingredientsSectionView release];
  [_caloriesField release];
  [_servingsField release];
  [_cookTimeField release];
  [_preservedTools release];
  [_preservedTagValues release];
  [_tagButtonsByValue release];
  [_tagButtonsStackView release];
  [_selectedMealType release];
  [_mealTypeButtonsByIdentifier release];
  [_mealTypeButtonsStackView release];
  [_basicInfoErrorLabel release];
  [_summaryTextView release];
  [_subtitleField release];
  [_titleField release];
  [_basicInfoSectionView release];
  [_removePhotoButton release];
  [_setCoverButton release];
  [_addPhotoButton release];
  [_photoThumbnailsStackView release];
  [_photoHelperLabel release];
  [_photoActionsStackView release];
  [_coverImageView release];
  [_previousNavigationBarTintColor release];
  [_photoSectionView release];
  [_saveBarButtonItem release];
  [_bottomSaveButton release];
  [_contentStackView release];
  [_contentView release];
  [_scrollView release];
  [_draftRecipeID release];
  [_existingRecipe release];
  [_photoStorage release];
  [_syncEngine release];
  [_userRecipesStore release];
  [_sessionUserID release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = MRRYoursEditorCanvasColor();
  self.view.tintColor = MRRYoursEditorAccentColor();
  self.title = self.creatingRecipe ? @"New Recipe" : @"Edit Recipe";
  if (@available(iOS 11.0, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  }

  UIBarButtonItem *saveBarButtonItem =
      [[[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(handleSaveTapped:)] autorelease];
  saveBarButtonItem.tintColor = MRRYoursEditorAccentColor();
  self.navigationItem.rightBarButtonItem = saveBarButtonItem;
  self.saveBarButtonItem = saveBarButtonItem;

  [self buildViewHierarchy];

  self.titleField.text = self.existingRecipe.title ?: @"";
  self.subtitleField.text = self.existingRecipe.subtitle ?: @"";
  self.summaryTextView.text = self.existingRecipe.summaryText.length > 0 ? self.existingRecipe.summaryText : @"";
  self.summaryTextView.textColor =
      (MRRYoursEditorTrimmedString(self.summaryTextView.text ?: @"").length > 0) ? MRRYoursEditorPrimaryTextColor() : MRRYoursEditorSecondaryTextColor();
  self.cookTimeField.text = self.existingRecipe != nil ? [NSString stringWithFormat:@"%ld", (long)self.existingRecipe.readyInMinutes] : @"30";
  self.servingsField.text = self.existingRecipe != nil ? [NSString stringWithFormat:@"%ld", (long)self.existingRecipe.servings] : @"2";
  self.caloriesField.text = self.existingRecipe != nil && self.existingRecipe.calorieCount > 0
                                ? [NSString stringWithFormat:@"%ld", (long)self.existingRecipe.calorieCount]
                                : @"";
  if (MRRYoursEditorTrimmedString(self.summaryTextView.text ?: @"").length == 0) {
    self.summaryTextView.text = @"Describe your recipe briefly...";
  }

  NSMutableSet<NSString *> *selectedSuggestionTags = [NSMutableSet set];
  for (MRRUserRecipeStringSnapshot *tagSnapshot in self.existingRecipe.tags ?: @[]) {
    if ([MRRYoursEditorSuggestionTags() containsObject:tagSnapshot.value]) {
      [selectedSuggestionTags addObject:tagSnapshot.value];
    }
  }
  for (NSString *tagValue in selectedSuggestionTags) {
    UIButton *button = [self.tagButtonsByValue objectForKey:tagValue];
    button.selected = YES;
  }

  [self reloadMealTypeSelection];
  [self reloadTagSelection];
  [self reloadPhotoUI];
  [self reloadIngredientRowsWithValues:[self.existingRecipe.ingredients valueForKey:@"displayText"] ?: @[]];
  [self reloadStepRowsWithValues:[self.existingRecipe.instructions valueForKey:@"detailText"] ?: @[]];

  self.bottomSaveButton.accessibilityIdentifier = @"yours.editor.saveButton";
  self.view.accessibilityIdentifier = @"yours.editor.view";

  self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
}

- (void)viewWillAppear:(BOOL)animated {
  if (self.navigationController) {
    self.previousNavigationBarTintColor = self.navigationController.navigationBar.tintColor;
    self.navigationController.navigationBar.tintColor = MRRYoursEditorAccentColor();
  }
  [super viewWillAppear:animated];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleKeyboardWillChangeFrame:)
                                               name:UIKeyboardWillChangeFrameNotification
                                             object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
  if (self.navigationController) {
    self.navigationController.navigationBar.tintColor = self.previousNavigationBarTintColor;
  }
  [super viewWillDisappear:animated];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)buildViewHierarchy {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.alwaysBounceVertical = YES;
  scrollView.showsVerticalScrollIndicator = NO;
  [self.view addSubview:scrollView];
  self.scrollView = scrollView;

  UIButton *bottomSaveButton = [UIButton buttonWithType:UIButtonTypeSystem];
  bottomSaveButton.translatesAutoresizingMaskIntoConstraints = NO;
  [bottomSaveButton setTitle:(self.creatingRecipe ? @"Save Recipe" : @"Save Changes") forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRolePrimary toButton:bottomSaveButton];
  [bottomSaveButton addTarget:self action:@selector(handleSaveTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:bottomSaveButton];
  self.bottomSaveButton = bottomSaveButton;

  UIView *contentView = [[[UIView alloc] init] autorelease];
  contentView.translatesAutoresizingMaskIntoConstraints = NO;
  [scrollView addSubview:contentView];
  self.contentView = contentView;

  UIStackView *contentStackView = [[[UIStackView alloc] init] autorelease];
  contentStackView.translatesAutoresizingMaskIntoConstraints = NO;
  contentStackView.axis = UILayoutConstraintAxisVertical;
  contentStackView.spacing = 18.0;
  [contentView addSubview:contentStackView];
  self.contentStackView = contentStackView;

  UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [bottomSaveButton.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:24.0],
    [bottomSaveButton.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-24.0],
    [bottomSaveButton.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-12.0],
    [bottomSaveButton.heightAnchor constraintEqualToConstant:56.0],

    [scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
    [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [scrollView.bottomAnchor constraintEqualToAnchor:bottomSaveButton.topAnchor constant:-12.0],

    [contentView.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
    [contentView.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
    [contentView.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
    [contentView.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
    [contentView.widthAnchor constraintEqualToAnchor:scrollView.widthAnchor],

    [contentStackView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20.0],
    [contentStackView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20.0],
    [contentStackView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20.0],
    [contentStackView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24.0]
  ]];

  UIView *photoSectionView = [self sectionCardViewWithTitle:@"Photos"
                                                accentColor:MRRYoursEditorAccentColor()
                                     accessibilityIdentifier:@"yours.editor.photoSection"];
  self.photoSectionView = photoSectionView;
  [self.contentStackView addArrangedSubview:photoSectionView];

  UILabel *photoHeroLabel = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium] color:MRRYoursEditorSecondaryTextColor()];
  photoHeroLabel.text = @"Add up to 5 photos. The first photo becomes your cover.";
  photoHeroLabel.numberOfLines = 0;
  [photoSectionView addSubview:photoHeroLabel];
  self.photoHelperLabel = photoHeroLabel;

  UIImageView *coverImageView = [[[UIImageView alloc] init] autorelease];
  coverImageView.translatesAutoresizingMaskIntoConstraints = NO;
  coverImageView.contentMode = UIViewContentModeScaleAspectFill;
  coverImageView.clipsToBounds = YES;
  coverImageView.layer.cornerRadius = 24.0;
  coverImageView.layer.borderWidth = 1.0;
  coverImageView.layer.borderColor = [MRRYoursEditorBorderColor() colorWithAlphaComponent:0.55].CGColor;
  coverImageView.backgroundColor = [MRRYoursEditorMutedSurfaceColor() colorWithAlphaComponent:0.85];
  coverImageView.accessibilityIdentifier = @"yours.editor.coverImage";
  [photoSectionView addSubview:coverImageView];
  self.coverImageView = coverImageView;

  UIStackView *photoThumbnailsStackView = [[[UIStackView alloc] init] autorelease];
  photoThumbnailsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  photoThumbnailsStackView.axis = UILayoutConstraintAxisHorizontal;
  photoThumbnailsStackView.spacing = 8.0;
  photoThumbnailsStackView.alignment = UIStackViewAlignmentLeading;
  photoThumbnailsStackView.distribution = UIStackViewDistributionFill;
  photoThumbnailsStackView.accessibilityIdentifier = @"yours.editor.photoThumbnails";
  [photoSectionView addSubview:photoThumbnailsStackView];
  self.photoThumbnailsStackView = photoThumbnailsStackView;

  UIButton *addPhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
  addPhotoButton.translatesAutoresizingMaskIntoConstraints = NO;
  [addPhotoButton setTitle:@"Add Photo" forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRolePrimary toButton:addPhotoButton];
  [addPhotoButton addTarget:self action:@selector(handleAddPhotoTapped:) forControlEvents:UIControlEventTouchUpInside];
  addPhotoButton.accessibilityIdentifier = @"yours.editor.addPhotoButton";
  self.addPhotoButton = addPhotoButton;

  UIButton *setCoverButton = [UIButton buttonWithType:UIButtonTypeSystem];
  setCoverButton.translatesAutoresizingMaskIntoConstraints = NO;
  [setCoverButton setTitle:@"Set as Cover" forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRoleSecondary toButton:setCoverButton];
  [setCoverButton addTarget:self action:@selector(handleSetCoverTapped:) forControlEvents:UIControlEventTouchUpInside];
  setCoverButton.accessibilityIdentifier = @"yours.editor.setCoverButton";
  self.setCoverButton = setCoverButton;

  UIButton *removePhotoButton = [UIButton buttonWithType:UIButtonTypeSystem];
  removePhotoButton.translatesAutoresizingMaskIntoConstraints = NO;
  [removePhotoButton setTitle:@"Remove Photo" forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRoleSecondary toButton:removePhotoButton];
  [removePhotoButton addTarget:self action:@selector(handleRemovePhotoTapped:) forControlEvents:UIControlEventTouchUpInside];
  removePhotoButton.accessibilityIdentifier = @"yours.editor.removePhotoButton";
  self.removePhotoButton = removePhotoButton;

  [NSLayoutConstraint activateConstraints:@[
    [photoHeroLabel.topAnchor constraintEqualToAnchor:photoSectionView.topAnchor constant:MRRYoursRecipeEditorSectionContentTopInset],
  UIStackView *photoActionsStackView = [[[UIStackView alloc] init] autorelease];
  photoActionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  photoActionsStackView.axis = UILayoutConstraintAxisVertical;
  photoActionsStackView.spacing = 10.0;
  photoActionsStackView.accessibilityIdentifier = @"yours.editor.photoActionsStack";
  [photoActionsStackView addArrangedSubview:addPhotoButton];
  [photoActionsStackView addArrangedSubview:setCoverButton];
  [photoActionsStackView addArrangedSubview:removePhotoButton];
  [photoSectionView addSubview:photoActionsStackView];
  self.photoActionsStackView = photoActionsStackView;

    [photoHeroLabel.leadingAnchor constraintEqualToAnchor:photoSectionView.leadingAnchor constant:22.0],
    [photoHeroLabel.trailingAnchor constraintEqualToAnchor:photoSectionView.trailingAnchor constant:-22.0],

    [coverImageView.topAnchor constraintEqualToAnchor:photoHeroLabel.bottomAnchor constant:14.0],
    [coverImageView.leadingAnchor constraintEqualToAnchor:photoHeroLabel.leadingAnchor],
    [coverImageView.trailingAnchor constraintEqualToAnchor:photoHeroLabel.trailingAnchor],
    [coverImageView.heightAnchor constraintEqualToConstant:208.0],

    [photoThumbnailsStackView.topAnchor constraintEqualToAnchor:coverImageView.bottomAnchor constant:14.0],
    [photoThumbnailsStackView.leadingAnchor constraintEqualToAnchor:photoHeroLabel.leadingAnchor],
    [photoThumbnailsStackView.trailingAnchor constraintLessThanOrEqualToAnchor:photoHeroLabel.trailingAnchor],

    [photoActionsStackView.topAnchor constraintEqualToAnchor:photoThumbnailsStackView.bottomAnchor constant:16.0],
    [photoActionsStackView.leadingAnchor constraintEqualToAnchor:photoHeroLabel.leadingAnchor],
    [photoActionsStackView.trailingAnchor constraintEqualToAnchor:photoHeroLabel.trailingAnchor],
    [photoActionsStackView.bottomAnchor constraintEqualToAnchor:photoSectionView.bottomAnchor constant:-22.0]
  ]];

  UIView *basicInfoSectionView = [self sectionCardViewWithTitle:@"Basic Info" accentColor:MRRYoursEditorAccentColor() accessibilityIdentifier:@"yours.editor.basicInfoSection"];
  self.basicInfoSectionView = basicInfoSectionView;
  [self.contentStackView addArrangedSubview:basicInfoSectionView];

  UITextField *titleField = [self styledTextFieldWithPlaceholder:@"Recipe name" keyboardType:UIKeyboardTypeDefault identifier:@"yours.editor.titleField"];
  self.titleField = titleField;
  [basicInfoSectionView addSubview:titleField];

  UITextField *subtitleField = [self styledTextFieldWithPlaceholder:@"Short subtitle" keyboardType:UIKeyboardTypeDefault identifier:@"yours.editor.subtitleField"];
  self.subtitleField = subtitleField;
  [basicInfoSectionView addSubview:subtitleField];

  UITextView *summaryTextView = [self styledTextViewWithIdentifier:@"yours.editor.summaryTextView"];
  summaryTextView.text = @"Describe your recipe briefly...";
  summaryTextView.textColor = MRRYoursEditorSecondaryTextColor();
  self.summaryTextView = summaryTextView;
  [basicInfoSectionView addSubview:summaryTextView];

  UILabel *basicInfoErrorLabel = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium] color:MRRYoursEditorErrorColor()];
  basicInfoErrorLabel.numberOfLines = 0;
  basicInfoErrorLabel.hidden = YES;
  basicInfoErrorLabel.accessibilityIdentifier = @"yours.editor.errorLabel";
  [basicInfoSectionView addSubview:basicInfoErrorLabel];
  self.basicInfoErrorLabel = basicInfoErrorLabel;

  [NSLayoutConstraint activateConstraints:@[
    [titleField.topAnchor constraintEqualToAnchor:basicInfoSectionView.topAnchor constant:MRRYoursRecipeEditorSectionContentTopInset],
    [titleField.leadingAnchor constraintEqualToAnchor:basicInfoSectionView.leadingAnchor constant:22.0],
    [titleField.trailingAnchor constraintEqualToAnchor:basicInfoSectionView.trailingAnchor constant:-22.0],
    [titleField.heightAnchor constraintEqualToConstant:52.0],

    [subtitleField.topAnchor constraintEqualToAnchor:titleField.bottomAnchor constant:12.0],
    [subtitleField.leadingAnchor constraintEqualToAnchor:titleField.leadingAnchor],
    [subtitleField.trailingAnchor constraintEqualToAnchor:titleField.trailingAnchor],
    [subtitleField.heightAnchor constraintEqualToConstant:52.0],

    [summaryTextView.topAnchor constraintEqualToAnchor:subtitleField.bottomAnchor constant:12.0],
    [summaryTextView.leadingAnchor constraintEqualToAnchor:titleField.leadingAnchor],
    [summaryTextView.trailingAnchor constraintEqualToAnchor:titleField.trailingAnchor],
    [summaryTextView.heightAnchor constraintEqualToConstant:132.0],

    [basicInfoErrorLabel.topAnchor constraintEqualToAnchor:summaryTextView.bottomAnchor constant:10.0],
    [basicInfoErrorLabel.leadingAnchor constraintEqualToAnchor:titleField.leadingAnchor],
    [basicInfoErrorLabel.trailingAnchor constraintEqualToAnchor:titleField.trailingAnchor],
    [basicInfoErrorLabel.bottomAnchor constraintEqualToAnchor:basicInfoSectionView.bottomAnchor constant:-22.0]
  ]];

  UIView *categorySectionView = [self sectionCardViewWithTitle:@"Category" accentColor:MRRYoursEditorInfoBlueColor() accessibilityIdentifier:@"yours.editor.categorySection"];
  [self.contentStackView addArrangedSubview:categorySectionView];

  UIStackView *mealTypeButtonsStackView = [[[UIStackView alloc] init] autorelease];
  mealTypeButtonsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  mealTypeButtonsStackView.axis = UILayoutConstraintAxisVertical;
  mealTypeButtonsStackView.spacing = 10.0;
  [categorySectionView addSubview:mealTypeButtonsStackView];
  self.mealTypeButtonsStackView = mealTypeButtonsStackView;

  NSArray<NSArray<NSString *> *> *mealRows = @[ @[ MRRUserRecipeMealTypeBreakfast, MRRUserRecipeMealTypeLunch, MRRUserRecipeMealTypeDinner ],
                                               @[ MRRUserRecipeMealTypeDessert, MRRUserRecipeMealTypeSnack ] ];
  for (NSArray<NSString *> *mealRow in mealRows) {
    UIStackView *rowStack = [[[UIStackView alloc] init] autorelease];
    rowStack.axis = UILayoutConstraintAxisHorizontal;
    rowStack.spacing = 10.0;
    rowStack.distribution = UIStackViewDistributionFillEqually;
    [mealTypeButtonsStackView addArrangedSubview:rowStack];
    for (NSString *mealType in mealRow) {
      UIButton *button = [self chipButtonWithTitle:mealType.capitalizedString tintColor:MRRYoursEditorInfoBlueColor()];
      button.accessibilityIdentifier = [@"yours.editor.mealType." stringByAppendingString:mealType];
      [button addTarget:self action:@selector(handleMealTypeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
      [rowStack addArrangedSubview:button];
      [self.mealTypeButtonsByIdentifier setObject:button forKey:mealType];
    }
  }

  UIStackView *tagButtonsStackView = [[[UIStackView alloc] init] autorelease];
  tagButtonsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  tagButtonsStackView.axis = UILayoutConstraintAxisHorizontal;
  tagButtonsStackView.spacing = 10.0;
  tagButtonsStackView.distribution = UIStackViewDistributionFillEqually;
  [categorySectionView addSubview:tagButtonsStackView];
  self.tagButtonsStackView = tagButtonsStackView;

  for (NSString *tagValue in MRRYoursEditorSuggestionTags()) {
    UIButton *button = [self chipButtonWithTitle:tagValue tintColor:MRRYoursEditorSuccessColor()];
    button.accessibilityIdentifier = [@"yours.editor.tag." stringByAppendingString:tagValue];
    [button addTarget:self action:@selector(handleTagButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [tagButtonsStackView addArrangedSubview:button];
    [self.tagButtonsByValue setObject:button forKey:tagValue];
  }

  UILabel *tagsHintLabel = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium] color:MRRYoursEditorSecondaryTextColor()];
  tagsHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
  tagsHintLabel.numberOfLines = 0;
  tagsHintLabel.text = @"Extra chips are stored as tags while the main category stays aligned with the rest of the app.";
  [categorySectionView addSubview:tagsHintLabel];

  [NSLayoutConstraint activateConstraints:@[
    [mealTypeButtonsStackView.topAnchor constraintEqualToAnchor:categorySectionView.topAnchor constant:MRRYoursRecipeEditorSectionContentTopInset],
    [mealTypeButtonsStackView.leadingAnchor constraintEqualToAnchor:categorySectionView.leadingAnchor constant:22.0],
    [mealTypeButtonsStackView.trailingAnchor constraintEqualToAnchor:categorySectionView.trailingAnchor constant:-22.0],

    [tagButtonsStackView.topAnchor constraintEqualToAnchor:mealTypeButtonsStackView.bottomAnchor constant:18.0],
    [tagButtonsStackView.leadingAnchor constraintEqualToAnchor:mealTypeButtonsStackView.leadingAnchor],
    [tagButtonsStackView.trailingAnchor constraintEqualToAnchor:mealTypeButtonsStackView.trailingAnchor],

    [tagsHintLabel.topAnchor constraintEqualToAnchor:tagButtonsStackView.bottomAnchor constant:10.0],
    [tagsHintLabel.leadingAnchor constraintEqualToAnchor:mealTypeButtonsStackView.leadingAnchor],
    [tagsHintLabel.trailingAnchor constraintEqualToAnchor:mealTypeButtonsStackView.trailingAnchor],
    [tagsHintLabel.bottomAnchor constraintEqualToAnchor:categorySectionView.bottomAnchor constant:-22.0]
  ]];

  UIView *detailsSectionView = [self sectionCardViewWithTitle:@"Details & Nutrition" accentColor:MRRYoursEditorSuccessColor() accessibilityIdentifier:@"yours.editor.detailsSection"];
  [self.contentStackView addArrangedSubview:detailsSectionView];

  UITextField *cookTimeField = [self styledTextFieldWithPlaceholder:@"Cook time (min)" keyboardType:UIKeyboardTypeNumberPad identifier:@"yours.editor.readyField"];
  UITextField *servingsField = [self styledTextFieldWithPlaceholder:@"Servings" keyboardType:UIKeyboardTypeNumberPad identifier:@"yours.editor.servingsField"];
  UITextField *caloriesField = [self styledTextFieldWithPlaceholder:@"Calories" keyboardType:UIKeyboardTypeNumberPad identifier:@"yours.editor.caloriesField"];
  self.cookTimeField = cookTimeField;
  self.servingsField = servingsField;
  self.caloriesField = caloriesField;
  [detailsSectionView addSubview:cookTimeField];
  [detailsSectionView addSubview:servingsField];
  [detailsSectionView addSubview:caloriesField];

  [NSLayoutConstraint activateConstraints:@[
    [cookTimeField.topAnchor constraintEqualToAnchor:detailsSectionView.topAnchor constant:MRRYoursRecipeEditorSectionContentTopInset],
    [cookTimeField.leadingAnchor constraintEqualToAnchor:detailsSectionView.leadingAnchor constant:22.0],
    [cookTimeField.trailingAnchor constraintEqualToAnchor:detailsSectionView.trailingAnchor constant:-22.0],
    [cookTimeField.heightAnchor constraintEqualToConstant:52.0],

    [servingsField.topAnchor constraintEqualToAnchor:cookTimeField.bottomAnchor constant:12.0],
    [servingsField.leadingAnchor constraintEqualToAnchor:cookTimeField.leadingAnchor],
    [servingsField.trailingAnchor constraintEqualToAnchor:cookTimeField.trailingAnchor],
    [servingsField.heightAnchor constraintEqualToConstant:52.0],

    [caloriesField.topAnchor constraintEqualToAnchor:servingsField.bottomAnchor constant:12.0],
    [caloriesField.leadingAnchor constraintEqualToAnchor:cookTimeField.leadingAnchor],
    [caloriesField.trailingAnchor constraintEqualToAnchor:cookTimeField.trailingAnchor],
    [caloriesField.heightAnchor constraintEqualToConstant:52.0],
    [caloriesField.bottomAnchor constraintEqualToAnchor:detailsSectionView.bottomAnchor constant:-22.0]
  ]];

  UIView *ingredientsSectionView = [self sectionCardViewWithTitle:@"Ingredients" accentColor:MRRYoursEditorSuccessColor() accessibilityIdentifier:@"yours.editor.ingredientsSection"];
  self.ingredientsSectionView = ingredientsSectionView;
  [self.contentStackView addArrangedSubview:ingredientsSectionView];

  UIStackView *ingredientsRowsStackView = [[[UIStackView alloc] init] autorelease];
  ingredientsRowsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  ingredientsRowsStackView.axis = UILayoutConstraintAxisVertical;
  ingredientsRowsStackView.spacing = 12.0;
  [ingredientsSectionView addSubview:ingredientsRowsStackView];
  self.ingredientsRowsStackView = ingredientsRowsStackView;

  UIButton *addIngredientButton = [UIButton buttonWithType:UIButtonTypeSystem];
  addIngredientButton.translatesAutoresizingMaskIntoConstraints = NO;
  [addIngredientButton setTitle:@"Add Ingredient" forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRoleInline toButton:addIngredientButton];
  [addIngredientButton addTarget:self action:@selector(handleIngredientAddTapped:) forControlEvents:UIControlEventTouchUpInside];
  [ingredientsSectionView addSubview:addIngredientButton];

  UILabel *ingredientsErrorLabel = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium] color:MRRYoursEditorErrorColor()];
  ingredientsErrorLabel.numberOfLines = 0;
  ingredientsErrorLabel.hidden = YES;
  [ingredientsSectionView addSubview:ingredientsErrorLabel];
  self.ingredientsErrorLabel = ingredientsErrorLabel;

  [NSLayoutConstraint activateConstraints:@[
    [ingredientsRowsStackView.topAnchor constraintEqualToAnchor:ingredientsSectionView.topAnchor constant:MRRYoursRecipeEditorSectionContentTopInset],
    [ingredientsRowsStackView.leadingAnchor constraintEqualToAnchor:ingredientsSectionView.leadingAnchor constant:22.0],
    [ingredientsRowsStackView.trailingAnchor constraintEqualToAnchor:ingredientsSectionView.trailingAnchor constant:-22.0],

    [addIngredientButton.topAnchor constraintEqualToAnchor:ingredientsRowsStackView.bottomAnchor constant:14.0],
    [addIngredientButton.leadingAnchor constraintEqualToAnchor:ingredientsRowsStackView.leadingAnchor],

    [ingredientsErrorLabel.topAnchor constraintEqualToAnchor:addIngredientButton.bottomAnchor constant:10.0],
    [ingredientsErrorLabel.leadingAnchor constraintEqualToAnchor:ingredientsRowsStackView.leadingAnchor],
    [ingredientsErrorLabel.trailingAnchor constraintEqualToAnchor:ingredientsRowsStackView.trailingAnchor],
    [ingredientsErrorLabel.bottomAnchor constraintEqualToAnchor:ingredientsSectionView.bottomAnchor constant:-22.0]
  ]];

  UIView *stepsSectionView = [self sectionCardViewWithTitle:@"Cooking Steps" accentColor:MRRYoursEditorInfoBlueColor() accessibilityIdentifier:@"yours.editor.stepsSection"];
  self.stepsSectionView = stepsSectionView;
  [self.contentStackView addArrangedSubview:stepsSectionView];

  UIStackView *stepsRowsStackView = [[[UIStackView alloc] init] autorelease];
  stepsRowsStackView.translatesAutoresizingMaskIntoConstraints = NO;
  stepsRowsStackView.axis = UILayoutConstraintAxisVertical;
  stepsRowsStackView.spacing = 12.0;
  [stepsSectionView addSubview:stepsRowsStackView];
  self.stepsRowsStackView = stepsRowsStackView;

  UIButton *addStepButton = [UIButton buttonWithType:UIButtonTypeSystem];
  addStepButton.translatesAutoresizingMaskIntoConstraints = NO;
  [addStepButton setTitle:@"Add Step" forState:UIControlStateNormal];
  [MRRLiquidGlassStyling applyButtonRole:MRRGlassButtonRoleInline toButton:addStepButton];
  [addStepButton addTarget:self action:@selector(handleStepAddTapped:) forControlEvents:UIControlEventTouchUpInside];
  [stepsSectionView addSubview:addStepButton];

  UILabel *stepsErrorLabel = [self labelWithFont:[UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium] color:MRRYoursEditorErrorColor()];
  stepsErrorLabel.numberOfLines = 0;
  stepsErrorLabel.hidden = YES;
  [stepsSectionView addSubview:stepsErrorLabel];
  self.stepsErrorLabel = stepsErrorLabel;

  [NSLayoutConstraint activateConstraints:@[
    [stepsRowsStackView.topAnchor constraintEqualToAnchor:stepsSectionView.topAnchor constant:MRRYoursRecipeEditorSectionContentTopInset],
    [stepsRowsStackView.leadingAnchor constraintEqualToAnchor:stepsSectionView.leadingAnchor constant:22.0],
    [stepsRowsStackView.trailingAnchor constraintEqualToAnchor:stepsSectionView.trailingAnchor constant:-22.0],

    [addStepButton.topAnchor constraintEqualToAnchor:stepsRowsStackView.bottomAnchor constant:14.0],
    [addStepButton.leadingAnchor constraintEqualToAnchor:stepsRowsStackView.leadingAnchor],

    [stepsErrorLabel.topAnchor constraintEqualToAnchor:addStepButton.bottomAnchor constant:10.0],
    [stepsErrorLabel.leadingAnchor constraintEqualToAnchor:stepsRowsStackView.leadingAnchor],
    [stepsErrorLabel.trailingAnchor constraintEqualToAnchor:stepsRowsStackView.trailingAnchor],
    [stepsErrorLabel.bottomAnchor constraintEqualToAnchor:stepsSectionView.bottomAnchor constant:-22.0]
  ]];
}

- (UIView *)sectionCardViewWithTitle:(NSString *)title accentColor:(UIColor *)accentColor accessibilityIdentifier:(NSString *)accessibilityIdentifier {
  UIView *containerView = [[[UIView alloc] init] autorelease];
  containerView.translatesAutoresizingMaskIntoConstraints = NO;
  [MRRLiquidGlassStyling applySurfaceRole:MRRGlassSurfaceRoleElevatedCard toView:containerView];
  containerView.layer.cornerRadius = 28.0;
  containerView.layer.borderColor = [MRRYoursEditorBorderColor() colorWithAlphaComponent:0.62].CGColor;
  containerView.accessibilityIdentifier = accessibilityIdentifier;

  UILabel *titleLabel = [self labelWithFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightBold] color:accentColor];
  titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  containerView.layer.shadowOpacity = 0.06f;
  containerView.layer.shadowRadius = 18.0f;
  containerView.layer.shadowOffset = CGSizeMake(0.0, 10.0);
  titleLabel.text = [title uppercaseString];
  [containerView addSubview:titleLabel];

  UIView *dividerView = [[[UIView alloc] init] autorelease];
  dividerView.translatesAutoresizingMaskIntoConstraints = NO;
  dividerView.backgroundColor = [MRRYoursEditorBorderColor() colorWithAlphaComponent:0.46];
  [containerView addSubview:dividerView];

  [NSLayoutConstraint activateConstraints:@[
    [titleLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:16.0],
    [titleLabel.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:22.0],
    [titleLabel.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-22.0],

    [dividerView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:14.0],
    [dividerView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
    [dividerView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
    [dividerView.heightAnchor constraintEqualToConstant:1.0]
  ]];
  return containerView;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
  UILabel *label = [[[UILabel alloc] init] autorelease];
  label.translatesAutoresizingMaskIntoConstraints = NO;
  label.font = font;
  label.textColor = color;
  label.adjustsFontForContentSizeCategory = YES;
  return label;
}

- (UITextField *)styledTextFieldWithPlaceholder:(NSString *)placeholder keyboardType:(UIKeyboardType)keyboardType identifier:(NSString *)identifier {
  UITextField *textField = [[[UITextField alloc] init] autorelease];
  textField.translatesAutoresizingMaskIntoConstraints = NO;
  textField.placeholder = placeholder;
  textField.keyboardType = keyboardType;
  textField.textColor = MRRYoursEditorPrimaryTextColor();
  textField.tintColor = MRRYoursEditorAccentColor();
  textField.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
  textField.clearButtonMode = UITextFieldViewModeWhileEditing;
  textField.leftView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)] autorelease];
  textField.leftViewMode = UITextFieldViewModeAlways;
  textField.accessibilityIdentifier = identifier;
  [MRRLiquidGlassStyling applyTextFieldStyling:textField];
  return textField;
}

- (UITextView *)styledTextViewWithIdentifier:(NSString *)identifier {
  UITextView *textView = [[[UITextView alloc] init] autorelease];
  textView.translatesAutoresizingMaskIntoConstraints = NO;
  textView.textColor = MRRYoursEditorPrimaryTextColor();
  textView.tintColor = MRRYoursEditorAccentColor();
  textView.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
  textView.layer.cornerRadius = 18.0;
  textView.layer.borderWidth = 1.0;
  textView.layer.borderColor = [MRRYoursEditorBorderColor() colorWithAlphaComponent:0.52].CGColor;
  textView.backgroundColor = [MRRYoursEditorMutedSurfaceColor() colorWithAlphaComponent:0.82];
  textView.textContainerInset = UIEdgeInsetsMake(14.0, 10.0, 14.0, 10.0);
  textView.accessibilityIdentifier = identifier;
  textView.delegate = self;
  return textView;
}

- (UIButton *)chipButtonWithTitle:(NSString *)title tintColor:(UIColor *)tintColor {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  button.layer.cornerRadius = 18.0;
  button.layer.borderWidth = 1.0;
  button.layer.borderColor = [tintColor colorWithAlphaComponent:0.14].CGColor;
  button.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
  button.contentEdgeInsets = UIEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);
  [button setTitle:title forState:UIControlStateNormal];
  [button.heightAnchor constraintGreaterThanOrEqualToConstant:42.0].active = YES;
  [self applySelectedState:NO toChipButton:button tintColor:tintColor];
  return button;
}

- (void)applySelectedState:(BOOL)selected toChipButton:(UIButton *)button tintColor:(UIColor *)tintColor {
  button.selected = selected;
  button.backgroundColor = selected ? tintColor : [MRRYoursEditorMutedSurfaceColor() colorWithAlphaComponent:0.86];
  [button setTitleColor:(selected ? [UIColor whiteColor] : MRRYoursEditorPrimaryTextColor()) forState:UIControlStateNormal];
  button.layer.borderColor = (selected ? tintColor : [tintColor colorWithAlphaComponent:0.14]).CGColor;
}

- (void)reloadPhotoUI {
  while (self.photoThumbnailsStackView.arrangedSubviews.count > 0) {
    UIView *subview = self.photoThumbnailsStackView.arrangedSubviews.firstObject;
    [self.photoThumbnailsStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  for (NSUInteger index = 0; index < self.photoDrafts.count; index += 1) {
    MRRYoursRecipePhotoDraft *draft = self.photoDrafts[index];
    UIButton *thumbnailButton = [UIButton buttonWithType:UIButtonTypeSystem];
    thumbnailButton.translatesAutoresizingMaskIntoConstraints = NO;
    thumbnailButton.tag = (NSInteger)index;
    thumbnailButton.layer.cornerRadius = 16.0;
    thumbnailButton.layer.borderWidth = 2.0;
    thumbnailButton.layer.borderColor = ((NSInteger)index == self.selectedPhotoIndex ? MRRYoursEditorAccentColor() : [MRRYoursEditorBorderColor() colorWithAlphaComponent:0.45]).CGColor;
    thumbnailButton.backgroundColor = [MRRYoursEditorMutedSurfaceColor() colorWithAlphaComponent:0.85];
    thumbnailButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    [thumbnailButton setTitle:[NSString stringWithFormat:@"%lu", (unsigned long)(index + 1)] forState:UIControlStateNormal];
    [thumbnailButton setTitleColor:MRRYoursEditorPrimaryTextColor() forState:UIControlStateNormal];
    UIImage *previewImage = [self displayImageForPhotoDraft:draft];
    if (previewImage != nil) {
      [thumbnailButton setBackgroundImage:previewImage forState:UIControlStateNormal];
      [thumbnailButton setTitle:@"" forState:UIControlStateNormal];
    }
    [thumbnailButton.widthAnchor constraintEqualToConstant:62.0].active = YES;
    [thumbnailButton.heightAnchor constraintEqualToConstant:62.0].active = YES;
    [thumbnailButton addTarget:self action:@selector(handleThumbnailTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.photoThumbnailsStackView addArrangedSubview:thumbnailButton];
  }

  self.selectedPhotoIndex = MAX(0, MIN(self.selectedPhotoIndex, (NSInteger)self.photoDrafts.count - 1));
  self.photoHelperLabel.text = self.photoDrafts.count > 0
                                   ? [NSString stringWithFormat:@"%lu of %ld photos. Cover uses the first slot in your gallery.",
                                                                  (unsigned long)(self.selectedPhotoIndex + 1),
                                                                  (long)self.photoDrafts.count]
                                   : @"Add up to 5 photos. Local photos stay on this device until remote URLs exist.";
  self.setCoverButton.enabled = self.photoDrafts.count > 1 && self.selectedPhotoIndex > 0;
  self.removePhotoButton.enabled = self.photoDrafts.count > 0;
  self.addPhotoButton.enabled = self.photoDrafts.count < MRRYoursRecipeEditorMaximumPhotoCount;
  [self reloadCoverImage];
}

- (void)reloadCoverImage {
  MRRYoursRecipePhotoDraft *selectedDraft =
      (self.selectedPhotoIndex >= 0 && self.selectedPhotoIndex < (NSInteger)self.photoDrafts.count) ? self.photoDrafts[self.selectedPhotoIndex] : nil;
  UIImage *previewImage = [self displayImageForPhotoDraft:selectedDraft];
  if (previewImage != nil) {
    self.coverImageView.image = previewImage;
    return;
  }

  self.coverImageView.image = [UIImage imageNamed:self.existingRecipe.assetName.length > 0 ? self.existingRecipe.assetName : [MRRUserRecipeSnapshot defaultAssetName]];
  NSString *remoteURLString = MRRYoursEditorTrimmedString(selectedDraft.remoteURLString ?: @"");
  if (remoteURLString.length == 0) {
    return;
  }

  NSURL *imageURL = [NSURL URLWithString:remoteURLString];
  if (imageURL == nil) {
    return;
  }

  self.coverImageRequestToken += 1;
  NSUInteger requestToken = self.coverImageRequestToken;
  __block MRRYoursRecipeEditorViewController *blockSelf = self;
  NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:imageURL
                                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                            #pragma unused(response)
                                                            if (error != nil || data.length == 0) {
                                                              return;
                                                            }
                                                            UIImage *image = [[[UIImage alloc] initWithData:data] autorelease];
                                                            if (image == nil) {
                                                              return;
                                                            }
                                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                              MRRYoursRecipeEditorViewController *strongSelf = blockSelf;
                                                              if (strongSelf == nil || requestToken != strongSelf.coverImageRequestToken) {
                                                                return;
                                                              }
                                                              selectedDraft.previewImage = image;
                                                              strongSelf.coverImageView.image = image;
                                                              [strongSelf reloadPhotoUI];
                                                            });
                                                          }];
  [task resume];
}

- (UIImage *)displayImageForPhotoDraft:(MRRYoursRecipePhotoDraft *)photoDraft {
  if (photoDraft == nil) {
    return nil;
  }
  if (photoDraft.previewImage != nil) {
    return photoDraft.previewImage;
  }
  if (photoDraft.localRelativePath.length > 0) {
    NSURL *fileURL = [self.photoStorage fileURLForRelativePath:photoDraft.localRelativePath];
    if (fileURL.path.length > 0) {
      UIImage *image = [UIImage imageWithContentsOfFile:fileURL.path];
      if (image != nil) {
        photoDraft.previewImage = image;
      }
      return image;
    }
  }
  return nil;
}

- (void)reloadMealTypeSelection {
  for (NSString *mealType in MRRYoursEditorMealTypes()) {
    UIButton *button = [self.mealTypeButtonsByIdentifier objectForKey:mealType];
    [self applySelectedState:[self.selectedMealType isEqualToString:mealType] toChipButton:button tintColor:MRRYoursEditorInfoBlueColor()];
  }
}

- (void)reloadTagSelection {
  for (NSString *tagValue in MRRYoursEditorSuggestionTags()) {
    UIButton *button = [self.tagButtonsByValue objectForKey:tagValue];
    [self applySelectedState:button.selected toChipButton:button tintColor:MRRYoursEditorSuccessColor()];
  }
}

- (void)reloadIngredientRowsWithValues:(NSArray<NSString *> *)values {
  while (self.ingredientsRowsStackView.arrangedSubviews.count > 0) {
    UIView *subview = self.ingredientsRowsStackView.arrangedSubviews.firstObject;
    [self.ingredientsRowsStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  NSArray<NSString *> *resolvedValues = values.count > 0 ? values : @[ @"" ];
  for (NSUInteger index = 0; index < resolvedValues.count; index += 1) {
    UIView *rowView = [[[UIView alloc] init] autorelease];
    rowView.translatesAutoresizingMaskIntoConstraints = NO;
    rowView.backgroundColor = [MRRYoursEditorMutedSurfaceColor() colorWithAlphaComponent:0.78];
    rowView.layer.cornerRadius = 18.0;

    UILabel *badgeLabel = [self labelWithFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightBold] color:[UIColor whiteColor]];
    badgeLabel.backgroundColor = MRRYoursEditorSuccessColor();
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)(index + 1)];
    badgeLabel.layer.cornerRadius = 14.0;
    badgeLabel.clipsToBounds = YES;
    [rowView addSubview:badgeLabel];

    UITextField *textField = [self styledTextFieldWithPlaceholder:@"e.g. 2 cups flour" keyboardType:UIKeyboardTypeDefault identifier:[NSString stringWithFormat:@"yours.editor.ingredientField.%lu", (unsigned long)index]];
    textField.text = resolvedValues[index];
    [rowView addSubview:textField];

    UIButton *removeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    removeButton.translatesAutoresizingMaskIntoConstraints = NO;
    removeButton.tag = (NSInteger)index;
    [removeButton setTitle:@"Delete" forState:UIControlStateNormal];
    [removeButton setTitleColor:MRRYoursEditorErrorColor() forState:UIControlStateNormal];
    removeButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [removeButton addTarget:self action:@selector(handleRemoveIngredientTapped:) forControlEvents:UIControlEventTouchUpInside];
    [rowView addSubview:removeButton];

    [NSLayoutConstraint activateConstraints:@[
      [badgeLabel.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor constant:12.0],
      [badgeLabel.centerYAnchor constraintEqualToAnchor:rowView.centerYAnchor],
      [badgeLabel.widthAnchor constraintEqualToConstant:28.0],
      [badgeLabel.heightAnchor constraintEqualToConstant:28.0],

      [textField.topAnchor constraintEqualToAnchor:rowView.topAnchor constant:10.0],
      [textField.bottomAnchor constraintEqualToAnchor:rowView.bottomAnchor constant:-10.0],
      [textField.leadingAnchor constraintEqualToAnchor:badgeLabel.trailingAnchor constant:10.0],
      [textField.trailingAnchor constraintEqualToAnchor:removeButton.leadingAnchor constant:-8.0],
      [textField.heightAnchor constraintEqualToConstant:44.0],

      [removeButton.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor constant:-12.0],
      [removeButton.centerYAnchor constraintEqualToAnchor:rowView.centerYAnchor],
      [removeButton.widthAnchor constraintGreaterThanOrEqualToConstant:54.0]
    ]];
    [self.ingredientsRowsStackView addArrangedSubview:rowView];
  }
}

- (void)reloadStepRowsWithValues:(NSArray<NSString *> *)values {
  while (self.stepsRowsStackView.arrangedSubviews.count > 0) {
    UIView *subview = self.stepsRowsStackView.arrangedSubviews.firstObject;
    [self.stepsRowsStackView removeArrangedSubview:subview];
    [subview removeFromSuperview];
  }

  NSArray<NSString *> *resolvedValues = values.count > 0 ? values : @[ @"" ];
  for (NSUInteger index = 0; index < resolvedValues.count; index += 1) {
    UIView *rowView = [[[UIView alloc] init] autorelease];
    rowView.translatesAutoresizingMaskIntoConstraints = NO;
    rowView.backgroundColor = [MRRYoursEditorMutedSurfaceColor() colorWithAlphaComponent:0.78];
    rowView.layer.cornerRadius = 18.0;

    UILabel *badgeLabel = [self labelWithFont:[UIFont systemFontOfSize:14.0 weight:UIFontWeightBold] color:[UIColor whiteColor]];
    badgeLabel.backgroundColor = MRRYoursEditorInfoBlueColor();
    badgeLabel.textAlignment = NSTextAlignmentCenter;
    badgeLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)(index + 1)];
    badgeLabel.layer.cornerRadius = 14.0;
    badgeLabel.clipsToBounds = YES;
    [rowView addSubview:badgeLabel];

    UITextField *textField = [self styledTextFieldWithPlaceholder:[NSString stringWithFormat:@"Step %lu", (unsigned long)(index + 1)] keyboardType:UIKeyboardTypeDefault identifier:[NSString stringWithFormat:@"yours.editor.stepField.%lu", (unsigned long)index]];
    textField.text = resolvedValues[index];
    [rowView addSubview:textField];

    UIButton *removeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    removeButton.translatesAutoresizingMaskIntoConstraints = NO;
    removeButton.tag = (NSInteger)index;
    [removeButton setTitle:@"Delete" forState:UIControlStateNormal];
    [removeButton setTitleColor:MRRYoursEditorErrorColor() forState:UIControlStateNormal];
    removeButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [removeButton addTarget:self action:@selector(handleRemoveStepTapped:) forControlEvents:UIControlEventTouchUpInside];
    [rowView addSubview:removeButton];

    [NSLayoutConstraint activateConstraints:@[
      [badgeLabel.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor constant:12.0],
      [badgeLabel.centerYAnchor constraintEqualToAnchor:rowView.centerYAnchor],
      [badgeLabel.widthAnchor constraintEqualToConstant:28.0],
      [badgeLabel.heightAnchor constraintEqualToConstant:28.0],

      [textField.topAnchor constraintEqualToAnchor:rowView.topAnchor constant:10.0],
      [textField.bottomAnchor constraintEqualToAnchor:rowView.bottomAnchor constant:-10.0],
      [textField.leadingAnchor constraintEqualToAnchor:badgeLabel.trailingAnchor constant:10.0],
      [textField.trailingAnchor constraintEqualToAnchor:removeButton.leadingAnchor constant:-8.0],
      [textField.heightAnchor constraintEqualToConstant:44.0],

      [removeButton.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor constant:-12.0],
      [removeButton.centerYAnchor constraintEqualToAnchor:rowView.centerYAnchor],
      [removeButton.widthAnchor constraintGreaterThanOrEqualToConstant:54.0]
    ]];
    [self.stepsRowsStackView addArrangedSubview:rowView];
  }
}

- (NSArray<NSString *> *)currentTextsFromRowsStackView:(UIStackView *)stackView {
  NSMutableArray<NSString *> *values = [NSMutableArray array];
  for (UIView *rowView in stackView.arrangedSubviews) {
    for (UIView *subview in rowView.subviews) {
      if (![subview isKindOfClass:[UITextField class]]) {
        continue;
      }
      NSString *trimmedValue = MRRYoursEditorTrimmedString(((UITextField *)subview).text ?: @"");
      [values addObject:trimmedValue ?: @""];
      break;
    }
  }
  return values;
}

- (void)handleAddPhotoTapped:(id)sender {
  [self presentPhotoPickerFromSourceView:(UIView *)sender];
}

- (BOOL)appendPhotoWithImage:(UIImage *)image error:(NSError **)error {
  if (![image isKindOfClass:[UIImage class]]) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRYoursRecipeEditorValidationErrorDomain
                                   code:31
                               userInfo:@{NSLocalizedDescriptionKey : @"Photo could not be added."}];
    }
    return NO;
  }
  if (self.photoDrafts.count >= MRRYoursRecipeEditorMaximumPhotoCount) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRYoursRecipeEditorValidationErrorDomain
                                   code:32
                               userInfo:@{NSLocalizedDescriptionKey : @"You can add up to 5 photos for now."}];
    }
    return NO;
  }

  MRRYoursRecipePhotoDraft *draft = [[[MRRYoursRecipePhotoDraft alloc] initWithPhotoID:[NSUUID UUID].UUIDString
                                                                         remoteURLString:nil
                                                                       localRelativePath:nil
                                                                            previewImage:image] autorelease];
  [self.photoDrafts addObject:draft];
  self.selectedPhotoIndex = (NSInteger)self.photoDrafts.count - 1;
  [self reloadPhotoUI];
  return YES;
}

- (void)handleSetCoverTapped:(id)sender {
  #pragma unused(sender)
  if (self.selectedPhotoIndex <= 0 || self.selectedPhotoIndex >= (NSInteger)self.photoDrafts.count) {
    return;
  }
  MRRYoursRecipePhotoDraft *selectedDraft = [[[self.photoDrafts objectAtIndex:self.selectedPhotoIndex] retain] autorelease];
  [self.photoDrafts removeObjectAtIndex:self.selectedPhotoIndex];
  [self.photoDrafts insertObject:selectedDraft atIndex:0];
  self.selectedPhotoIndex = 0;
  [self reloadPhotoUI];
}

- (void)handleRemovePhotoTapped:(id)sender {
  #pragma unused(sender)
  if (self.selectedPhotoIndex < 0 || self.selectedPhotoIndex >= (NSInteger)self.photoDrafts.count) {
    return;
  }
  MRRYoursRecipePhotoDraft *draft = [self.photoDrafts objectAtIndex:self.selectedPhotoIndex];
  if (draft.localRelativePath.length > 0) {
    [self.removedLocalRelativePaths addObject:draft.localRelativePath];
  }
  [self.photoDrafts removeObjectAtIndex:self.selectedPhotoIndex];
  self.selectedPhotoIndex = MAX(0, MIN(self.selectedPhotoIndex, (NSInteger)self.photoDrafts.count - 1));
  [self reloadPhotoUI];
}

- (void)handleMealTypeButtonTapped:(UIButton *)sender {
  for (NSString *mealType in self.mealTypeButtonsByIdentifier) {
    if ([self.mealTypeButtonsByIdentifier objectForKey:mealType] == sender) {
      self.selectedMealType = mealType;
      break;
    }
  }
  [self reloadMealTypeSelection];
}

- (void)handleTagButtonTapped:(UIButton *)sender {
  sender.selected = !sender.selected;
  [self reloadTagSelection];
}

- (void)handleIngredientAddTapped:(id)sender {
  #pragma unused(sender)
  NSMutableArray<NSString *> *values = [[self currentTextsFromRowsStackView:self.ingredientsRowsStackView] mutableCopy];
  [values addObject:@""];
  [self reloadIngredientRowsWithValues:values];
  [values release];
}

- (void)handleStepAddTapped:(id)sender {
  #pragma unused(sender)
  NSMutableArray<NSString *> *values = [[self currentTextsFromRowsStackView:self.stepsRowsStackView] mutableCopy];
  [values addObject:@""];
  [self reloadStepRowsWithValues:values];
  [values release];
}

- (void)handleRemoveIngredientTapped:(UIButton *)sender {
  NSMutableArray<NSString *> *values = [[self currentTextsFromRowsStackView:self.ingredientsRowsStackView] mutableCopy];
  if (sender.tag >= 0 && sender.tag < (NSInteger)values.count) {
    [values removeObjectAtIndex:(NSUInteger)sender.tag];
  }
  [self reloadIngredientRowsWithValues:values];
  [values release];
}

- (void)handleRemoveStepTapped:(UIButton *)sender {
  NSMutableArray<NSString *> *values = [[self currentTextsFromRowsStackView:self.stepsRowsStackView] mutableCopy];
  if (sender.tag >= 0 && sender.tag < (NSInteger)values.count) {
    [values removeObjectAtIndex:(NSUInteger)sender.tag];
  }
  [self reloadStepRowsWithValues:values];
  [values release];
}

- (void)handleThumbnailTapped:(UIButton *)sender {
  self.selectedPhotoIndex = sender.tag;
  [self reloadPhotoUI];
}

- (void)presentPhotoPickerFromSourceView:(UIView *)sourceView {
  if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
    NSError *error = [NSError errorWithDomain:MRRYoursRecipeEditorValidationErrorDomain
                                         code:30
                                     userInfo:@{NSLocalizedDescriptionKey : @"Photo library is not available on this device."}];
    [self presentValidationError:error];
    return;
  }

  UIImagePickerController *pickerController = [[[UIImagePickerController alloc] init] autorelease];
  pickerController.delegate = self;
  pickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
  pickerController.modalPresentationStyle = UIModalPresentationFullScreen;
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    pickerController.modalPresentationStyle = UIModalPresentationPopover;
    UIPopoverPresentationController *popoverPresentationController = pickerController.popoverPresentationController;
    popoverPresentationController.sourceView = sourceView;
    popoverPresentationController.sourceRect = sourceView.bounds;
  }
  [self presentViewController:pickerController animated:YES completion:nil];
}

- (void)handleSaveTapped:(id)sender {
  #pragma unused(sender)
  [self.view endEditing:YES];
  [self clearValidationErrors];

  NSError *error = nil;
  if (![self persistDraftWithError:&error]) {
    if (error != nil) {
      [self presentValidationError:error];
    }
    return;
  }
  self.didPersistRecipe = YES;
  [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)persistDraftWithError:(NSError **)error {
  if (self.userRecipesStore == nil || self.sessionUserID.length == 0) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRYoursRecipeEditorValidationErrorDomain
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : @"Your account is not ready to save recipes yet."}];
    }
    return NO;
  }

  NSString *trimmedTitle = MRRYoursEditorTrimmedString(self.titleField.text ?: @"");
  if (trimmedTitle.length == 0) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRYoursRecipeEditorValidationErrorDomain
                                   code:2
                               userInfo:@{NSLocalizedDescriptionKey : @"Recipe name is required."}];
    }
    [self showValidationMessage:@"Recipe name is required." onLabel:self.basicInfoErrorLabel scrollTarget:self.basicInfoSectionView];
    return NO;
  }

  NSArray<MRRUserRecipeIngredientSnapshot *> *ingredients = [self ingredientSnapshotsFromCurrentRows];
  if (ingredients.count == 0) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRYoursRecipeEditorValidationErrorDomain
                                   code:3
                               userInfo:@{NSLocalizedDescriptionKey : @"Add at least one ingredient."}];
    }
    [self showValidationMessage:@"Add at least one ingredient." onLabel:self.ingredientsErrorLabel scrollTarget:self.ingredientsSectionView];
    return NO;
  }

  NSArray<MRRUserRecipeInstructionSnapshot *> *steps = [self instructionSnapshotsFromCurrentRows];
  if (steps.count == 0) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRYoursRecipeEditorValidationErrorDomain
                                   code:4
                               userInfo:@{NSLocalizedDescriptionKey : @"Add at least one cooking step."}];
    }
    [self showValidationMessage:@"Add at least one cooking step." onLabel:self.stepsErrorLabel scrollTarget:self.stepsSectionView];
    return NO;
  }

  NSArray<MRRUserRecipePhotoSnapshot *> *photos = [self resolvedPhotoSnapshotsWithError:error];
  if (photos == nil) {
    return NO;
  }

  NSInteger readyInMinutes = [self resolvedIntegerValueFromText:self.cookTimeField.text
                                                       fallback:(self.existingRecipe != nil ? self.existingRecipe.readyInMinutes : 30)
                                                   minimumValue:1];
  NSInteger servings = [self resolvedIntegerValueFromText:self.servingsField.text
                                                 fallback:(self.existingRecipe != nil ? self.existingRecipe.servings : 2)
                                             minimumValue:1];
  NSInteger calorieCount = [self resolvedIntegerValueFromText:self.caloriesField.text
                                                     fallback:(self.existingRecipe != nil ? self.existingRecipe.calorieCount : 0)
                                                 minimumValue:0];

  MRRUserRecipeSnapshot *snapshot =
      [[[MRRUserRecipeSnapshot alloc] initWithUserID:self.sessionUserID
                                           recipeID:self.draftRecipeID
                                              title:trimmedTitle
                                           subtitle:MRRYoursEditorTrimmedString(self.subtitleField.text ?: @"")
                                        summaryText:[MRRYoursEditorTrimmedString(self.summaryTextView.text ?: @"") isEqualToString:@"Describe your recipe briefly..."] ? @""
                                                                                                                               : MRRYoursEditorTrimmedString(self.summaryTextView.text ?: @"")
                                           mealType:(self.selectedMealType.length > 0 ? self.selectedMealType : MRRUserRecipeMealTypeSnack)
                                     readyInMinutes:readyInMinutes
                                           servings:servings
                                       calorieCount:MAX(0, calorieCount)
                                          assetName:(self.existingRecipe.assetName.length > 0 ? self.existingRecipe.assetName : [MRRUserRecipeSnapshot defaultAssetName])
                                   heroImageURLString:self.existingRecipe.heroImageURLString
                                              photos:photos
                                        ingredients:ingredients
                                       instructions:steps
                                              tools:(self.preservedTools ?: @[])
                                               tags:[self tagSnapshotsForCurrentSelection]
                                          createdAt:(self.existingRecipe.createdAt ?: [NSDate date])
                                    localModifiedAt:[NSDate date]
                                    remoteUpdatedAt:self.existingRecipe.remoteUpdatedAt] autorelease];

  BOOL didSave = [self.userRecipesStore saveRecipeSnapshot:snapshot error:error];
  if (!didSave) {
    return NO;
  }

  for (NSString *removedRelativePath in self.removedLocalRelativePaths) {
    [self.photoStorage removeImageAtRelativePath:removedRelativePath error:nil];
  }
  [self.removedLocalRelativePaths removeAllObjects];
  [self.createdLocalRelativePaths removeAllObjects];
  [self.syncEngine requestImmediateSyncForUserID:self.sessionUserID];
  return YES;
}

- (NSArray<MRRUserRecipePhotoSnapshot *> *)resolvedPhotoSnapshotsWithError:(NSError **)error {
  NSMutableArray<MRRUserRecipePhotoSnapshot *> *snapshots = [NSMutableArray arrayWithCapacity:self.photoDrafts.count];
  for (NSUInteger index = 0; index < self.photoDrafts.count; index += 1) {
    MRRYoursRecipePhotoDraft *draft = self.photoDrafts[index];
    NSString *localRelativePath = draft.localRelativePath;
    if (draft.previewImage != nil && localRelativePath.length == 0) {
      NSString *createdRelativePath = [self.photoStorage storeImage:draft.previewImage
                                                           recipeID:self.draftRecipeID
                                                            photoID:draft.photoID
                                                              error:error];
      if (createdRelativePath.length == 0) {
        return nil;
      }
      draft.localRelativePath = createdRelativePath;
      localRelativePath = createdRelativePath;
      [self.createdLocalRelativePaths addObject:createdRelativePath];
    }
    if (draft.remoteURLString.length == 0 && localRelativePath.length == 0) {
      continue;
    }
    MRRUserRecipePhotoSnapshot *snapshot =
        [[[MRRUserRecipePhotoSnapshot alloc] initWithPhotoID:draft.photoID
                                                  orderIndex:(NSInteger)index
                                             remoteURLString:draft.remoteURLString
                                           localRelativePath:localRelativePath] autorelease];
    [snapshots addObject:snapshot];
  }
  return snapshots;
}

- (NSArray<MRRUserRecipeIngredientSnapshot *> *)ingredientSnapshotsFromCurrentRows {
  NSArray<NSString *> *values = [self currentTextsFromRowsStackView:self.ingredientsRowsStackView];
  NSMutableArray<MRRUserRecipeIngredientSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (NSString *value in values) {
    NSString *trimmedValue = MRRYoursEditorTrimmedString(value ?: @"");
    if (trimmedValue.length == 0) {
      continue;
    }
    MRRUserRecipeIngredientSnapshot *snapshot =
        [[[MRRUserRecipeIngredientSnapshot alloc] initWithName:trimmedValue displayText:trimmedValue orderIndex:(NSInteger)orderIndex] autorelease];
    [snapshots addObject:snapshot];
    orderIndex += 1;
  }
  return snapshots;
}

- (NSArray<MRRUserRecipeInstructionSnapshot *> *)instructionSnapshotsFromCurrentRows {
  NSArray<NSString *> *values = [self currentTextsFromRowsStackView:self.stepsRowsStackView];
  NSMutableArray<MRRUserRecipeInstructionSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (NSString *value in values) {
    NSString *trimmedValue = MRRYoursEditorTrimmedString(value ?: @"");
    if (trimmedValue.length == 0) {
      continue;
    }
    NSString *title = [NSString stringWithFormat:@"Step %lu", (unsigned long)(orderIndex + 1)];
    MRRUserRecipeInstructionSnapshot *snapshot =
        [[[MRRUserRecipeInstructionSnapshot alloc] initWithTitle:title detailText:trimmedValue orderIndex:(NSInteger)orderIndex] autorelease];
    [snapshots addObject:snapshot];
    orderIndex += 1;
  }
  return snapshots;
}

- (NSArray<MRRUserRecipeStringSnapshot *> *)tagSnapshotsForCurrentSelection {
  NSMutableOrderedSet<NSString *> *tagValues = [NSMutableOrderedSet orderedSet];
  for (NSString *preservedTagValue in self.preservedTagValues) {
    NSString *trimmedTagValue = MRRYoursEditorTrimmedString(preservedTagValue ?: @"");
    if (trimmedTagValue.length > 0) {
      [tagValues addObject:trimmedTagValue];
    }
  }
  for (NSString *tagValue in MRRYoursEditorSuggestionTags()) {
    UIButton *button = [self.tagButtonsByValue objectForKey:tagValue];
    if (button.selected) {
      [tagValues addObject:tagValue];
    }
  }
  NSMutableArray<MRRUserRecipeStringSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (NSString *tagValue in tagValues) {
    [snapshots addObject:[[[MRRUserRecipeStringSnapshot alloc] initWithValue:tagValue orderIndex:(NSInteger)orderIndex] autorelease]];
    orderIndex += 1;
  }
  return snapshots;
}

- (NSInteger)resolvedIntegerValueFromText:(NSString *)text fallback:(NSInteger)fallback minimumValue:(NSInteger)minimumValue {
  NSString *trimmedText = MRRYoursEditorTrimmedString(text ?: @"");
  if (trimmedText.length == 0) {
    return MAX(minimumValue, fallback);
  }
  NSInteger value = [trimmedText integerValue];
  return value < minimumValue ? MAX(minimumValue, fallback) : value;
}

- (void)presentValidationError:(NSError *)error {
  NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : @"Please review your recipe and try again.";
  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Couldn't save recipe"
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
  [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
  [self presentViewController:alertController animated:YES completion:nil];
}

- (void)clearValidationErrors {
  self.basicInfoErrorLabel.hidden = YES;
  self.ingredientsErrorLabel.hidden = YES;
  self.stepsErrorLabel.hidden = YES;
}

- (void)showValidationMessage:(NSString *)message onLabel:(UILabel *)label scrollTarget:(UIView *)scrollTarget {
  label.text = message;
  label.hidden = NO;
  if (label != self.basicInfoErrorLabel) {
    self.basicInfoErrorLabel.text = message;
    self.basicInfoErrorLabel.hidden = NO;
  }
  CGRect targetRect = [self.scrollView convertRect:scrollTarget.frame fromView:scrollTarget.superview];
  [self.scrollView scrollRectToVisible:CGRectInset(targetRect, 0.0, -20.0) animated:YES];
}

- (void)cleanupUnsavedLocalPhotosIfNeeded {
  if (self.didPersistRecipe) {
    return;
  }
  for (NSString *relativePath in self.createdLocalRelativePaths) {
    [self.photoStorage removeImageAtRelativePath:relativePath error:nil];
  }
  [self.createdLocalRelativePaths removeAllObjects];
}

- (void)handleKeyboardWillChangeFrame:(NSNotification *)notification {
  NSDictionary *userInfo = notification.userInfo;
  CGRect keyboardFrame = [userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGRect keyboardFrameInView = [self.view convertRect:keyboardFrame fromView:nil];
  CGRect intersection = CGRectIntersection(self.view.bounds, keyboardFrameInView);
  CGFloat safeAreaBottomInset = 0.0;
  if (@available(iOS 11.0, *)) {
    safeAreaBottomInset = self.view.safeAreaInsets.bottom;
  }
  CGFloat overlapHeight = CGRectIsNull(intersection) ? 0.0 : CGRectGetHeight(intersection);
  CGFloat keyboardInset = MAX(0.0, overlapHeight - safeAreaBottomInset);
  UIEdgeInsets insets = self.scrollView.contentInset;
  insets.bottom = keyboardInset > 0.0 ? keyboardInset + MRRYoursRecipeEditorKeyboardGap : 0.0;
  self.scrollView.contentInset = insets;
  self.scrollView.scrollIndicatorInsets = insets;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
  [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
  UIImage *selectedImage = info[UIImagePickerControllerOriginalImage];
  if ([selectedImage isKindOfClass:[UIImage class]]) {
    [self appendPhotoWithImage:selectedImage error:nil];
  }
  [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)textViewDidBeginEditing:(UITextView *)textView {
  if (textView == self.summaryTextView && [textView.text isEqualToString:@"Describe your recipe briefly..."]) {
    textView.text = @"";
    textView.textColor = MRRYoursEditorPrimaryTextColor();
  }
}

- (void)textViewDidEndEditing:(UITextView *)textView {
  if (textView == self.summaryTextView && MRRYoursEditorTrimmedString(textView.text ?: @"").length == 0) {
    textView.text = @"Describe your recipe briefly...";
    textView.textColor = MRRYoursEditorSecondaryTextColor();
  }
}

@end
