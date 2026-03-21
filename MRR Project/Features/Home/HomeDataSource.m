#import "HomeDataSource.h"

#import "../Onboarding/Data/OnboardingRecipeCatalog.h"

NSString *const HomeSectionIdentifierRecommendation = @"recommendation";
NSString *const HomeSectionIdentifierWeekly = @"weekly";

NSString *const HomeCategoryIdentifierBreakfast = @"breakfast";
NSString *const HomeCategoryIdentifierLunch = @"lunch";
NSString *const HomeCategoryIdentifierDinner = @"dinner";
NSString *const HomeCategoryIdentifierDessert = @"dessert";
NSString *const HomeCategoryIdentifierSnack = @"snack";

static NSUInteger const MRRHomeLiveRailRecipeCount = 8;
static NSUInteger const MRRHomeFallbackSearchResultLimit = 12;

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

static void MRRHomeCompleteOnMainThread(dispatch_block_t block) {
  if (block == nil) {
    return;
  }

  if ([NSThread isMainThread]) {
    block();
    return;
  }

  dispatch_async(dispatch_get_main_queue(), block);
}

static NSString *MRRHomeTrimmedString(id candidate) {
  if (![candidate isKindOfClass:[NSString class]]) {
    return @"";
  }

  return [(NSString *)candidate stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *MRRHomeNormalizedKey(NSString *string) {
  return [[MRRHomeTrimmedString(string) lowercaseString] stringByReplacingOccurrencesOfString:@"  " withString:@" "];
}

static NSInteger MRRHomeFirstIntegerFromString(NSString *string) {
  NSScanner *scanner = [NSScanner scannerWithString:MRRHomeTrimmedString(string)];
  NSInteger value = 0;
  if ([scanner scanInteger:&value]) {
    return value;
  }
  return 0;
}

static NSArray<NSString *> *MRRHomeStringArrayFromJSONArray(id candidate) {
  if (![candidate isKindOfClass:[NSArray class]]) {
    return @[];
  }

  NSMutableArray<NSString *> *strings = [NSMutableArray array];
  for (id entry in (NSArray *)candidate) {
    NSString *value = MRRHomeTrimmedString(entry);
    if (value.length > 0) {
      [strings addObject:value];
    }
  }

  return strings;
}

static NSArray<HomeRecipeCard *> *MRRHomeLimitedRecipeCards(NSArray<HomeRecipeCard *> *recipes, NSUInteger limit) {
  if (limit == 0 || recipes.count <= limit) {
    return recipes;
  }

  return [recipes subarrayWithRange:NSMakeRange(0, limit)];
}

static NSString *MRRHomeDecodedHTMLString(NSString *string) {
  NSString *decodedString = MRRHomeTrimmedString(string);
  if (decodedString.length == 0) {
    return @"";
  }

  NSDictionary<NSString *, NSString *> *replacements = @{
    @"&amp;" : @"&",
    @"&nbsp;" : @" ",
    @"&quot;" : @"\"",
    @"&#39;" : @"'",
    @"&apos;" : @"'",
    @"&rsquo;" : @"'",
    @"&ldquo;" : @"\"",
    @"&rdquo;" : @"\"",
  };
  for (NSString *entity in replacements) {
    decodedString = [decodedString stringByReplacingOccurrencesOfString:entity withString:[replacements objectForKey:entity]];
  }

  decodedString = [decodedString stringByReplacingOccurrencesOfString:@"<[^>]+>"
                                                           withString:@" "
                                                              options:NSRegularExpressionSearch
                                                                range:NSMakeRange(0, decodedString.length)];
  decodedString = [decodedString stringByReplacingOccurrencesOfString:@"\\s+"
                                                           withString:@" "
                                                              options:NSRegularExpressionSearch
                                                                range:NSMakeRange(0, decodedString.length)];
  return [decodedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *MRRHomeMealTypeDisplayName(NSString *mealTypeIdentifier) {
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierBreakfast]) {
    return @"Breakfast";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierLunch]) {
    return @"Lunch";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierDinner]) {
    return @"Dinner";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierDessert]) {
    return @"Dessert";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierSnack]) {
    return @"Snack";
  }
  return @"Recipe";
}

static NSArray<HomeRecipeCard *> *MRRHomeRecipesSortedForFilterOption(NSArray<HomeRecipeCard *> *recipes, HomeFilterOption filterOption) {
  if (recipes.count < 2) {
    return recipes;
  }

  switch (filterOption) {
    case HomeFilterOptionFeatured:
      return recipes;
    case HomeFilterOptionFastest:
      return [recipes sortedArrayUsingComparator:^NSComparisonResult(HomeRecipeCard *left, HomeRecipeCard *right) {
        if (left.readyInMinutes == right.readyInMinutes) {
          return [left.title localizedCaseInsensitiveCompare:right.title];
        }
        return left.readyInMinutes < right.readyInMinutes ? NSOrderedAscending : NSOrderedDescending;
      }];
    case HomeFilterOptionPopular:
      return [recipes sortedArrayUsingComparator:^NSComparisonResult(HomeRecipeCard *left, HomeRecipeCard *right) {
        if (left.popularityScore == right.popularityScore) {
          return [left.title localizedCaseInsensitiveCompare:right.title];
        }
        return left.popularityScore > right.popularityScore ? NSOrderedAscending : NSOrderedDescending;
      }];
    case HomeFilterOptionLowCalorie:
      return [recipes sortedArrayUsingComparator:^NSComparisonResult(HomeRecipeCard *left, HomeRecipeCard *right) {
        if (left.calorieCount == right.calorieCount) {
          return [left.title localizedCaseInsensitiveCompare:right.title];
        }
        return left.calorieCount < right.calorieCount ? NSOrderedAscending : NSOrderedDescending;
      }];
  }
}

static NSString *MRRHomeSpoonacularSortDirectionForFilterOption(HomeFilterOption filterOption) {
  switch (filterOption) {
    case HomeFilterOptionFeatured:
      return nil;
    case HomeFilterOptionFastest:
      return @"asc";
    case HomeFilterOptionPopular:
      return @"desc";
    case HomeFilterOptionLowCalorie:
      return @"asc";
  }
}

static NSString *MRRHomeSpoonacularSearchSortForFilterOption(HomeFilterOption filterOption) {
  switch (filterOption) {
    case HomeFilterOptionFeatured:
      return nil;
    case HomeFilterOptionFastest:
      return @"time";
    case HomeFilterOptionPopular:
      return @"popularity";
    case HomeFilterOptionLowCalorie:
      return @"calories";
  }
}

static NSString *MRRHomeSpoonacularRecommendationSortForFilterOption(HomeFilterOption filterOption) {
  switch (filterOption) {
    case HomeFilterOptionFeatured:
    case HomeFilterOptionPopular:
      return @"popularity";
    case HomeFilterOptionFastest:
      return @"time";
    case HomeFilterOptionLowCalorie:
      return @"calories";
  }
}

static NSString *MRRHomeSpoonacularWeeklySortForFilterOption(HomeFilterOption filterOption) {
  switch (filterOption) {
    case HomeFilterOptionFeatured:
      return @"random";
    case HomeFilterOptionPopular:
      return @"popularity";
    case HomeFilterOptionFastest:
      return @"time";
    case HomeFilterOptionLowCalorie:
      return @"calories";
  }
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

- (NSString *)calorieText {
  if (self.calorieCount > 0) {
    return [NSString stringWithFormat:@"%ld kcal", (long)self.calorieCount];
  }

  return @"Calories vary";
}

- (NSString *)servingsText {
  if (self.servings > 0) {
    return [NSString stringWithFormat:@"%ld servings", (long)self.servings];
  }

  return @"Serving info varies";
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

- (NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *)recipesByCategoryIdentifier;

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

- (void)loadInitialSectionsForFilterOption:(HomeFilterOption)filterOption completion:(HomeInitialSectionsCompletion)completion {
  if (completion == nil) {
    return;
  }

  NSMutableArray<HomeSection *> *sections = [NSMutableArray array];
  for (HomeSection *section in (self.sections ?: @[])) {
    NSArray<HomeRecipeCard *> *sortedRecipes = MRRHomeRecipesSortedForFilterOption(section.recipes ?: @[], filterOption);
    [sections addObject:[[[HomeSection alloc] initWithIdentifier:section.identifier title:section.title recipes:sortedRecipes] autorelease]];
  }

  NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *recipesByCategoryIdentifier = [NSMutableDictionary dictionary];
  for (NSString *identifier in [[self recipesByCategoryIdentifier] allKeys]) {
    NSArray<HomeRecipeCard *> *recipes = [[self recipesByCategoryIdentifier] objectForKey:identifier] ?: @[];
    [recipesByCategoryIdentifier setObject:MRRHomeRecipesSortedForFilterOption(recipes, filterOption) forKey:identifier];
  }
  MRRHomeCompleteOnMainThread(^{
    completion(sections, recipesByCategoryIdentifier, NO);
  });
}

- (void)searchRecipes:(NSString *)query
                limit:(NSUInteger)limit
         filterOption:(HomeFilterOption)filterOption
           completion:(HomeRecipeSearchCompletion)completion {
  if (completion == nil) {
    return;
  }

  NSArray<HomeRecipeCard *> *recipes = [self searchRecipes:query];
  recipes = MRRHomeRecipesSortedForFilterOption(recipes, filterOption);
  recipes = MRRHomeLimitedRecipeCards(recipes, limit > 0 ? limit : MRRHomeFallbackSearchResultLimit);
  MRRHomeCompleteOnMainThread(^{
    completion(recipes, NO);
  });
}

- (void)loadRecipeDetailForRecipeCard:(HomeRecipeCard *)recipeCard completion:(HomeRecipeDetailCompletion)completion {
  if (completion == nil) {
    return;
  }

  OnboardingRecipeDetail *detail = [self recipeDetailForID:recipeCard.recipeID];
  MRRHomeCompleteOnMainThread(^{
    completion(detail, NO);
  });
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

- (NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *)recipesByCategoryIdentifier {
  NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *recipesByCategoryIdentifier =
      [NSMutableDictionary dictionaryWithCapacity:self.categories.count];
  for (HomeCategory *category in self.categories) {
    NSArray<HomeRecipeCard *> *recipes = [self recipesForCategory:category] ?: @[];
    [recipesByCategoryIdentifier setObject:recipes forKey:category.identifier];
  }

  return recipesByCategoryIdentifier;
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
    MRRHomeCategory(HomeCategoryIdentifierBreakfast, @"Breakfast", @"Bk"),
    MRRHomeCategory(HomeCategoryIdentifierLunch, @"Lunch", @"Lu"),
    MRRHomeCategory(HomeCategoryIdentifierDinner, @"Dinner", @"Dn"),
    MRRHomeCategory(HomeCategoryIdentifierDessert, @"Dessert", @"Sw"),
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

@interface MRRHomeSpoonacularAPIClient : NSObject

@property(nonatomic, copy) NSString *apiKey;
@property(nonatomic, retain) NSURLSession *URLSession;

- (instancetype)initWithAPIKey:(NSString *)apiKey URLSession:(NSURLSession *)URLSession;
- (void)fetchRecipesForQuery:(nullable NSString *)query
                        sort:(nullable NSString *)sort
               sortDirection:(nullable NSString *)sortDirection
                    mealType:(nullable NSString *)mealType
                      number:(NSUInteger)number
                  completion:(void (^)(NSArray<NSDictionary *> * _Nullable recipes, BOOL succeeded))completion;
- (void)fetchRecipeInformationForIdentifier:(NSString *)recipeIdentifier
                                 completion:(void (^)(NSDictionary * _Nullable recipe, BOOL succeeded))completion;

@end

@implementation MRRHomeSpoonacularAPIClient

- (instancetype)initWithAPIKey:(NSString *)apiKey URLSession:(NSURLSession *)URLSession {
  NSParameterAssert(apiKey.length > 0);
  NSParameterAssert(URLSession != nil);

  self = [super init];
  if (self) {
    _apiKey = [apiKey copy];
    _URLSession = [URLSession retain];
  }

  return self;
}

- (void)dealloc {
  [_URLSession release];
  [_apiKey release];
  [super dealloc];
}

- (void)fetchRecipesForQuery:(NSString *)query
                        sort:(NSString *)sort
               sortDirection:(NSString *)sortDirection
                    mealType:(NSString *)mealType
                      number:(NSUInteger)number
                  completion:(void (^)(NSArray<NSDictionary *> * _Nullable recipes, BOOL succeeded))completion {
  NSURLComponents *components = [NSURLComponents componentsWithString:@"https://api.spoonacular.com/recipes/complexSearch"];
  NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray arrayWithObjects:
                                                  [NSURLQueryItem queryItemWithName:@"apiKey" value:self.apiKey],
                                                  [NSURLQueryItem queryItemWithName:@"number" value:[NSString stringWithFormat:@"%lu", (unsigned long)number]],
                                                  [NSURLQueryItem queryItemWithName:@"instructionsRequired" value:@"true"],
                                                  [NSURLQueryItem queryItemWithName:@"addRecipeInformation" value:@"true"],
                                                  [NSURLQueryItem queryItemWithName:@"addRecipeInstructions" value:@"true"],
                                                  [NSURLQueryItem queryItemWithName:@"addRecipeNutrition" value:@"true"],
                                                  nil];
  if (MRRHomeTrimmedString(query).length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"query" value:MRRHomeTrimmedString(query)]];
  }
  if (MRRHomeTrimmedString(sort).length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"sort" value:MRRHomeTrimmedString(sort)]];
  }
  if (MRRHomeTrimmedString(sortDirection).length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"sortDirection" value:MRRHomeTrimmedString(sortDirection)]];
  }
  if (MRRHomeTrimmedString(mealType).length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"type" value:MRRHomeTrimmedString(mealType)]];
  }
  components.queryItems = queryItems;

  NSURL *URL = components.URL;
  if (URL == nil) {
    if (completion != nil) {
      completion(nil, NO);
    }
    return;
  }

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  request.HTTPMethod = @"GET";
  request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

  NSURLSessionDataTask *task = [self.URLSession dataTaskWithRequest:request
                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error != nil || data == nil) {
                                                      if (completion != nil) {
                                                        completion(nil, NO);
                                                      }
                                                      return;
                                                    }

                                                    NSInteger statusCode = 0;
                                                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                                                      statusCode = [(NSHTTPURLResponse *)response statusCode];
                                                    }

                                                    if (statusCode < 200 || statusCode >= 300) {
                                                      if (completion != nil) {
                                                        completion(nil, NO);
                                                      }
                                                      return;
                                                    }

                                                    NSError *JSONError = nil;
                                                    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
                                                    if (JSONError != nil || ![JSONObject isKindOfClass:[NSDictionary class]]) {
                                                      if (completion != nil) {
                                                        completion(nil, NO);
                                                      }
                                                      return;
                                                    }

                                                    id results = [(NSDictionary *)JSONObject objectForKey:@"results"];
                                                    if (![results isKindOfClass:[NSArray class]]) {
                                                      if (completion != nil) {
                                                        completion(@[], YES);
                                                      }
                                                      return;
                                                    }

                                                    if (completion != nil) {
                                                      completion((NSArray<NSDictionary *> *)results, YES);
                                                    }
                                                  }];
  [task resume];
}

- (void)fetchRecipeInformationForIdentifier:(NSString *)recipeIdentifier
                                 completion:(void (^)(NSDictionary * _Nullable recipe, BOOL succeeded))completion {
  NSString *trimmedIdentifier = MRRHomeTrimmedString(recipeIdentifier);
  if (trimmedIdentifier.length == 0) {
    if (completion != nil) {
      completion(nil, NO);
    }
    return;
  }

  NSString *URLString =
      [NSString stringWithFormat:@"https://api.spoonacular.com/recipes/%@/information?apiKey=%@&includeNutrition=true",
                                 trimmedIdentifier, self.apiKey];
  NSURL *URL = [NSURL URLWithString:URLString];
  if (URL == nil) {
    if (completion != nil) {
      completion(nil, NO);
    }
    return;
  }

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  request.HTTPMethod = @"GET";
  request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

  NSURLSessionDataTask *task = [self.URLSession dataTaskWithRequest:request
                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error != nil || data == nil) {
                                                      if (completion != nil) {
                                                        completion(nil, NO);
                                                      }
                                                      return;
                                                    }

                                                    NSInteger statusCode = 0;
                                                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                                                      statusCode = [(NSHTTPURLResponse *)response statusCode];
                                                    }

                                                    if (statusCode < 200 || statusCode >= 300) {
                                                      if (completion != nil) {
                                                        completion(nil, NO);
                                                      }
                                                      return;
                                                    }

                                                    NSError *JSONError = nil;
                                                    id JSONObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&JSONError];
                                                    if (JSONError != nil || ![JSONObject isKindOfClass:[NSDictionary class]]) {
                                                      if (completion != nil) {
                                                        completion(nil, NO);
                                                      }
                                                      return;
                                                    }

                                                    if (completion != nil) {
                                                      completion((NSDictionary *)JSONObject, YES);
                                                    }
                                                  }];
  [task resume];
}

@end

@interface HomeCompositeDataProvider ()

@property(nonatomic, copy) NSString *apiKey;
@property(nonatomic, retain, nullable) MRRHomeSpoonacularAPIClient *client;
@property(nonatomic, retain) NSURLSession *URLSession;
@property(nonatomic, retain) HomeMockDataProvider *fallbackDataProvider;
@property(nonatomic, copy) NSDictionary<NSString *, OnboardingRecipePreview *> *previewByNormalizedTitle;
@property(nonatomic, copy) NSDictionary<NSString *, OnboardingRecipePreview *> *previewByAssetName;
@property(nonatomic, copy) NSArray<HomeSection *> *cachedSections;
@property(nonatomic, copy) NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *cachedRecipesByCategoryIdentifier;
@property(nonatomic, retain) NSMutableDictionary<NSString *, OnboardingRecipeDetail *> *detailCacheByRecipeID;

- (nullable NSString *)bundleAPIKey;
- (NSDictionary<NSString *, OnboardingRecipePreview *> *)previewMapByNormalizedTitle;
- (NSDictionary<NSString *, OnboardingRecipePreview *> *)previewMapByAssetName;
- (NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *)fallbackRecipesByCategoryIdentifier;
- (NSArray<HomeSection *> *)fallbackSections;
- (NSArray<HomeRecipeCard *> *)fallbackSearchResultsForQuery:(NSString *)query limit:(NSUInteger)limit;
- (nullable OnboardingRecipePreview *)previewTemplateForTitle:(NSString *)title mealType:(NSString *)mealType;
- (NSArray<HomeRecipeCard *> *)recipeCardsFromRecipeDictionaries:(NSArray<NSDictionary *> *)recipeDictionaries preferredMealType:(nullable NSString *)preferredMealType;
- (nullable HomeRecipeCard *)recipeCardFromRecipeDictionary:(NSDictionary *)recipeDictionary preferredMealType:(nullable NSString *)preferredMealType;
- (nullable OnboardingRecipeDetail *)recipeDetailFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                                            recipeCard:(HomeRecipeCard *)recipeCard
                                                       fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSString *)mealTypeIdentifierFromRecipeDictionary:(NSDictionary *)recipeDictionary preferredMealType:(nullable NSString *)preferredMealType;
- (NSString *)assetNameForMealType:(NSString *)mealTypeIdentifier fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSString *)subtitleTextFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                      mealType:(NSString *)mealTypeIdentifier
                               fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSString *)summaryTextFromRecipeDictionary:(NSDictionary *)recipeDictionary fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSInteger)readyInMinutesFromRecipeDictionary:(NSDictionary *)recipeDictionary fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSInteger)servingsFromRecipeDictionary:(NSDictionary *)recipeDictionary fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSInteger)calorieCountFromRecipeDictionary:(NSDictionary *)recipeDictionary fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSInteger)popularityScoreFromRecipeDictionary:(NSDictionary *)recipeDictionary;
- (NSString *)sourceNameFromRecipeDictionary:(NSDictionary *)recipeDictionary
                             sourceURLString:(nullable NSString *)sourceURLString
                              fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSArray<NSString *> *)tagsFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                         mealType:(NSString *)mealTypeIdentifier
                                  fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSArray<OnboardingRecipeIngredient *> *)ingredientsFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                                          fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSArray<OnboardingRecipeInstruction *> *)instructionsFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                                            fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;
- (NSArray<NSString *> *)toolsFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                   fallbackPreview:(nullable OnboardingRecipePreview *)fallbackPreview;

@end

@implementation HomeCompositeDataProvider

- (instancetype)init {
  return [self initWithAPIKey:nil URLSession:nil fallbackDataProvider:nil];
}

- (instancetype)initWithAPIKey:(NSString *)apiKey
                    URLSession:(NSURLSession *)URLSession
          fallbackDataProvider:(HomeMockDataProvider *)fallbackDataProvider {
  self = [super init];
  if (self) {
    NSURLSession *effectiveSession = URLSession;
    if (effectiveSession == nil) {
      NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
      configuration.URLCache = nil;
      configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
      effectiveSession = [NSURLSession sessionWithConfiguration:configuration];
    }

    NSString *resolvedAPIKey = MRRHomeTrimmedString(apiKey);
    if (resolvedAPIKey.length == 0) {
      resolvedAPIKey = [self bundleAPIKey];
    }

    _URLSession = [effectiveSession retain];
    _apiKey = [resolvedAPIKey copy];
    HomeMockDataProvider *resolvedFallbackDataProvider =
        fallbackDataProvider != nil ? fallbackDataProvider : [[[HomeMockDataProvider alloc] init] autorelease];
    _fallbackDataProvider = [resolvedFallbackDataProvider retain];
    _previewByNormalizedTitle = [[self previewMapByNormalizedTitle] copy];
    _previewByAssetName = [[self previewMapByAssetName] copy];
    _detailCacheByRecipeID = [[NSMutableDictionary alloc] init];

    if (_apiKey.length > 0) {
      _client = [[MRRHomeSpoonacularAPIClient alloc] initWithAPIKey:_apiKey URLSession:_URLSession];
    }
  }

  return self;
}

- (void)dealloc {
  [_detailCacheByRecipeID release];
  [_cachedRecipesByCategoryIdentifier release];
  [_cachedSections release];
  [_previewByAssetName release];
  [_previewByNormalizedTitle release];
  [_fallbackDataProvider release];
  [_URLSession release];
  [_client release];
  [_apiKey release];
  [super dealloc];
}

- (NSArray<HomeCategory *> *)availableCategories {
  return [self.fallbackDataProvider availableCategories];
}

- (void)loadInitialSectionsForFilterOption:(HomeFilterOption)filterOption completion:(HomeInitialSectionsCompletion)completion {
  if (completion == nil) {
    return;
  }

  if (self.client == nil) {
    NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *fallbackCategories = [self fallbackRecipesByCategoryIdentifier];
    NSArray<HomeSection *> *fallbackSections = [self.fallbackDataProvider featuredSections] ?: @[];
    NSMutableArray<HomeSection *> *sortedFallbackSections = [NSMutableArray arrayWithCapacity:fallbackSections.count];
    for (HomeSection *section in fallbackSections) {
      NSArray<HomeRecipeCard *> *sortedRecipes = MRRHomeRecipesSortedForFilterOption(section.recipes ?: @[], filterOption);
      [sortedFallbackSections addObject:[[[HomeSection alloc] initWithIdentifier:section.identifier
                                                                           title:section.title
                                                                         recipes:sortedRecipes] autorelease]];
    }
    NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *sortedFallbackCategories =
        [NSMutableDictionary dictionaryWithCapacity:fallbackCategories.count];
    for (NSString *identifier in fallbackCategories) {
      NSArray<HomeRecipeCard *> *recipes = [fallbackCategories objectForKey:identifier] ?: @[];
      [sortedFallbackCategories setObject:MRRHomeRecipesSortedForFilterOption(recipes, filterOption) forKey:identifier];
    }
    self.cachedRecipesByCategoryIdentifier = sortedFallbackCategories;
    self.cachedSections = sortedFallbackSections;
    MRRHomeCompleteOnMainThread(^{
      completion(sortedFallbackSections, sortedFallbackCategories, NO);
    });
    return;
  }

  NSArray<HomeCategory *> *categories = [self availableCategories];
  NSString *recommendationSort = MRRHomeSpoonacularRecommendationSortForFilterOption(filterOption);
  NSString *weeklySort = MRRHomeSpoonacularWeeklySortForFilterOption(filterOption);
  NSString *sortDirection = MRRHomeSpoonacularSortDirectionForFilterOption(filterOption);
  NSString *recommendationSortDirection = [recommendationSort isEqualToString:@"random"] ? nil : sortDirection;
  NSString *weeklySortDirection = [weeklySort isEqualToString:@"random"] ? nil : sortDirection;
  NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *categoryResults = [NSMutableDictionary dictionaryWithCapacity:categories.count];
  NSMutableDictionary<NSString *, NSNumber *> *categorySuccessByIdentifier = [NSMutableDictionary dictionaryWithCapacity:categories.count];
  __block NSArray<HomeRecipeCard *> *recommendationRecipes = nil;
  __block NSArray<HomeRecipeCard *> *weeklyRecipes = nil;
  __block BOOL recommendationSucceeded = NO;
  __block BOOL weeklySucceeded = NO;

  dispatch_group_t requestGroup = dispatch_group_create();

  dispatch_group_enter(requestGroup);
  [self.client fetchRecipesForQuery:nil
                               sort:recommendationSort
                      sortDirection:recommendationSortDirection
                           mealType:nil
                             number:MRRHomeLiveRailRecipeCount
                         completion:^(NSArray<NSDictionary *> *recipes, BOOL succeeded) {
                           NSArray<HomeRecipeCard *> *mappedRecipes = succeeded ? [self recipeCardsFromRecipeDictionaries:recipes preferredMealType:nil] : nil;
                           @synchronized(self) {
                             recommendationSucceeded = succeeded;
                             recommendationRecipes = [mappedRecipes copy];
                           }
                           dispatch_group_leave(requestGroup);
                         }];

  dispatch_group_enter(requestGroup);
  [self.client fetchRecipesForQuery:nil
                               sort:weeklySort
                      sortDirection:weeklySortDirection
                           mealType:nil
                             number:MRRHomeLiveRailRecipeCount
                         completion:^(NSArray<NSDictionary *> *recipes, BOOL succeeded) {
                           NSArray<HomeRecipeCard *> *mappedRecipes = succeeded ? [self recipeCardsFromRecipeDictionaries:recipes preferredMealType:nil] : nil;
                           @synchronized(self) {
                             weeklySucceeded = succeeded;
                             weeklyRecipes = [mappedRecipes copy];
                           }
                           dispatch_group_leave(requestGroup);
                         }];

  for (HomeCategory *category in categories) {
    dispatch_group_enter(requestGroup);
    [self.client fetchRecipesForQuery:nil
                                 sort:recommendationSort
                        sortDirection:recommendationSortDirection
                             mealType:category.identifier
                               number:MRRHomeLiveRailRecipeCount
                           completion:^(NSArray<NSDictionary *> *recipes, BOOL succeeded) {
                             NSArray<HomeRecipeCard *> *mappedRecipes = succeeded ? [self recipeCardsFromRecipeDictionaries:recipes preferredMealType:category.identifier] : nil;
                             @synchronized(self) {
                               if (mappedRecipes != nil) {
                                 [categoryResults setObject:mappedRecipes forKey:category.identifier];
                               }
                               [categorySuccessByIdentifier setObject:@(succeeded) forKey:category.identifier];
                             }
                             dispatch_group_leave(requestGroup);
                           }];
  }

  dispatch_group_notify(requestGroup, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSArray<HomeSection *> *fallbackSections = [self fallbackSections];
    NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *fallbackCategories = [self fallbackRecipesByCategoryIdentifier];

    NSArray<HomeRecipeCard *> *resolvedRecommendationRecipes =
        recommendationSucceeded ? (recommendationRecipes ?: @[]) : [[[self.fallbackDataProvider featuredSections] firstObject] recipes];
    NSArray<HomeRecipeCard *> *resolvedWeeklyRecipes =
        weeklySucceeded ? (weeklyRecipes ?: @[]) : [[[self.fallbackDataProvider featuredSections] lastObject] recipes];

    NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *resolvedCategories =
        [NSMutableDictionary dictionaryWithDictionary:fallbackCategories];
    for (HomeCategory *category in categories) {
      NSNumber *successValue = [categorySuccessByIdentifier objectForKey:category.identifier];
      if (successValue.boolValue) {
        [resolvedCategories setObject:([categoryResults objectForKey:category.identifier] ?: @[]) forKey:category.identifier];
      }
    }

    NSArray<HomeSection *> *resolvedSections = @[
      [[[HomeSection alloc] initWithIdentifier:HomeSectionIdentifierRecommendation
                                         title:@"Recommendation"
                                       recipes:resolvedRecommendationRecipes ?: @[]] autorelease],
      [[[HomeSection alloc] initWithIdentifier:HomeSectionIdentifierWeekly
                                         title:@"Recipes Of The Week"
                                       recipes:resolvedWeeklyRecipes ?: @[]] autorelease]
    ];

    BOOL usesLiveData = recommendationSucceeded || weeklySucceeded;
    for (NSNumber *successValue in [categorySuccessByIdentifier allValues]) {
      usesLiveData = usesLiveData || successValue.boolValue;
    }

    self.cachedSections = resolvedSections;
    self.cachedRecipesByCategoryIdentifier = resolvedCategories;

    MRRHomeCompleteOnMainThread(^{
      completion(resolvedSections, resolvedCategories, usesLiveData);
    });

    [recommendationRecipes release];
    [weeklyRecipes release];
    (void)fallbackSections;
  });
}

- (void)searchRecipes:(NSString *)query
                limit:(NSUInteger)limit
         filterOption:(HomeFilterOption)filterOption
           completion:(HomeRecipeSearchCompletion)completion {
  if (completion == nil) {
    return;
  }

  NSString *trimmedQuery = MRRHomeTrimmedString(query);
  if (trimmedQuery.length == 0) {
    MRRHomeCompleteOnMainThread(^{
      completion(@[], NO);
    });
    return;
  }

  NSUInteger requestedLimit = limit > 0 ? limit : MRRHomeFallbackSearchResultLimit;
  if (self.client == nil) {
    NSArray<HomeRecipeCard *> *fallbackRecipes =
        MRRHomeRecipesSortedForFilterOption([self fallbackSearchResultsForQuery:trimmedQuery limit:0], filterOption);
    fallbackRecipes = MRRHomeLimitedRecipeCards(fallbackRecipes, requestedLimit);
    MRRHomeCompleteOnMainThread(^{
      completion(fallbackRecipes, NO);
    });
    return;
  }

  NSString *sort = MRRHomeSpoonacularSearchSortForFilterOption(filterOption);
  NSString *sortDirection = MRRHomeSpoonacularSortDirectionForFilterOption(filterOption);
  [self.client fetchRecipesForQuery:trimmedQuery
                               sort:sort
                      sortDirection:sortDirection
                           mealType:nil
                             number:requestedLimit
                         completion:^(NSArray<NSDictionary *> *recipes, BOOL succeeded) {
                           if (succeeded) {
                             NSArray<HomeRecipeCard *> *mappedRecipes = [self recipeCardsFromRecipeDictionaries:recipes preferredMealType:nil];
                             MRRHomeCompleteOnMainThread(^{
                               completion(mappedRecipes ?: @[], YES);
                             });
                             return;
                           }

                           NSArray<HomeRecipeCard *> *fallbackRecipes =
                               MRRHomeRecipesSortedForFilterOption([self fallbackSearchResultsForQuery:trimmedQuery limit:0], filterOption);
                           fallbackRecipes = MRRHomeLimitedRecipeCards(fallbackRecipes, requestedLimit);
                           MRRHomeCompleteOnMainThread(^{
                             completion(fallbackRecipes, NO);
                           });
                         }];
}

- (void)loadRecipeDetailForRecipeCard:(HomeRecipeCard *)recipeCard completion:(HomeRecipeDetailCompletion)completion {
  if (completion == nil || recipeCard == nil) {
    return;
  }

  OnboardingRecipeDetail *cachedDetail = nil;
  @synchronized(self) {
    cachedDetail = [[self.detailCacheByRecipeID objectForKey:recipeCard.recipeID] retain];
  }
  if (cachedDetail != nil) {
    MRRHomeCompleteOnMainThread(^{
      completion([cachedDetail autorelease], YES);
    });
    return;
  }

  BOOL looksLikeLiveRecipe = [recipeCard.recipeID rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound;
  if (!looksLikeLiveRecipe) {
    OnboardingRecipeDetail *fallbackDetail = [self.fallbackDataProvider recipeDetailForID:recipeCard.recipeID];
    MRRHomeCompleteOnMainThread(^{
      completion(fallbackDetail, NO);
    });
    return;
  }

  if (self.client == nil) {
    MRRHomeCompleteOnMainThread(^{
      completion(nil, NO);
    });
    return;
  }

  [self.client fetchRecipeInformationForIdentifier:recipeCard.recipeID
                                        completion:^(NSDictionary *recipeDictionary, BOOL succeeded) {
                                          if (!succeeded || recipeDictionary == nil) {
                                            MRRHomeCompleteOnMainThread(^{
                                              completion(nil, NO);
                                            });
                                            return;
                                          }

                                          OnboardingRecipePreview *fallbackPreview =
                                              [self previewTemplateForTitle:recipeCard.title mealType:recipeCard.mealType];
                                          OnboardingRecipeDetail *detail =
                                              [self recipeDetailFromRecipeDictionary:recipeDictionary
                                                                          recipeCard:recipeCard
                                                                     fallbackPreview:fallbackPreview];
                                          if (detail != nil) {
                                            @synchronized(self) {
                                              [self.detailCacheByRecipeID setObject:detail forKey:recipeCard.recipeID];
                                            }
                                          }

                                          MRRHomeCompleteOnMainThread(^{
                                            completion(detail, detail != nil);
                                          });
                                        }];
}

- (NSString *)bundleAPIKey {
  NSArray<NSBundle *> *candidateBundles = @[ [NSBundle mainBundle], [NSBundle bundleForClass:[self class]] ];
  for (NSBundle *bundle in candidateBundles) {
    NSString *path = [bundle pathForResource:@"RecipeAPIConfig" ofType:@"plist"];
    if (path.length == 0) {
      continue;
    }

    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:path];
    NSString *APIKey = MRRHomeTrimmedString([configuration objectForKey:@"SpoonacularAPIKey"]);
    if (APIKey.length > 0) {
      return APIKey;
    }
  }

  return nil;
}

- (NSDictionary<NSString *, OnboardingRecipePreview *> *)previewMapByNormalizedTitle {
  OnboardingRecipeCatalog *catalog = [[[OnboardingRecipeCatalog alloc] init] autorelease];
  NSMutableDictionary<NSString *, OnboardingRecipePreview *> *previewsByNormalizedTitle = [NSMutableDictionary dictionary];
  for (OnboardingRecipePreview *preview in [catalog allRecipePreviews]) {
    NSString *key = MRRHomeNormalizedKey(preview.title);
    if (key.length > 0) {
      [previewsByNormalizedTitle setObject:preview forKey:key];
    }
  }
  return previewsByNormalizedTitle;
}

- (NSDictionary<NSString *, OnboardingRecipePreview *> *)previewMapByAssetName {
  OnboardingRecipeCatalog *catalog = [[[OnboardingRecipeCatalog alloc] init] autorelease];
  NSMutableDictionary<NSString *, OnboardingRecipePreview *> *previewsByAssetName = [NSMutableDictionary dictionary];
  for (OnboardingRecipePreview *preview in [catalog allRecipePreviews]) {
    if (preview.assetName.length > 0) {
      [previewsByAssetName setObject:preview forKey:preview.assetName];
    }
  }
  return previewsByAssetName;
}

- (NSDictionary<NSString *, NSArray<HomeRecipeCard *> *> *)fallbackRecipesByCategoryIdentifier {
  NSMutableDictionary<NSString *, NSArray<HomeRecipeCard *> *> *recipesByCategoryIdentifier = [NSMutableDictionary dictionary];
  for (HomeCategory *category in [self availableCategories]) {
    NSArray<HomeRecipeCard *> *recipes = [self.fallbackDataProvider recipesForCategory:category] ?: @[];
    [recipesByCategoryIdentifier setObject:recipes forKey:category.identifier];
  }
  return recipesByCategoryIdentifier;
}

- (NSArray<HomeSection *> *)fallbackSections {
  return [self.fallbackDataProvider featuredSections] ?: @[];
}

- (NSArray<HomeRecipeCard *> *)fallbackSearchResultsForQuery:(NSString *)query limit:(NSUInteger)limit {
  NSArray<HomeRecipeCard *> *recipes = [self.fallbackDataProvider searchRecipes:query] ?: @[];
  return MRRHomeLimitedRecipeCards(recipes, limit > 0 ? limit : MRRHomeFallbackSearchResultLimit);
}

- (OnboardingRecipePreview *)previewTemplateForTitle:(NSString *)title mealType:(NSString *)mealType {
  OnboardingRecipePreview *preview = [self.previewByNormalizedTitle objectForKey:MRRHomeNormalizedKey(title)];
  if (preview != nil) {
    return preview;
  }

  preview = [self.previewByAssetName objectForKey:[self assetNameForMealType:mealType fallbackPreview:nil]];
  if (preview != nil) {
    return preview;
  }

  return [[self.previewByAssetName allValues] firstObject];
}

- (NSArray<HomeRecipeCard *> *)recipeCardsFromRecipeDictionaries:(NSArray<NSDictionary *> *)recipeDictionaries preferredMealType:(NSString *)preferredMealType {
  NSMutableArray<HomeRecipeCard *> *recipeCards = [NSMutableArray arrayWithCapacity:recipeDictionaries.count];
  for (NSDictionary *recipeDictionary in recipeDictionaries) {
    HomeRecipeCard *recipeCard = [self recipeCardFromRecipeDictionary:recipeDictionary preferredMealType:preferredMealType];
    if (recipeCard != nil) {
      [recipeCards addObject:recipeCard];
    }
  }
  return recipeCards;
}

- (HomeRecipeCard *)recipeCardFromRecipeDictionary:(NSDictionary *)recipeDictionary preferredMealType:(NSString *)preferredMealType {
  NSString *title = MRRHomeTrimmedString([recipeDictionary objectForKey:@"title"]);
  NSNumber *identifierNumber = [recipeDictionary objectForKey:@"id"];
  if (title.length == 0 || ![identifierNumber respondsToSelector:@selector(stringValue)]) {
    return nil;
  }

  NSString *recipeIdentifier = MRRHomeTrimmedString([identifierNumber stringValue]);
  if (recipeIdentifier.length == 0) {
    return nil;
  }

  NSString *mealTypeIdentifier = [self mealTypeIdentifierFromRecipeDictionary:recipeDictionary preferredMealType:preferredMealType];
  OnboardingRecipePreview *fallbackPreview = [self previewTemplateForTitle:title mealType:mealTypeIdentifier];
  NSString *assetName = [self assetNameForMealType:mealTypeIdentifier fallbackPreview:fallbackPreview];
  NSString *sourceURLString = MRRHomeTrimmedString([recipeDictionary objectForKey:@"sourceUrl"]);
  NSString *sourceName = [self sourceNameFromRecipeDictionary:recipeDictionary sourceURLString:sourceURLString fallbackPreview:fallbackPreview];
  NSArray<NSString *> *tags = [self tagsFromRecipeDictionary:recipeDictionary mealType:mealTypeIdentifier fallbackPreview:fallbackPreview];
  NSString *subtitle = [self subtitleTextFromRecipeDictionary:recipeDictionary mealType:mealTypeIdentifier fallbackPreview:fallbackPreview];
  NSString *summaryText = [self summaryTextFromRecipeDictionary:recipeDictionary fallbackPreview:fallbackPreview];

  HomeRecipeCard *recipeCard = [[[HomeRecipeCard alloc] initWithRecipeID:recipeIdentifier
                                                                   title:title
                                                                subtitle:subtitle
                                                               assetName:assetName
                                                          imageURLString:MRRHomeTrimmedString([recipeDictionary objectForKey:@"image"])
                                                             summaryText:summaryText
                                                          readyInMinutes:[self readyInMinutesFromRecipeDictionary:recipeDictionary fallbackPreview:fallbackPreview]
                                                                servings:[self servingsFromRecipeDictionary:recipeDictionary fallbackPreview:fallbackPreview]
                                                            calorieCount:[self calorieCountFromRecipeDictionary:recipeDictionary fallbackPreview:fallbackPreview]
                                                         popularityScore:[self popularityScoreFromRecipeDictionary:recipeDictionary]
                                                              sourceName:sourceName
                                                         sourceURLString:sourceURLString
                                                                mealType:mealTypeIdentifier
                                                                    tags:tags] autorelease];

  OnboardingRecipeDetail *seedDetail =
      [self recipeDetailFromRecipeDictionary:recipeDictionary recipeCard:recipeCard fallbackPreview:fallbackPreview];
  if (seedDetail != nil) {
    @synchronized(self) {
      [self.detailCacheByRecipeID setObject:seedDetail forKey:recipeIdentifier];
    }
  }

  return recipeCard;
}

- (OnboardingRecipeDetail *)recipeDetailFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                                   recipeCard:(HomeRecipeCard *)recipeCard
                                              fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  OnboardingRecipeDetail *fallbackDetail = fallbackPreview.fallbackDetail;
  NSArray<OnboardingRecipeIngredient *> *ingredients = [self ingredientsFromRecipeDictionary:recipeDictionary fallbackPreview:fallbackPreview];
  NSArray<OnboardingRecipeInstruction *> *instructions = [self instructionsFromRecipeDictionary:recipeDictionary fallbackPreview:fallbackPreview];
  NSArray<NSString *> *tools = [self toolsFromRecipeDictionary:recipeDictionary fallbackPreview:fallbackPreview];
  NSArray<NSString *> *tags = recipeCard.tags.count > 0 ? recipeCard.tags : (fallbackDetail.tags ?: @[]);

  NSString *summaryText = recipeCard.summaryText.length > 0 ? recipeCard.summaryText : (fallbackDetail.summaryText ?: @"Recipe summary coming soon.");
  NSString *durationText = recipeCard.readyInMinutes > 0 ? [recipeCard durationText] : (fallbackDetail.durationText ?: @"30 min");
  NSString *calorieText = recipeCard.calorieCount > 0 ? [recipeCard calorieText] : (fallbackDetail.calorieText ?: @"Calories vary");
  NSString *servingsText = recipeCard.servings > 0 ? [recipeCard servingsText] : (fallbackDetail.servingsText ?: @"2 servings");

  return [[[OnboardingRecipeDetail alloc] initWithTitle:recipeCard.title
                                               subtitle:recipeCard.subtitle
                                              assetName:recipeCard.assetName
                                     heroImageURLString:recipeCard.imageURLString
                                           durationText:durationText
                                            calorieText:calorieText
                                           servingsText:servingsText
                                            summaryText:summaryText
                                            ingredients:ingredients
                                           instructions:instructions
                                                  tools:tools
                                                   tags:tags
                                             sourceName:recipeCard.sourceName
                                        sourceURLString:recipeCard.sourceURLString
                                         productContext:nil] autorelease];
}

- (NSString *)mealTypeIdentifierFromRecipeDictionary:(NSDictionary *)recipeDictionary preferredMealType:(NSString *)preferredMealType {
  NSString *trimmedPreferredMealType = MRRHomeTrimmedString(preferredMealType);
  if (trimmedPreferredMealType.length > 0) {
    return trimmedPreferredMealType;
  }

  NSArray<NSString *> *dishTypes = MRRHomeStringArrayFromJSONArray([recipeDictionary objectForKey:@"dishTypes"]);
  for (NSString *dishType in dishTypes) {
    NSString *lowercasedDishType = [dishType lowercaseString];
    if ([lowercasedDishType containsString:HomeCategoryIdentifierBreakfast]) {
      return HomeCategoryIdentifierBreakfast;
    }
    if ([lowercasedDishType containsString:HomeCategoryIdentifierLunch]) {
      return HomeCategoryIdentifierLunch;
    }
    if ([lowercasedDishType containsString:HomeCategoryIdentifierDinner]) {
      return HomeCategoryIdentifierDinner;
    }
    if ([lowercasedDishType containsString:HomeCategoryIdentifierDessert]) {
      return HomeCategoryIdentifierDessert;
    }
    if ([lowercasedDishType containsString:HomeCategoryIdentifierSnack]) {
      return HomeCategoryIdentifierSnack;
    }
  }

  return HomeCategoryIdentifierSnack;
}

- (NSString *)assetNameForMealType:(NSString *)mealTypeIdentifier fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  if (fallbackPreview.assetName.length > 0) {
    return fallbackPreview.assetName;
  }

  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierBreakfast]) {
    return @"avocado-toast";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierLunch]) {
    return @"greek-salad";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierDinner]) {
    return @"salmon";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierDessert]) {
    return @"pizza";
  }
  if ([mealTypeIdentifier isEqualToString:HomeCategoryIdentifierSnack]) {
    return @"ramen";
  }
  return @"avocado-toast";
}

- (NSString *)subtitleTextFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                      mealType:(NSString *)mealTypeIdentifier
                               fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSArray<NSString *> *cuisines = MRRHomeStringArrayFromJSONArray([recipeDictionary objectForKey:@"cuisines"]);
  NSArray<NSString *> *diets = MRRHomeStringArrayFromJSONArray([recipeDictionary objectForKey:@"diets"]);
  NSString *mealTypeDisplayName = MRRHomeMealTypeDisplayName(mealTypeIdentifier);
  if (cuisines.count > 0) {
    return [NSString stringWithFormat:@"%@ %@ pick", cuisines.firstObject, [mealTypeDisplayName lowercaseString]];
  }
  if (diets.count > 0) {
    return diets.firstObject;
  }
  if (fallbackPreview.subtitle.length > 0) {
    return fallbackPreview.subtitle;
  }
  return [NSString stringWithFormat:@"%@ highlight", mealTypeDisplayName];
}

- (NSString *)summaryTextFromRecipeDictionary:(NSDictionary *)recipeDictionary fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSString *summaryText = MRRHomeDecodedHTMLString([recipeDictionary objectForKey:@"summary"]);
  if (summaryText.length > 0) {
    return summaryText;
  }

  if (fallbackPreview.fallbackDetail.summaryText.length > 0) {
    return fallbackPreview.fallbackDetail.summaryText;
  }

  return @"Fresh live recipe inspiration from Spoonacular.";
}

- (NSInteger)readyInMinutesFromRecipeDictionary:(NSDictionary *)recipeDictionary fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSNumber *readyInMinutesNumber = [recipeDictionary objectForKey:@"readyInMinutes"];
  if ([readyInMinutesNumber respondsToSelector:@selector(integerValue)] && readyInMinutesNumber.integerValue > 0) {
    return readyInMinutesNumber.integerValue;
  }

  NSInteger fallbackValue = MRRHomeFirstIntegerFromString(fallbackPreview.fallbackDetail.durationText);
  return fallbackValue > 0 ? fallbackValue : 20;
}

- (NSInteger)servingsFromRecipeDictionary:(NSDictionary *)recipeDictionary fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSNumber *servingsNumber = [recipeDictionary objectForKey:@"servings"];
  if ([servingsNumber respondsToSelector:@selector(integerValue)] && servingsNumber.integerValue > 0) {
    return servingsNumber.integerValue;
  }

  NSInteger fallbackValue = MRRHomeFirstIntegerFromString(fallbackPreview.fallbackDetail.servingsText);
  return fallbackValue > 0 ? fallbackValue : 2;
}

- (NSInteger)calorieCountFromRecipeDictionary:(NSDictionary *)recipeDictionary fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSDictionary *nutritionDictionary = [recipeDictionary objectForKey:@"nutrition"];
  if ([nutritionDictionary isKindOfClass:[NSDictionary class]]) {
    NSArray<NSDictionary *> *nutrients = [nutritionDictionary objectForKey:@"nutrients"];
    if ([nutrients isKindOfClass:[NSArray class]]) {
      for (NSDictionary *nutrient in nutrients) {
        NSString *name = [MRRHomeTrimmedString([nutrient objectForKey:@"name"]) lowercaseString];
        if ([name containsString:@"calories"]) {
          NSNumber *amountNumber = [nutrient objectForKey:@"amount"];
          if ([amountNumber respondsToSelector:@selector(doubleValue)]) {
            return (NSInteger)llround(amountNumber.doubleValue);
          }
        }
      }
    }
  }

  NSInteger fallbackValue = MRRHomeFirstIntegerFromString(fallbackPreview.fallbackDetail.calorieText);
  return MAX(fallbackValue, 0);
}

- (NSInteger)popularityScoreFromRecipeDictionary:(NSDictionary *)recipeDictionary {
  NSNumber *aggregateLikesNumber = [recipeDictionary objectForKey:@"aggregateLikes"];
  if ([aggregateLikesNumber respondsToSelector:@selector(integerValue)] && aggregateLikesNumber.integerValue > 0) {
    return aggregateLikesNumber.integerValue;
  }

  NSNumber *scoreNumber = [recipeDictionary objectForKey:@"spoonacularScore"];
  if ([scoreNumber respondsToSelector:@selector(integerValue)]) {
    return scoreNumber.integerValue;
  }

  return 0;
}

- (NSString *)sourceNameFromRecipeDictionary:(NSDictionary *)recipeDictionary
                             sourceURLString:(NSString *)sourceURLString
                              fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSString *sourceName = MRRHomeTrimmedString([recipeDictionary objectForKey:@"sourceName"]);
  if (sourceName.length > 0) {
    return sourceName;
  }

  if (sourceURLString.length > 0) {
    NSURL *sourceURL = [NSURL URLWithString:sourceURLString];
    NSString *host = MRRHomeTrimmedString(sourceURL.host);
    if (host.length > 0) {
      return host;
    }
  }

  if (fallbackPreview.fallbackDetail.sourceName.length > 0) {
    return fallbackPreview.fallbackDetail.sourceName;
  }

  return @"Spoonacular";
}

- (NSArray<NSString *> *)tagsFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                         mealType:(NSString *)mealTypeIdentifier
                                  fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSMutableOrderedSet<NSString *> *tagSet = [NSMutableOrderedSet orderedSet];
  NSArray<NSString *> *dishTypes = MRRHomeStringArrayFromJSONArray([recipeDictionary objectForKey:@"dishTypes"]);
  NSArray<NSString *> *cuisines = MRRHomeStringArrayFromJSONArray([recipeDictionary objectForKey:@"cuisines"]);
  NSArray<NSString *> *diets = MRRHomeStringArrayFromJSONArray([recipeDictionary objectForKey:@"diets"]);

  [tagSet addObjectsFromArray:dishTypes];
  [tagSet addObjectsFromArray:cuisines];
  [tagSet addObjectsFromArray:diets];

  NSInteger readyInMinutes = [self readyInMinutesFromRecipeDictionary:recipeDictionary fallbackPreview:fallbackPreview];
  if (readyInMinutes > 0 && readyInMinutes <= 20) {
    [tagSet addObject:@"Quick"];
  }

  if (tagSet.count == 0 && fallbackPreview.fallbackDetail.tags.count > 0) {
    [tagSet addObjectsFromArray:fallbackPreview.fallbackDetail.tags];
  }
  if (tagSet.count == 0) {
    [tagSet addObject:MRRHomeMealTypeDisplayName(mealTypeIdentifier)];
  }

  return [tagSet array];
}

- (NSArray<OnboardingRecipeIngredient *> *)ingredientsFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                                          fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSArray<NSDictionary *> *extendedIngredients = [recipeDictionary objectForKey:@"extendedIngredients"];
  NSMutableArray<OnboardingRecipeIngredient *> *ingredients = [NSMutableArray array];
  if ([extendedIngredients isKindOfClass:[NSArray class]]) {
    for (NSDictionary *ingredientDictionary in extendedIngredients) {
      NSString *name = MRRHomeTrimmedString([ingredientDictionary objectForKey:@"name"]);
      NSString *displayText = MRRHomeTrimmedString([ingredientDictionary objectForKey:@"original"]);
      if (name.length == 0) {
        name = displayText;
      }
      if (displayText.length == 0) {
        displayText = name;
      }
      if (name.length == 0 || displayText.length == 0) {
        continue;
      }

      OnboardingRecipeIngredient *ingredient =
          [[[OnboardingRecipeIngredient alloc] initWithName:name displayText:displayText] autorelease];
      [ingredients addObject:ingredient];
    }
  }

  if (ingredients.count > 0) {
    return ingredients;
  }

  if (fallbackPreview.fallbackDetail.ingredients.count > 0) {
    return fallbackPreview.fallbackDetail.ingredients;
  }

  OnboardingRecipeIngredient *placeholderIngredient =
      [[[OnboardingRecipeIngredient alloc] initWithName:@"Ingredients"
                                            displayText:@"See the recipe source for the latest ingredient list."] autorelease];
  return @[ placeholderIngredient ];
}

- (NSArray<OnboardingRecipeInstruction *> *)instructionsFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                                            fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSArray<NSDictionary *> *analyzedInstructions = [recipeDictionary objectForKey:@"analyzedInstructions"];
  NSMutableArray<OnboardingRecipeInstruction *> *instructions = [NSMutableArray array];

  if ([analyzedInstructions isKindOfClass:[NSArray class]]) {
    for (NSDictionary *instructionGroup in analyzedInstructions) {
      NSArray<NSDictionary *> *steps = [instructionGroup objectForKey:@"steps"];
      if (![steps isKindOfClass:[NSArray class]]) {
        continue;
      }

      for (NSDictionary *stepDictionary in steps) {
        NSNumber *number = [stepDictionary objectForKey:@"number"];
        NSString *stepText = MRRHomeDecodedHTMLString([stepDictionary objectForKey:@"step"]);
        if (stepText.length == 0) {
          continue;
        }

        NSString *title = number != nil ? [NSString stringWithFormat:@"Step %@", number] : @"Step";
        OnboardingRecipeInstruction *instruction =
            [[[OnboardingRecipeInstruction alloc] initWithTitle:title detailText:stepText] autorelease];
        [instructions addObject:instruction];
      }
    }
  }

  if (instructions.count == 0) {
    NSString *instructionText = MRRHomeDecodedHTMLString([recipeDictionary objectForKey:@"instructions"]);
    if (instructionText.length > 0) {
      NSArray<NSString *> *components = [instructionText componentsSeparatedByString:@"."];
      NSUInteger stepIndex = 1;
      for (NSString *component in components) {
        NSString *stepText = MRRHomeTrimmedString(component);
        if (stepText.length == 0) {
          continue;
        }

        NSString *title = [NSString stringWithFormat:@"Step %lu", (unsigned long)stepIndex];
        OnboardingRecipeInstruction *instruction =
            [[[OnboardingRecipeInstruction alloc] initWithTitle:title detailText:stepText] autorelease];
        [instructions addObject:instruction];
        stepIndex += 1;
      }
    }
  }

  if (instructions.count > 0) {
    return instructions;
  }

  if (fallbackPreview.fallbackDetail.instructions.count > 0) {
    return fallbackPreview.fallbackDetail.instructions;
  }

  OnboardingRecipeInstruction *placeholderInstruction =
      [[[OnboardingRecipeInstruction alloc] initWithTitle:@"Step 1"
                                               detailText:@"Open the source recipe to view the latest preparation steps."] autorelease];
  return @[ placeholderInstruction ];
}

- (NSArray<NSString *> *)toolsFromRecipeDictionary:(NSDictionary *)recipeDictionary
                                   fallbackPreview:(OnboardingRecipePreview *)fallbackPreview {
  NSArray<NSDictionary *> *analyzedInstructions = [recipeDictionary objectForKey:@"analyzedInstructions"];
  NSMutableOrderedSet<NSString *> *toolSet = [NSMutableOrderedSet orderedSet];
  if ([analyzedInstructions isKindOfClass:[NSArray class]]) {
    for (NSDictionary *instructionGroup in analyzedInstructions) {
      NSArray<NSDictionary *> *steps = [instructionGroup objectForKey:@"steps"];
      if (![steps isKindOfClass:[NSArray class]]) {
        continue;
      }

      for (NSDictionary *stepDictionary in steps) {
        NSArray<NSDictionary *> *equipment = [stepDictionary objectForKey:@"equipment"];
        if (![equipment isKindOfClass:[NSArray class]]) {
          continue;
        }

        for (NSDictionary *equipmentDictionary in equipment) {
          NSString *name = MRRHomeTrimmedString([equipmentDictionary objectForKey:@"name"]);
          if (name.length > 0) {
            [toolSet addObject:name];
          }
        }
      }
    }
  }

  if (toolSet.count > 0) {
    return [toolSet array];
  }

  return fallbackPreview.fallbackDetail.tools ?: @[];
}

@end
