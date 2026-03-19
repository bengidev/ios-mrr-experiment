#import "HomeDataSource.h"

#import "../Onboarding/Data/OnboardingRecipeCatalog.h"

NSString *const HomeSectionIdentifierRecommendation = @"recommendation";
NSString *const HomeSectionIdentifierWeekly = @"weekly";

NSString *const HomeCategoryIdentifierBreakfast = @"breakfast";
NSString *const HomeCategoryIdentifierLunch = @"lunch";
NSString *const HomeCategoryIdentifierDinner = @"dinner";
NSString *const HomeCategoryIdentifierDessert = @"dessert";
NSString *const HomeCategoryIdentifierSnack = @"snack";

static HomeCategory *MRRHomeCategory(NSString *identifier, NSString *title, NSString *badgeText) {
  return [[[HomeCategory alloc] initWithIdentifier:identifier title:title badgeText:badgeText] autorelease];
}

static HomeRecipeCard *MRRHomeCard(NSString *recipeID,
                                   NSString *title,
                                   NSString *subtitle,
                                   NSString *assetName,
                                   NSString *summaryText,
                                   NSInteger readyInMinutes,
                                   NSInteger servings,
                                   NSInteger calorieCount,
                                   NSInteger popularityScore,
                                   NSString *sourceName,
                                   NSString *mealType,
                                   NSArray<NSString *> *tags) {
  return [[[HomeRecipeCard alloc] initWithRecipeID:recipeID
                                             title:title
                                          subtitle:subtitle
                                         assetName:assetName
                                    imageURLString:nil
                                       summaryText:summaryText
                                    readyInMinutes:readyInMinutes
                                          servings:servings
                                      calorieCount:calorieCount
                                   popularityScore:popularityScore
                                        sourceName:sourceName
                                   sourceURLString:nil
                                          mealType:mealType
                                              tags:tags] autorelease];
}

static BOOL MRRHomeStringContainsQuery(NSString *string, NSString *query) {
  if (string.length == 0 || query.length == 0) {
    return NO;
  }

  return [string rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL MRRHomeArrayContainsQuery(NSArray<NSString *> *strings, NSString *query) {
  for (NSString *string in strings) {
    if (MRRHomeStringContainsQuery(string, query)) {
      return YES;
    }
  }

  return NO;
}

@interface HomeCategory ()

@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *badgeText;

@end

@implementation HomeCategory

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title badgeText:(NSString *)badgeText {
  NSParameterAssert(identifier.length > 0);
  NSParameterAssert(title.length > 0);
  NSParameterAssert(badgeText.length > 0);

  self = [super init];
  if (self) {
    _identifier = [identifier copy];
    _title = [title copy];
    _badgeText = [badgeText copy];
  }

  return self;
}

- (void)dealloc {
  [_badgeText release];
  [_title release];
  [_identifier release];
  [super dealloc];
}

@end

@interface HomeRecipeCard ()

@property(nonatomic, copy, readwrite) NSString *recipeID;
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *subtitle;
@property(nonatomic, copy, readwrite) NSString *assetName;
@property(nonatomic, copy, readwrite, nullable) NSString *imageURLString;
@property(nonatomic, copy, readwrite) NSString *summaryText;
@property(nonatomic, assign, readwrite) NSInteger readyInMinutes;
@property(nonatomic, assign, readwrite) NSInteger servings;
@property(nonatomic, assign, readwrite) NSInteger calorieCount;
@property(nonatomic, assign, readwrite) NSInteger popularityScore;
@property(nonatomic, copy, readwrite) NSString *sourceName;
@property(nonatomic, copy, readwrite, nullable) NSString *sourceURLString;
@property(nonatomic, copy, readwrite) NSString *mealType;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *tags;

@end

@implementation HomeRecipeCard

- (instancetype)initWithRecipeID:(NSString *)recipeID
                           title:(NSString *)title
                        subtitle:(NSString *)subtitle
                       assetName:(NSString *)assetName
                  imageURLString:(NSString *)imageURLString
                     summaryText:(NSString *)summaryText
                  readyInMinutes:(NSInteger)readyInMinutes
                        servings:(NSInteger)servings
                    calorieCount:(NSInteger)calorieCount
                 popularityScore:(NSInteger)popularityScore
                      sourceName:(NSString *)sourceName
                 sourceURLString:(NSString *)sourceURLString
                        mealType:(NSString *)mealType
                            tags:(NSArray<NSString *> *)tags {
  NSParameterAssert(recipeID.length > 0);
  NSParameterAssert(title.length > 0);
  NSParameterAssert(subtitle.length > 0);
  NSParameterAssert(assetName.length > 0);
  NSParameterAssert(summaryText.length > 0);
  NSParameterAssert(sourceName.length > 0);
  NSParameterAssert(mealType.length > 0);
  NSParameterAssert(tags != nil);

  self = [super init];
  if (self) {
    _recipeID = [recipeID copy];
    _title = [title copy];
    _subtitle = [subtitle copy];
    _assetName = [assetName copy];
    _imageURLString = [imageURLString copy];
    _summaryText = [summaryText copy];
    _readyInMinutes = readyInMinutes;
    _servings = servings;
    _calorieCount = calorieCount;
    _popularityScore = popularityScore;
    _sourceName = [sourceName copy];
    _sourceURLString = [sourceURLString copy];
    _mealType = [mealType copy];
    _tags = [tags copy];
  }

  return self;
}

- (void)dealloc {
  [_tags release];
  [_mealType release];
  [_sourceURLString release];
  [_sourceName release];
  [_summaryText release];
  [_imageURLString release];
  [_assetName release];
  [_subtitle release];
  [_title release];
  [_recipeID release];
  [super dealloc];
}

- (NSString *)durationText { return [NSString stringWithFormat:@"%ld min", (long)self.readyInMinutes]; }

- (NSString *)calorieText { return [NSString stringWithFormat:@"%ld kcal", (long)self.calorieCount]; }

- (NSString *)servingsText {
  return [NSString stringWithFormat:@"%ld servings", (long)self.servings];
}

@end

@interface HomeSection ()

@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSArray<HomeRecipeCard *> *recipes;

@end

@implementation HomeSection

- (instancetype)initWithIdentifier:(NSString *)identifier title:(NSString *)title recipes:(NSArray<HomeRecipeCard *> *)recipes {
  NSParameterAssert(identifier.length > 0);
  NSParameterAssert(title.length > 0);
  NSParameterAssert(recipes != nil);

  self = [super init];
  if (self) {
    _identifier = [identifier copy];
    _title = [title copy];
    _recipes = [recipes copy];
  }

  return self;
}

- (void)dealloc {
  [_recipes release];
  [_title release];
  [_identifier release];
  [super dealloc];
}

@end

@interface HomeMockDataProvider ()

@property(nonatomic, copy) NSArray<HomeCategory *> *categories;
@property(nonatomic, copy) NSArray<HomeSection *> *sections;
@property(nonatomic, copy) NSArray<HomeRecipeCard *> *allRecipes;
@property(nonatomic, retain) NSDictionary<NSString *, OnboardingRecipeDetail *> *detailsByRecipeID;

@end

@implementation HomeMockDataProvider

- (instancetype)init {
  self = [super init];
  if (self) {
    [self buildData];
  }

  return self;
}

- (void)dealloc {
  [_detailsByRecipeID release];
  [_allRecipes release];
  [_sections release];
  [_categories release];
  [super dealloc];
}

- (NSArray<HomeCategory *> *)availableCategories {
  return self.categories;
}

- (NSArray<HomeSection *> *)featuredSections {
  return self.sections;
}

- (NSArray<HomeRecipeCard *> *)recipesForCategory:(HomeCategory *)category {
  if (category == nil || category.identifier.length == 0) {
    return self.allRecipes;
  }

  NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(HomeRecipeCard *evaluatedObject, NSDictionary<NSString *, id> *bindings) {
    if ([evaluatedObject.mealType caseInsensitiveCompare:category.identifier] == NSOrderedSame) {
      return YES;
    }

    return MRRHomeArrayContainsQuery(evaluatedObject.tags, category.title);
  }];
  return [self.allRecipes filteredArrayUsingPredicate:predicate];
}

- (NSArray<HomeRecipeCard *> *)searchRecipes:(NSString *)query {
  NSString *trimmedQuery = [[query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
  if (trimmedQuery.length == 0) {
    return @[];
  }

  NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(HomeRecipeCard *evaluatedObject, NSDictionary<NSString *, id> *bindings) {
    return MRRHomeStringContainsQuery(evaluatedObject.title, trimmedQuery) ||
           MRRHomeStringContainsQuery(evaluatedObject.subtitle, trimmedQuery) ||
           MRRHomeStringContainsQuery(evaluatedObject.summaryText, trimmedQuery) ||
           MRRHomeStringContainsQuery(evaluatedObject.mealType, trimmedQuery) ||
           MRRHomeArrayContainsQuery(evaluatedObject.tags, trimmedQuery);
  }];
  return [self.allRecipes filteredArrayUsingPredicate:predicate];
}

- (OnboardingRecipeDetail *)recipeDetailForID:(NSString *)recipeID {
  if (recipeID.length == 0) {
    return nil;
  }

  return [self.detailsByRecipeID objectForKey:recipeID];
}

- (void)buildData {
  OnboardingRecipeCatalog *catalog = [[[OnboardingRecipeCatalog alloc] init] autorelease];
  NSArray<OnboardingRecipePreview *> *previews = [catalog allRecipePreviews];
  NSMutableDictionary<NSString *, OnboardingRecipePreview *> *previewsByTitle = [NSMutableDictionary dictionaryWithCapacity:previews.count];
  for (OnboardingRecipePreview *preview in previews) {
    if (preview.title.length > 0) {
      [previewsByTitle setObject:preview forKey:preview.title];
    }
  }

  self.categories = @[
    MRRHomeCategory(HomeCategoryIdentifierBreakfast, @"Breakfast", @"Br"),
    MRRHomeCategory(HomeCategoryIdentifierLunch, @"Lunch", @"Lu"),
    MRRHomeCategory(HomeCategoryIdentifierDinner, @"Dinner", @"Di"),
    MRRHomeCategory(HomeCategoryIdentifierDessert, @"Dessert", @"De"),
    MRRHomeCategory(HomeCategoryIdentifierSnack, @"Snack", @"Sn"),
  ];

  HomeRecipeCard *avocadoToast =
      MRRHomeCard(@"home.avocadoToast", @"Avocado Toast", @"Bright breakfast", @"avocado-toast",
                  @"Creamy avocado, citrus, and toasted sourdough make this a quick opener for calm mornings.",
                  10, 2, 280, 92, @"Culina Test Kitchen", HomeCategoryIdentifierBreakfast,
                  @[ @"Breakfast", @"Quick", @"Vegetarian", @"Toast" ]);
  HomeRecipeCard *greekSalad =
      MRRHomeCard(@"home.greekSalad", @"Greek Salad", @"Crunchy midday plate", @"greek-salad",
                  @"Fresh vegetables, feta, and olives keep this bowl sharp, bright, and easy to revisit.",
                  12, 2, 240, 81, @"Culina Test Kitchen", HomeCategoryIdentifierLunch,
                  @[ @"Lunch", @"Fresh", @"Vegetarian", @"Salad" ]);
  HomeRecipeCard *pastaCarbonara =
      MRRHomeCard(@"home.pastaCarbonara", @"Pasta Carbonara", @"Silky comfort bowl", @"pasta-carbonara",
                  @"A glossy sauce built from eggs, cheese, and pasta water without the heaviness of cream.",
                  25, 3, 520, 95, @"Culina Test Kitchen", HomeCategoryIdentifierLunch,
                  @[ @"Lunch", @"Pasta", @"Comfort", @"Italian" ]);
  HomeRecipeCard *searedSalmon =
      MRRHomeCard(@"home.searedSalmon", @"Seared Salmon", @"Fast weeknight dinner", @"salmon",
                  @"Golden seared salmon with butter, garlic, and lemon for a polished dinner in one pan.",
                  18, 2, 430, 88, @"Culina Test Kitchen", HomeCategoryIdentifierDinner,
                  @[ @"Dinner", @"Seafood", @"High Protein", @"Weeknight" ]);
  HomeRecipeCard *greenCurry =
      MRRHomeCard(@"home.greenCurry", @"Green Curry", @"Aromatic comfort", @"green-curry",
                  @"Fragrant curry paste, coconut milk, and herbs create a rich bowl that still feels lively.",
                  30, 3, 470, 90, @"Culina Test Kitchen", HomeCategoryIdentifierDinner,
                  @[ @"Dinner", @"Comfort", @"Curry", @"Herbs" ]);
  HomeRecipeCard *ramenBowl =
      MRRHomeCard(@"home.ramenBowl", @"Ramen Bowl", @"Cozy late-night pick", @"ramen",
                  @"A strong broth, springy noodles, and a few thoughtful toppings keep the bowl satisfying.",
                  22, 2, 560, 84, @"Culina Test Kitchen", HomeCategoryIdentifierSnack,
                  @[ @"Snack", @"Dinner", @"Noodles", @"Broth" ]);
  HomeRecipeCard *pizzaNight =
      MRRHomeCard(@"home.pizzaNight", @"Pizza Night", @"Crowd-pleasing classic", @"pizza",
                  @"Crisp crust, bright sauce, and bubbling cheese make this an easy favorite for sharing.",
                  35, 4, 610, 89, @"Culina Test Kitchen", HomeCategoryIdentifierSnack,
                  @[ @"Snack", @"Sharing", @"Classic", @"Baked" ]);
  HomeRecipeCard *beefBourguignon =
      MRRHomeCard(@"home.beefBourguignon", @"Beef Bourguignon", @"Slow-cooked showpiece", @"beef-bourguignon",
                  @"Deep sauce, tender beef, and a steady braise make this the most dramatic plate in the set.",
                  45, 4, 650, 86, @"Culina Test Kitchen", HomeCategoryIdentifierDinner,
                  @[ @"Dinner", @"Slow Cooked", @"Comfort", @"Rich" ]);

  self.allRecipes = @[
    avocadoToast, greekSalad, pastaCarbonara, searedSalmon, greenCurry, ramenBowl, pizzaNight, beefBourguignon
  ];

  NSArray<HomeRecipeCard *> *weeklyRecipes = @[ pastaCarbonara, searedSalmon, greenCurry, beefBourguignon ];
  self.sections = @[
    [[[HomeSection alloc] initWithIdentifier:HomeSectionIdentifierRecommendation title:@"Recommendation" recipes:self.allRecipes] autorelease],
    [[[HomeSection alloc] initWithIdentifier:HomeSectionIdentifierWeekly title:@"Recipes Of The Week" recipes:weeklyRecipes] autorelease]
  ];

  NSMutableDictionary<NSString *, OnboardingRecipeDetail *> *details = [NSMutableDictionary dictionaryWithCapacity:self.allRecipes.count];
  NSDictionary<NSString *, NSString *> *titleMap = @{
    avocadoToast.recipeID : @"Avocado Toast",
    greekSalad.recipeID : @"Greek Salad",
    pastaCarbonara.recipeID : @"Pasta Carbonara",
    searedSalmon.recipeID : @"Seared Salmon",
    greenCurry.recipeID : @"Green Curry",
    ramenBowl.recipeID : @"Ramen Bowl",
    pizzaNight.recipeID : @"Pizza Night",
    beefBourguignon.recipeID : @"Beef Bourguignon"
  };
  for (NSString *recipeID in titleMap) {
    NSString *title = [titleMap objectForKey:recipeID];
    OnboardingRecipePreview *preview = [previewsByTitle objectForKey:title];
    if (preview != nil && preview.fallbackDetail != nil) {
      [details setObject:preview.fallbackDetail forKey:recipeID];
    }
  }
  self.detailsByRecipeID = details;
}

@end
