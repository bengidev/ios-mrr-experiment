#import "MRRSavedRecipeSnapshot.h"

#import "../../../Features/Onboarding/Data/OnboardingRecipeModels.h"

NSString *const MRRSavedRecipeMealTypeBreakfast = @"breakfast";
NSString *const MRRSavedRecipeMealTypeLunch = @"lunch";
NSString *const MRRSavedRecipeMealTypeDinner = @"dinner";
NSString *const MRRSavedRecipeMealTypeDessert = @"dessert";
NSString *const MRRSavedRecipeMealTypeSnack = @"snack";

static NSString *MRRTrimmedSavedRecipeString(NSString *string) {
  return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *MRRResolvedSavedRecipeMealType(NSString *mealType) {
  NSString *trimmedMealType = [[MRRTrimmedSavedRecipeString(mealType) lowercaseString] copy];
  if (trimmedMealType.length == 0) {
    [trimmedMealType release];
    return [MRRSavedRecipeMealTypeSnack retain];
  }
  if ([trimmedMealType isEqualToString:MRRSavedRecipeMealTypeBreakfast] || [trimmedMealType isEqualToString:MRRSavedRecipeMealTypeLunch] ||
      [trimmedMealType isEqualToString:MRRSavedRecipeMealTypeDinner] || [trimmedMealType isEqualToString:MRRSavedRecipeMealTypeDessert] ||
      [trimmedMealType isEqualToString:MRRSavedRecipeMealTypeSnack]) {
    return trimmedMealType;
  }
  [trimmedMealType release];
  return [MRRSavedRecipeMealTypeSnack retain];
}

static NSArray<MRRSavedRecipeIngredientSnapshot *> *MRRSavedRecipeIngredientSnapshotsFromDetail(OnboardingRecipeDetail *recipeDetail) {
  NSMutableArray<MRRSavedRecipeIngredientSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (OnboardingRecipeIngredient *ingredient in recipeDetail.ingredients ?: @[]) {
    NSString *name = ingredient.name.length > 0 ? ingredient.name : ingredient.displayText;
    NSString *displayText = ingredient.displayText.length > 0 ? ingredient.displayText : ingredient.name;
    if (displayText.length == 0) {
      continue;
    }
    MRRSavedRecipeIngredientSnapshot *snapshot = [[[MRRSavedRecipeIngredientSnapshot alloc] initWithName:name ?: displayText
                                                                                             displayText:displayText
                                                                                              orderIndex:(NSInteger)orderIndex] autorelease];
    [snapshots addObject:snapshot];
    orderIndex += 1;
  }
  return snapshots;
}

static NSArray<MRRSavedRecipeInstructionSnapshot *> *MRRSavedRecipeInstructionSnapshotsFromDetail(OnboardingRecipeDetail *recipeDetail) {
  NSMutableArray<MRRSavedRecipeInstructionSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (OnboardingRecipeInstruction *instruction in recipeDetail.instructions ?: @[]) {
    if (instruction.detailText.length == 0 && instruction.title.length == 0) {
      continue;
    }
    MRRSavedRecipeInstructionSnapshot *snapshot = [[[MRRSavedRecipeInstructionSnapshot alloc] initWithTitle:instruction.title ?: @""
                                                                                                 detailText:instruction.detailText ?: @""
                                                                                                 orderIndex:(NSInteger)orderIndex] autorelease];
    [snapshots addObject:snapshot];
    orderIndex += 1;
  }
  return snapshots;
}

static NSArray<MRRSavedRecipeStringSnapshot *> *MRRSavedRecipeStringSnapshotsFromValues(NSArray<NSString *> *values) {
  NSMutableArray<MRRSavedRecipeStringSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (NSString *value in values ?: @[]) {
    NSString *trimmedValue = MRRTrimmedSavedRecipeString(value ?: @"");
    if (trimmedValue.length == 0) {
      continue;
    }
    MRRSavedRecipeStringSnapshot *snapshot = [[[MRRSavedRecipeStringSnapshot alloc] initWithValue:trimmedValue
                                                                                       orderIndex:(NSInteger)orderIndex] autorelease];
    [snapshots addObject:snapshot];
    orderIndex += 1;
  }
  return snapshots;
}

static MRRSavedRecipeProductContextSnapshot *MRRSavedRecipeProductContextSnapshotFromDetail(OnboardingRecipeDetail *recipeDetail) {
  OnboardingRecipeProductContext *productContext = recipeDetail.productContext;
  if (productContext == nil || productContext.productName.length == 0) {
    return nil;
  }
  return [[[MRRSavedRecipeProductContextSnapshot alloc] initWithProductName:productContext.productName
                                                                  brandText:productContext.brandText
                                                         nutritionGradeText:productContext.nutritionGradeText
                                                               quantityText:productContext.quantityText] autorelease];
}

@interface MRRSavedRecipeIngredientSnapshot ()

@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, copy, readwrite) NSString *displayText;
@property(nonatomic, assign, readwrite) NSInteger orderIndex;

@end

@implementation MRRSavedRecipeIngredientSnapshot

- (instancetype)initWithName:(NSString *)name displayText:(NSString *)displayText orderIndex:(NSInteger)orderIndex {
  NSParameterAssert(name.length > 0);
  NSParameterAssert(displayText.length > 0);

  self = [super init];
  if (self) {
    _name = [name copy];
    _displayText = [displayText copy];
    _orderIndex = orderIndex;
  }
  return self;
}

- (void)dealloc {
  [_displayText release];
  [_name release];
  [super dealloc];
}

@end

@interface MRRSavedRecipeInstructionSnapshot ()

@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *detailText;
@property(nonatomic, assign, readwrite) NSInteger orderIndex;

@end

@implementation MRRSavedRecipeInstructionSnapshot

- (instancetype)initWithTitle:(NSString *)title detailText:(NSString *)detailText orderIndex:(NSInteger)orderIndex {
  NSParameterAssert(title != nil);
  NSParameterAssert(detailText != nil);

  self = [super init];
  if (self) {
    _title = [title copy];
    _detailText = [detailText copy];
    _orderIndex = orderIndex;
  }
  return self;
}

- (void)dealloc {
  [_detailText release];
  [_title release];
  [super dealloc];
}

@end

@interface MRRSavedRecipeStringSnapshot ()

@property(nonatomic, copy, readwrite) NSString *value;
@property(nonatomic, assign, readwrite) NSInteger orderIndex;

@end

@implementation MRRSavedRecipeStringSnapshot

- (instancetype)initWithValue:(NSString *)value orderIndex:(NSInteger)orderIndex {
  NSParameterAssert(value.length > 0);

  self = [super init];
  if (self) {
    _value = [value copy];
    _orderIndex = orderIndex;
  }
  return self;
}

- (void)dealloc {
  [_value release];
  [super dealloc];
}

@end

@interface MRRSavedRecipeProductContextSnapshot ()

@property(nonatomic, copy, readwrite) NSString *productName;
@property(nonatomic, copy, readwrite, nullable) NSString *brandText;
@property(nonatomic, copy, readwrite, nullable) NSString *nutritionGradeText;
@property(nonatomic, copy, readwrite, nullable) NSString *quantityText;

@end

@implementation MRRSavedRecipeProductContextSnapshot

- (instancetype)initWithProductName:(NSString *)productName
                          brandText:(NSString *)brandText
                 nutritionGradeText:(NSString *)nutritionGradeText
                       quantityText:(NSString *)quantityText {
  NSParameterAssert(productName.length > 0);

  self = [super init];
  if (self) {
    _productName = [productName copy];
    _brandText = [brandText copy];
    _nutritionGradeText = [nutritionGradeText copy];
    _quantityText = [quantityText copy];
  }
  return self;
}

- (void)dealloc {
  [_quantityText release];
  [_nutritionGradeText release];
  [_brandText release];
  [_productName release];
  [super dealloc];
}

@end

@interface MRRSavedRecipeSnapshot ()

@property(nonatomic, copy, readwrite) NSString *userID;
@property(nonatomic, copy, readwrite) NSString *recipeID;
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *subtitle;
@property(nonatomic, copy, readwrite) NSString *assetName;
@property(nonatomic, copy, readwrite, nullable) NSString *heroImageURLString;
@property(nonatomic, copy, readwrite) NSString *summaryText;
@property(nonatomic, copy, readwrite) NSString *mealType;
@property(nonatomic, copy, readwrite, nullable) NSString *sourceName;
@property(nonatomic, copy, readwrite, nullable) NSString *sourceURLString;
@property(nonatomic, assign, readwrite) NSInteger readyInMinutes;
@property(nonatomic, assign, readwrite) NSInteger servings;
@property(nonatomic, assign, readwrite) NSInteger calorieCount;
@property(nonatomic, assign, readwrite) NSInteger popularityScore;
@property(nonatomic, copy, readwrite) NSString *durationText;
@property(nonatomic, copy, readwrite) NSString *calorieText;
@property(nonatomic, copy, readwrite) NSString *servingsText;
@property(nonatomic, copy, readwrite) NSArray<MRRSavedRecipeIngredientSnapshot *> *ingredients;
@property(nonatomic, copy, readwrite) NSArray<MRRSavedRecipeInstructionSnapshot *> *instructions;
@property(nonatomic, copy, readwrite) NSArray<MRRSavedRecipeStringSnapshot *> *tools;
@property(nonatomic, copy, readwrite) NSArray<MRRSavedRecipeStringSnapshot *> *tags;
@property(nonatomic, retain, readwrite, nullable) MRRSavedRecipeProductContextSnapshot *productContext;
@property(nonatomic, retain, readwrite) NSDate *savedAt;
@property(nonatomic, retain, readwrite) NSDate *localModifiedAt;
@property(nonatomic, retain, readwrite, nullable) NSDate *remoteUpdatedAt;

@end

@implementation MRRSavedRecipeSnapshot

- (instancetype)initWithUserID:(NSString *)userID
                      recipeID:(NSString *)recipeID
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                     assetName:(NSString *)assetName
            heroImageURLString:(NSString *)heroImageURLString
                   summaryText:(NSString *)summaryText
                      mealType:(NSString *)mealType
                    sourceName:(NSString *)sourceName
               sourceURLString:(NSString *)sourceURLString
                readyInMinutes:(NSInteger)readyInMinutes
                      servings:(NSInteger)servings
                  calorieCount:(NSInteger)calorieCount
               popularityScore:(NSInteger)popularityScore
                  durationText:(NSString *)durationText
                   calorieText:(NSString *)calorieText
                  servingsText:(NSString *)servingsText
                   ingredients:(NSArray<MRRSavedRecipeIngredientSnapshot *> *)ingredients
                  instructions:(NSArray<MRRSavedRecipeInstructionSnapshot *> *)instructions
                         tools:(NSArray<MRRSavedRecipeStringSnapshot *> *)tools
                          tags:(NSArray<MRRSavedRecipeStringSnapshot *> *)tags
                productContext:(MRRSavedRecipeProductContextSnapshot *)productContext
                       savedAt:(NSDate *)savedAt
               localModifiedAt:(NSDate *)localModifiedAt
               remoteUpdatedAt:(NSDate *)remoteUpdatedAt {
  NSParameterAssert(userID.length > 0);
  NSParameterAssert(recipeID.length > 0);
  NSParameterAssert(title.length > 0);
  NSParameterAssert(subtitle != nil);
  NSParameterAssert(assetName.length > 0);
  NSParameterAssert(summaryText.length > 0);
  NSParameterAssert(mealType.length > 0);
  NSParameterAssert(durationText.length > 0);
  NSParameterAssert(calorieText.length > 0);
  NSParameterAssert(servingsText.length > 0);
  NSParameterAssert(ingredients != nil);
  NSParameterAssert(instructions != nil);
  NSParameterAssert(tools != nil);
  NSParameterAssert(tags != nil);
  NSParameterAssert(savedAt != nil);
  NSParameterAssert(localModifiedAt != nil);

  self = [super init];
  if (self) {
    _userID = [userID copy];
    _recipeID = [recipeID copy];
    _title = [title copy];
    _subtitle = [subtitle copy];
    _assetName = [assetName copy];
    _heroImageURLString = [heroImageURLString copy];
    _summaryText = [summaryText copy];
    _mealType = MRRResolvedSavedRecipeMealType(mealType);
    _sourceName = [sourceName copy];
    _sourceURLString = [sourceURLString copy];
    _readyInMinutes = readyInMinutes;
    _servings = servings;
    _calorieCount = calorieCount;
    _popularityScore = popularityScore;
    _durationText = [durationText copy];
    _calorieText = [calorieText copy];
    _servingsText = [servingsText copy];
    _ingredients = [ingredients copy];
    _instructions = [instructions copy];
    _tools = [tools copy];
    _tags = [tags copy];
    _productContext = [productContext retain];
    _savedAt = [savedAt retain];
    _localModifiedAt = [localModifiedAt retain];
    _remoteUpdatedAt = [remoteUpdatedAt retain];
  }
  return self;
}

+ (instancetype)snapshotWithUserID:(NSString *)userID
                        recipeCard:(HomeRecipeCard *)recipeCard
                      recipeDetail:(OnboardingRecipeDetail *)recipeDetail
                           savedAt:(NSDate *)savedAt
                   localModifiedAt:(NSDate *)localModifiedAt {
  NSParameterAssert(recipeCard != nil);
  NSParameterAssert(recipeDetail != nil);
  return [[[self alloc] initWithUserID:userID
                              recipeID:recipeCard.recipeID
                                 title:recipeDetail.title.length > 0 ? recipeDetail.title : recipeCard.title
                              subtitle:recipeDetail.subtitle.length > 0 ? recipeDetail.subtitle : recipeCard.subtitle
                             assetName:recipeDetail.assetName.length > 0 ? recipeDetail.assetName : recipeCard.assetName
                    heroImageURLString:recipeDetail.heroImageURLString.length > 0 ? recipeDetail.heroImageURLString : recipeCard.imageURLString
                           summaryText:recipeDetail.summaryText.length > 0 ? recipeDetail.summaryText : recipeCard.summaryText
                              mealType:recipeCard.mealType.length > 0 ? recipeCard.mealType : MRRSavedRecipeMealTypeSnack
                            sourceName:recipeDetail.sourceName.length > 0 ? recipeDetail.sourceName : recipeCard.sourceName
                       sourceURLString:recipeDetail.sourceURLString.length > 0 ? recipeDetail.sourceURLString : recipeCard.sourceURLString
                        readyInMinutes:recipeCard.readyInMinutes
                              servings:recipeCard.servings
                          calorieCount:recipeCard.calorieCount
                       popularityScore:recipeCard.popularityScore
                          durationText:recipeDetail.durationText.length > 0 ? recipeDetail.durationText : [recipeCard durationText]
                           calorieText:recipeDetail.calorieText.length > 0 ? recipeDetail.calorieText : [recipeCard calorieText]
                          servingsText:recipeDetail.servingsText.length > 0 ? recipeDetail.servingsText : [recipeCard servingsText]
                           ingredients:MRRSavedRecipeIngredientSnapshotsFromDetail(recipeDetail)
                          instructions:MRRSavedRecipeInstructionSnapshotsFromDetail(recipeDetail)
                                 tools:MRRSavedRecipeStringSnapshotsFromValues(recipeDetail.tools)
                                  tags:MRRSavedRecipeStringSnapshotsFromValues(recipeDetail.tags.count > 0 ? recipeDetail.tags : recipeCard.tags)
                        productContext:MRRSavedRecipeProductContextSnapshotFromDetail(recipeDetail)
                               savedAt:savedAt
                       localModifiedAt:localModifiedAt
                       remoteUpdatedAt:nil] autorelease];
}

- (void)dealloc {
  [_remoteUpdatedAt release];
  [_localModifiedAt release];
  [_savedAt release];
  [_productContext release];
  [_tags release];
  [_tools release];
  [_instructions release];
  [_ingredients release];
  [_servingsText release];
  [_calorieText release];
  [_durationText release];
  [_sourceURLString release];
  [_sourceName release];
  [_mealType release];
  [_summaryText release];
  [_heroImageURLString release];
  [_assetName release];
  [_subtitle release];
  [_title release];
  [_recipeID release];
  [_userID release];
  [super dealloc];
}

- (OnboardingRecipeDetail *)recipeDetailRepresentation {
  NSMutableArray<OnboardingRecipeIngredient *> *ingredients = [NSMutableArray array];
  for (MRRSavedRecipeIngredientSnapshot *ingredientSnapshot in self.ingredients) {
    OnboardingRecipeIngredient *ingredient = [[[OnboardingRecipeIngredient alloc] initWithName:ingredientSnapshot.name
                                                                                   displayText:ingredientSnapshot.displayText] autorelease];
    [ingredients addObject:ingredient];
  }

  NSMutableArray<OnboardingRecipeInstruction *> *instructions = [NSMutableArray array];
  for (MRRSavedRecipeInstructionSnapshot *instructionSnapshot in self.instructions) {
    OnboardingRecipeInstruction *instruction = [[[OnboardingRecipeInstruction alloc] initWithTitle:instructionSnapshot.title
                                                                                        detailText:instructionSnapshot.detailText] autorelease];
    [instructions addObject:instruction];
  }

  NSMutableArray<NSString *> *tools = [NSMutableArray array];
  for (MRRSavedRecipeStringSnapshot *toolSnapshot in self.tools) {
    [tools addObject:toolSnapshot.value];
  }

  NSMutableArray<NSString *> *tags = [NSMutableArray array];
  for (MRRSavedRecipeStringSnapshot *tagSnapshot in self.tags) {
    [tags addObject:tagSnapshot.value];
  }

  OnboardingRecipeProductContext *productContext = nil;
  if (self.productContext != nil) {
    productContext = [[[OnboardingRecipeProductContext alloc] initWithProductName:self.productContext.productName
                                                                        brandText:self.productContext.brandText
                                                               nutritionGradeText:self.productContext.nutritionGradeText
                                                                     quantityText:self.productContext.quantityText] autorelease];
  }

  return [[[OnboardingRecipeDetail alloc] initWithTitle:self.title
                                               subtitle:self.subtitle
                                              assetName:self.assetName
                                     heroImageURLString:self.heroImageURLString
                                           durationText:self.durationText
                                            calorieText:self.calorieText
                                           servingsText:self.servingsText
                                            summaryText:self.summaryText
                                            ingredients:ingredients
                                           instructions:instructions
                                                  tools:tools
                                                   tags:tags
                                             sourceName:self.sourceName
                                        sourceURLString:self.sourceURLString
                                         productContext:productContext] autorelease];
}

- (OnboardingRecipePreview *)recipePreviewRepresentation {
  return [[[OnboardingRecipePreview alloc] initWithTitle:self.title
                                                subtitle:self.subtitle
                                               assetName:self.assetName
                                    openFoodFactsBarcode:nil
                                          fallbackDetail:[self recipeDetailRepresentation]] autorelease];
}

- (NSString *)sectionIdentifier {
  return self.mealType;
}

- (NSString *)sectionTitle {
  if ([self.mealType isEqualToString:MRRSavedRecipeMealTypeBreakfast]) {
    return @"Breakfast";
  }
  if ([self.mealType isEqualToString:MRRSavedRecipeMealTypeLunch]) {
    return @"Lunch";
  }
  if ([self.mealType isEqualToString:MRRSavedRecipeMealTypeDinner]) {
    return @"Dinner";
  }
  if ([self.mealType isEqualToString:MRRSavedRecipeMealTypeDessert]) {
    return @"Dessert";
  }
  return @"Snack";
}

@end
