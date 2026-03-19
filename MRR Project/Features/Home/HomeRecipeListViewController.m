#import "HomeRecipeListViewController.h"

#import "HomeCollectionViewCells.h"

static NSString *const MRRHomeRecipeListCellReuseIdentifier = @"MRRHomeRecipeListCell";

static UIColor *MRRHomeListDynamicColor(UIColor *lightColor, UIColor *darkColor) {
  if (@available(iOS 13.0, *)) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
      return traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? darkColor : lightColor;
    }];
  }

  return lightColor;
}

static UIColor *MRRHomeListNamedColor(NSString *name, UIColor *lightColor, UIColor *darkColor) {
  UIColor *namedColor = [UIColor colorNamed:name];
  return namedColor ?: MRRHomeListDynamicColor(lightColor, darkColor);
}

@interface HomeRecipeListViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property(nonatomic, copy) NSString *screenTitle;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *recipes;
@property(nonatomic, copy) NSString *emptyMessage;
@property(nonatomic, retain) UICollectionView *collectionView;
@property(nonatomic, retain) UILabel *emptyStateLabel;

@end

@implementation HomeRecipeListViewController

- (instancetype)initWithScreenTitle:(NSString *)screenTitle recipes:(NSArray<HomeRecipeCard *> *)recipes emptyMessage:(NSString *)emptyMessage {
  NSParameterAssert(screenTitle.length > 0);
  NSParameterAssert(recipes != nil);
  NSParameterAssert(emptyMessage.length > 0);

  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _screenTitle = [screenTitle copy];
    _recipes = [recipes copy];
    _emptyMessage = [emptyMessage copy];
  }

  return self;
}

- (void)dealloc {
  [_emptyStateLabel release];
  [_collectionView release];
  [_emptyMessage release];
  [_recipes release];
  [_screenTitle release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = self.screenTitle;
  self.view.accessibilityIdentifier = @"home.recipeList.view";
  self.view.backgroundColor = MRRHomeListNamedColor(@"BackgroundColor", [UIColor colorWithWhite:0.98 alpha:1.0],
                                                    [UIColor colorWithWhite:0.10 alpha:1.0]);

  UICollectionViewFlowLayout *layout = [[[UICollectionViewFlowLayout alloc] init] autorelease];
  layout.minimumLineSpacing = 18.0;
  layout.scrollDirection = UICollectionViewScrollDirectionVertical;

  UICollectionView *collectionView = [[[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout] autorelease];
  collectionView.translatesAutoresizingMaskIntoConstraints = NO;
  collectionView.backgroundColor = [UIColor clearColor];
  collectionView.alwaysBounceVertical = YES;
  collectionView.accessibilityIdentifier = @"home.recipeList.collectionView";
  collectionView.dataSource = self;
  collectionView.delegate = self;
  [collectionView registerClass:[HomeRecipeCardCell class] forCellWithReuseIdentifier:MRRHomeRecipeListCellReuseIdentifier];
  [self.view addSubview:collectionView];
  self.collectionView = collectionView;

  UILabel *emptyStateLabel = [[[UILabel alloc] init] autorelease];
  emptyStateLabel.translatesAutoresizingMaskIntoConstraints = NO;
  emptyStateLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
  emptyStateLabel.adjustsFontForContentSizeCategory = YES;
  emptyStateLabel.numberOfLines = 0;
  emptyStateLabel.textAlignment = NSTextAlignmentCenter;
  emptyStateLabel.textColor = MRRHomeListNamedColor(@"TextSecondaryColor", [UIColor colorWithWhite:0.46 alpha:1.0],
                                                    [UIColor colorWithWhite:0.74 alpha:1.0]);
  emptyStateLabel.text = self.emptyMessage;
  emptyStateLabel.hidden = self.recipes.count > 0;
  emptyStateLabel.accessibilityIdentifier = @"home.recipeList.emptyStateLabel";
  [self.view addSubview:emptyStateLabel];
  self.emptyStateLabel = emptyStateLabel;

  [NSLayoutConstraint activateConstraints:@[
    [collectionView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16.0],
    [collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

    [emptyStateLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [emptyStateLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    [emptyStateLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24.0],
    [emptyStateLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24.0]
  ]];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return self.recipes.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  HomeRecipeCardCell *cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:MRRHomeRecipeListCellReuseIdentifier forIndexPath:indexPath];
  if (indexPath.item < self.recipes.count) {
    [cell configureWithRecipeCard:self.recipes[indexPath.item] style:HomeRecipeCardCellStyleList];
  }
  return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
  CGFloat availableWidth = CGRectGetWidth(collectionView.bounds) - 32.0;
  return CGSizeMake(MAX(availableWidth, 220.0), 272.0);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
  return UIEdgeInsetsMake(0.0, 16.0, 28.0, 16.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.item >= self.recipes.count) {
    return;
  }

  [self.delegate homeRecipeListViewController:self didSelectRecipeCard:self.recipes[indexPath.item]];
}

@end
