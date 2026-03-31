#import "MRRUserRecipeSnapshot.h"

#import "../../../Features/Onboarding/Data/OnboardingRecipeModels.h"

NSString *const MRRUserRecipeMealTypeBreakfast = @"breakfast";
NSString *const MRRUserRecipeMealTypeLunch = @"lunch";
NSString *const MRRUserRecipeMealTypeDinner = @"dinner";
NSString *const MRRUserRecipeMealTypeDessert = @"dessert";
NSString *const MRRUserRecipeMealTypeSnack = @"snack";

static NSString *MRRTrimmedUserRecipeString(NSString *string) {
  return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *MRRUserRecipeLegacyPhotoIdentifier(NSString *recipeID) {
  NSString *resolvedRecipeID = MRRTrimmedUserRecipeString(recipeID ?: @"");
  return resolvedRecipeID.length > 0 ? [resolvedRecipeID stringByAppendingString:@".legacyCover"] : @"legacyCover";
}

static NSString *MRRResolvedUserRecipeMealType(NSString *mealType) {
  NSString *trimmedMealType = [[MRRTrimmedUserRecipeString(mealType ?: @"") lowercaseString] copy];
  if (trimmedMealType.length == 0) {
    [trimmedMealType release];
    return [MRRUserRecipeMealTypeSnack retain];
  }
  if ([trimmedMealType isEqualToString:MRRUserRecipeMealTypeBreakfast] ||
      [trimmedMealType isEqualToString:MRRUserRecipeMealTypeLunch] ||
      [trimmedMealType isEqualToString:MRRUserRecipeMealTypeDinner] ||
      [trimmedMealType isEqualToString:MRRUserRecipeMealTypeDessert] ||
      [trimmedMealType isEqualToString:MRRUserRecipeMealTypeSnack]) {
    return trimmedMealType;
  }

  if ([trimmedMealType isEqualToString:@"breakfast"]) {
    return trimmedMealType;
  }
  if ([trimmedMealType isEqualToString:@"lunch"]) {
    return trimmedMealType;
  }
  if ([trimmedMealType isEqualToString:@"dinner"]) {
    return trimmedMealType;
  }
  if ([trimmedMealType isEqualToString:@"dessert"]) {
    return trimmedMealType;
  }
  if ([trimmedMealType isEqualToString:@"snack"]) {
    return trimmedMealType;
  }

  [trimmedMealType release];
  return [MRRUserRecipeMealTypeSnack retain];
}

static NSArray<MRRUserRecipeIngredientSnapshot *> *MRRUserRecipeIngredientSnapshotsFromDetail(OnboardingRecipeDetail *recipeDetail) {
  NSMutableArray<MRRUserRecipeIngredientSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (OnboardingRecipeIngredient *ingredient in recipeDetail.ingredients ?: @[]) {
    NSString *name = ingredient.name.length > 0 ? ingredient.name : ingredient.displayText;
    NSString *displayText = ingredient.displayText.length > 0 ? ingredient.displayText : ingredient.name;
    if (displayText.length == 0) {
      continue;
    }
    MRRUserRecipeIngredientSnapshot *snapshot =
        [[[MRRUserRecipeIngredientSnapshot alloc] initWithName:name ?: displayText displayText:displayText orderIndex:(NSInteger)orderIndex] autorelease];
    [snapshots addObject:snapshot];
    orderIndex += 1;
  }
  return snapshots;
}

static NSArray<MRRUserRecipeInstructionSnapshot *> *MRRUserRecipeInstructionSnapshotsFromDetail(OnboardingRecipeDetail *recipeDetail) {
  NSMutableArray<MRRUserRecipeInstructionSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (OnboardingRecipeInstruction *instruction in recipeDetail.instructions ?: @[]) {
    NSString *detailText = MRRTrimmedUserRecipeString(instruction.detailText ?: @"");
    if (detailText.length == 0) {
      continue;
    }
    NSString *title = MRRTrimmedUserRecipeString(instruction.title ?: @"");
    if (title.length == 0) {
      title = [NSString stringWithFormat:@"Step %lu", (unsigned long)(orderIndex + 1)];
    }
    MRRUserRecipeInstructionSnapshot *snapshot =
        [[[MRRUserRecipeInstructionSnapshot alloc] initWithTitle:title
                                                      detailText:detailText
                                                      orderIndex:(NSInteger)orderIndex] autorelease];
    [snapshots addObject:snapshot];
    orderIndex += 1;
  }
  return snapshots;
}

static NSArray<MRRUserRecipeStringSnapshot *> *MRRUserRecipeStringSnapshotsFromValues(NSArray<NSString *> *values) {
  NSMutableArray<MRRUserRecipeStringSnapshot *> *snapshots = [NSMutableArray array];
  NSUInteger orderIndex = 0;
  for (NSString *value in values ?: @[]) {
    NSString *trimmedValue = MRRTrimmedUserRecipeString(value ?: @"");
    if (trimmedValue.length == 0) {
      continue;
    }
    MRRUserRecipeStringSnapshot *snapshot = [[[MRRUserRecipeStringSnapshot alloc] initWithValue:trimmedValue orderIndex:(NSInteger)orderIndex] autorelease];
    [snapshots addObject:snapshot];
    orderIndex += 1;
  }
  return snapshots;
}

@interface MRRUserRecipeIngredientSnapshot ()

@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, copy, readwrite) NSString *displayText;
@property(nonatomic, assign, readwrite) NSInteger orderIndex;

@end

@implementation MRRUserRecipeIngredientSnapshot

- (instancetype)initWithName:(NSString *)name displayText:(NSString *)displayText orderIndex:(NSInteger)orderIndex {
  NSString *resolvedName = MRRTrimmedUserRecipeString(name ?: @"");
  NSString *resolvedDisplayText = MRRTrimmedUserRecipeString(displayText ?: @"");
  NSParameterAssert(resolvedName.length > 0);
  NSParameterAssert(resolvedDisplayText.length > 0);

  self = [super init];
  if (self) {
    _name = [resolvedName copy];
    _displayText = [resolvedDisplayText copy];
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

@interface MRRUserRecipeInstructionSnapshot ()

@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *detailText;
@property(nonatomic, assign, readwrite) NSInteger orderIndex;

@end

@implementation MRRUserRecipeInstructionSnapshot

- (instancetype)initWithTitle:(NSString *)title detailText:(NSString *)detailText orderIndex:(NSInteger)orderIndex {
  NSString *resolvedTitle = MRRTrimmedUserRecipeString(title ?: @"");
  NSString *resolvedDetailText = MRRTrimmedUserRecipeString(detailText ?: @"");
  NSParameterAssert(resolvedTitle.length > 0);
  NSParameterAssert(resolvedDetailText.length > 0);

  self = [super init];
  if (self) {
    _title = [resolvedTitle copy];
    _detailText = [resolvedDetailText copy];
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

@interface MRRUserRecipeStringSnapshot ()

@property(nonatomic, copy, readwrite) NSString *value;
@property(nonatomic, assign, readwrite) NSInteger orderIndex;

@end

@implementation MRRUserRecipeStringSnapshot

- (instancetype)initWithValue:(NSString *)value orderIndex:(NSInteger)orderIndex {
  NSString *resolvedValue = MRRTrimmedUserRecipeString(value ?: @"");
  NSParameterAssert(resolvedValue.length > 0);

  self = [super init];
  if (self) {
    _value = [resolvedValue copy];
    _orderIndex = orderIndex;
  }
  return self;
}

- (void)dealloc {
  [_value release];
  [super dealloc];
}

@end

@interface MRRUserRecipePhotoSnapshot ()

@property(nonatomic, copy, readwrite) NSString *photoID;
@property(nonatomic, assign, readwrite) NSInteger orderIndex;
@property(nonatomic, copy, readwrite, nullable) NSString *remoteURLString;
@property(nonatomic, copy, readwrite, nullable) NSString *localRelativePath;

@end

@implementation MRRUserRecipePhotoSnapshot

- (instancetype)initWithPhotoID:(NSString *)photoID
                     orderIndex:(NSInteger)orderIndex
                remoteURLString:(NSString *)remoteURLString
              localRelativePath:(NSString *)localRelativePath {
  NSString *resolvedPhotoID = MRRTrimmedUserRecipeString(photoID ?: @"");
  NSString *resolvedRemoteURLString = MRRTrimmedUserRecipeString(remoteURLString ?: @"");
  NSString *resolvedLocalRelativePath = MRRTrimmedUserRecipeString(localRelativePath ?: @"");
  NSParameterAssert(resolvedPhotoID.length > 0);
  NSParameterAssert(resolvedRemoteURLString.length > 0 || resolvedLocalRelativePath.length > 0);

  self = [super init];
  if (self) {
    _photoID = [resolvedPhotoID copy];
    _orderIndex = orderIndex;
    _remoteURLString = resolvedRemoteURLString.length > 0 ? [resolvedRemoteURLString copy] : nil;
    _localRelativePath = resolvedLocalRelativePath.length > 0 ? [resolvedLocalRelativePath copy] : nil;
  }
  return self;
}

- (void)dealloc {
  [_localRelativePath release];
  [_remoteURLString release];
  [_photoID release];
  [super dealloc];
}

@end

static NSArray<MRRUserRecipePhotoSnapshot *> *MRRUserRecipeNormalizedPhotos(NSArray<MRRUserRecipePhotoSnapshot *> *photos,
                                                                            NSString *legacyHeroImageURLString,
                                                                            NSString *recipeID) {
  NSMutableArray<MRRUserRecipePhotoSnapshot *> *normalizedPhotos = [NSMutableArray array];
  NSInteger normalizedOrderIndex = 0;
  for (MRRUserRecipePhotoSnapshot *photo in photos ?: @[]) {
    if (![photo isKindOfClass:[MRRUserRecipePhotoSnapshot class]]) {
      continue;
    }
    NSString *resolvedPhotoID = MRRTrimmedUserRecipeString(photo.photoID ?: @"");
    NSString *resolvedRemoteURLString = MRRTrimmedUserRecipeString(photo.remoteURLString ?: @"");
    NSString *resolvedLocalRelativePath = MRRTrimmedUserRecipeString(photo.localRelativePath ?: @"");
    if (resolvedPhotoID.length == 0 || (resolvedRemoteURLString.length == 0 && resolvedLocalRelativePath.length == 0)) {
      continue;
    }
    [normalizedPhotos addObject:[[[MRRUserRecipePhotoSnapshot alloc] initWithPhotoID:resolvedPhotoID
                                                                           orderIndex:normalizedOrderIndex
                                                                      remoteURLString:resolvedRemoteURLString
                                                                    localRelativePath:resolvedLocalRelativePath] autorelease]];
    normalizedOrderIndex += 1;
  }

  NSString *resolvedLegacyHeroImageURLString = MRRTrimmedUserRecipeString(legacyHeroImageURLString ?: @"");
  if (normalizedPhotos.count == 0 && resolvedLegacyHeroImageURLString.length > 0) {
    [normalizedPhotos addObject:[[[MRRUserRecipePhotoSnapshot alloc] initWithPhotoID:MRRUserRecipeLegacyPhotoIdentifier(recipeID)
                                                                           orderIndex:0
                                                                      remoteURLString:resolvedLegacyHeroImageURLString
                                                                    localRelativePath:nil] autorelease]];
  }

  return normalizedPhotos;
}

static NSString *MRRUserRecipeResolvedHeroImageURLString(NSArray<MRRUserRecipePhotoSnapshot *> *photos,
                                                         NSString *legacyHeroImageURLString) {
  MRRUserRecipePhotoSnapshot *coverPhoto = photos.count > 0 ? photos.firstObject : nil;
  NSString *resolvedCoverRemoteURLString = MRRTrimmedUserRecipeString(coverPhoto.remoteURLString ?: @"");
  if (resolvedCoverRemoteURLString.length > 0) {
    return resolvedCoverRemoteURLString;
  }
  NSString *resolvedLegacyHeroImageURLString = MRRTrimmedUserRecipeString(legacyHeroImageURLString ?: @"");
  return resolvedLegacyHeroImageURLString.length > 0 ? resolvedLegacyHeroImageURLString : @"";
}

@interface MRRUserRecipeSnapshot ()

@property(nonatomic, copy, readwrite) NSString *userID;
@property(nonatomic, copy, readwrite) NSString *recipeID;
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *subtitle;
@property(nonatomic, copy, readwrite) NSString *summaryText;
@property(nonatomic, copy, readwrite) NSString *mealType;
@property(nonatomic, assign, readwrite) NSInteger readyInMinutes;
@property(nonatomic, assign, readwrite) NSInteger servings;
@property(nonatomic, assign, readwrite) NSInteger calorieCount;
@property(nonatomic, copy, readwrite) NSString *assetName;
@property(nonatomic, copy, readwrite, nullable) NSString *heroImageURLString;
@property(nonatomic, copy, readwrite) NSArray<MRRUserRecipePhotoSnapshot *> *photos;
@property(nonatomic, copy, readwrite) NSArray<MRRUserRecipeIngredientSnapshot *> *ingredients;
@property(nonatomic, copy, readwrite) NSArray<MRRUserRecipeInstructionSnapshot *> *instructions;
@property(nonatomic, copy, readwrite) NSArray<MRRUserRecipeStringSnapshot *> *tools;
@property(nonatomic, copy, readwrite) NSArray<MRRUserRecipeStringSnapshot *> *tags;
@property(nonatomic, retain, readwrite) NSDate *createdAt;
@property(nonatomic, retain, readwrite) NSDate *localModifiedAt;
@property(nonatomic, retain, readwrite, nullable) NSDate *remoteUpdatedAt;

@end

@implementation MRRUserRecipeSnapshot

- (instancetype)initWithUserID:(NSString *)userID
                      recipeID:(NSString *)recipeID
                         title:(NSString *)title
                      subtitle:(NSString *)subtitle
                   summaryText:(NSString *)summaryText
                      mealType:(NSString *)mealType
                readyInMinutes:(NSInteger)readyInMinutes
                      servings:(NSInteger)servings
                  calorieCount:(NSInteger)calorieCount
                     assetName:(NSString *)assetName
              heroImageURLString:(NSString *)heroImageURLString
                         photos:(NSArray<MRRUserRecipePhotoSnapshot *> *)photos
                   ingredients:(NSArray<MRRUserRecipeIngredientSnapshot *> *)ingredients
                  instructions:(NSArray<MRRUserRecipeInstructionSnapshot *> *)instructions
                         tools:(NSArray<MRRUserRecipeStringSnapshot *> *)tools
                          tags:(NSArray<MRRUserRecipeStringSnapshot *> *)tags
                     createdAt:(NSDate *)createdAt
               localModifiedAt:(NSDate *)localModifiedAt
               remoteUpdatedAt:(NSDate *)remoteUpdatedAt {
  NSString *resolvedTitle = MRRTrimmedUserRecipeString(title ?: @"");
  NSString *resolvedSummaryText = MRRTrimmedUserRecipeString(summaryText ?: @"");
  NSString *resolvedAssetName = MRRTrimmedUserRecipeString(assetName ?: @"");
  NSArray<MRRUserRecipePhotoSnapshot *> *resolvedPhotos = MRRUserRecipeNormalizedPhotos(photos, heroImageURLString, recipeID);
  NSString *resolvedHeroImageURLString = MRRUserRecipeResolvedHeroImageURLString(resolvedPhotos, heroImageURLString);

  NSParameterAssert(userID.length > 0);
  NSParameterAssert(recipeID.length > 0);
  NSParameterAssert(resolvedTitle.length > 0);
  NSParameterAssert(subtitle != nil);
  NSParameterAssert(resolvedAssetName.length > 0);
  NSParameterAssert(photos != nil);
  NSParameterAssert(ingredients != nil);
  NSParameterAssert(instructions != nil);
  NSParameterAssert(tools != nil);
  NSParameterAssert(tags != nil);
  NSParameterAssert(createdAt != nil);
  NSParameterAssert(localModifiedAt != nil);

  self = [super init];
  if (self) {
    _userID = [userID copy];
    _recipeID = [recipeID copy];
    _title = [resolvedTitle copy];
    _subtitle = [subtitle copy];
    _summaryText = [resolvedSummaryText copy];
    _mealType = MRRResolvedUserRecipeMealType(mealType ?: @"");
    _readyInMinutes = MAX(1, readyInMinutes);
    _servings = MAX(1, servings);
    _calorieCount = MAX(0, calorieCount);
    _assetName = [resolvedAssetName copy];
    _heroImageURLString = resolvedHeroImageURLString.length > 0 ? [resolvedHeroImageURLString copy] : nil;
    _photos = [resolvedPhotos copy];
    _ingredients = [ingredients copy];
    _instructions = [instructions copy];
    _tools = [tools copy];
    _tags = [tags copy];
    _createdAt = [createdAt retain];
    _localModifiedAt = [localModifiedAt retain];
    _remoteUpdatedAt = [remoteUpdatedAt retain];
  }
  return self;
}

+ (instancetype)snapshotWithUserID:(NSString *)userID
                        recipeCard:(HomeRecipeCard *)recipeCard
                      recipeDetail:(OnboardingRecipeDetail *)recipeDetail
                         createdAt:(NSDate *)createdAt
                   localModifiedAt:(NSDate *)localModifiedAt {
  NSParameterAssert(recipeCard != nil);
  NSParameterAssert(recipeDetail != nil);

  NSString *summaryText = MRRTrimmedUserRecipeString(recipeDetail.summaryText ?: recipeCard.summaryText ?: @"");
  if (summaryText.length == 0) {
    summaryText = @"Recipe created by you.";
  }

  return [[[self alloc] initWithUserID:userID
                              recipeID:recipeCard.recipeID
                                 title:recipeDetail.title.length > 0 ? recipeDetail.title : recipeCard.title
                              subtitle:recipeDetail.subtitle.length > 0 ? recipeDetail.subtitle : recipeCard.subtitle
                           summaryText:summaryText
                              mealType:recipeCard.mealType.length > 0 ? recipeCard.mealType : MRRUserRecipeMealTypeSnack
                        readyInMinutes:MAX(1, recipeCard.readyInMinutes)
                              servings:MAX(1, recipeCard.servings)
                          calorieCount:MAX(0, recipeCard.calorieCount)
                             assetName:recipeDetail.assetName.length > 0 ? recipeDetail.assetName : recipeCard.assetName
                      heroImageURLString:recipeDetail.heroImageURLString.length > 0 ? recipeDetail.heroImageURLString : recipeCard.imageURLString
                                photos:@[]
                           ingredients:MRRUserRecipeIngredientSnapshotsFromDetail(recipeDetail)
                          instructions:MRRUserRecipeInstructionSnapshotsFromDetail(recipeDetail)
                                 tools:MRRUserRecipeStringSnapshotsFromValues(recipeDetail.tools)
                                  tags:MRRUserRecipeStringSnapshotsFromValues(recipeDetail.tags.count > 0 ? recipeDetail.tags : recipeCard.tags)
                             createdAt:createdAt
                       localModifiedAt:localModifiedAt
                       remoteUpdatedAt:nil] autorelease];
}

+ (NSString *)normalizedMealTypeFromString:(NSString *)mealType {
  NSString *normalizedMealType = MRRResolvedUserRecipeMealType(mealType ?: @"");
  return [normalizedMealType autorelease];
}

+ (NSString *)defaultAssetName {
  return @"avocado-toast";
}

- (MRRUserRecipePhotoSnapshot *)coverPhotoSnapshot {
  return self.photos.count > 0 ? self.photos.firstObject : nil;
}

- (NSArray<NSString *> *)remotePhotoURLStrings {
  NSMutableArray<NSString *> *photoURLStrings = [NSMutableArray array];
  for (MRRUserRecipePhotoSnapshot *photoSnapshot in self.photos) {
    NSString *remoteURLString = MRRTrimmedUserRecipeString(photoSnapshot.remoteURLString ?: @"");
    if (remoteURLString.length == 0) {
      continue;
    }
    [photoURLStrings addObject:remoteURLString];
  }
  return photoURLStrings;
}

- (OnboardingRecipeDetail *)recipeDetailRepresentation {
  NSMutableArray<OnboardingRecipeIngredient *> *ingredients = [NSMutableArray array];
  for (MRRUserRecipeIngredientSnapshot *ingredientSnapshot in self.ingredients) {
    OnboardingRecipeIngredient *ingredient =
        [[[OnboardingRecipeIngredient alloc] initWithName:ingredientSnapshot.name displayText:ingredientSnapshot.displayText] autorelease];
    [ingredients addObject:ingredient];
  }

  NSMutableArray<OnboardingRecipeInstruction *> *instructions = [NSMutableArray array];
  for (MRRUserRecipeInstructionSnapshot *instructionSnapshot in self.instructions) {
    OnboardingRecipeInstruction *instruction =
        [[[OnboardingRecipeInstruction alloc] initWithTitle:instructionSnapshot.title detailText:instructionSnapshot.detailText] autorelease];
    [instructions addObject:instruction];
  }

  NSMutableArray<NSString *> *tools = [NSMutableArray array];
  for (MRRUserRecipeStringSnapshot *toolSnapshot in self.tools) {
    [tools addObject:toolSnapshot.value];
  }

  NSMutableArray<NSString *> *tags = [NSMutableArray array];
  for (MRRUserRecipeStringSnapshot *tagSnapshot in self.tags) {
    [tags addObject:tagSnapshot.value];
  }

  return [[[OnboardingRecipeDetail alloc] initWithTitle:self.title
                                               subtitle:self.subtitle
                                              assetName:self.assetName
                                     heroImageURLString:self.heroImageURLString
                                           durationText:[self durationText]
                                            calorieText:[self calorieText]
                                           servingsText:[self servingsText]
                                            summaryText:self.summaryText
                                            ingredients:ingredients
                                           instructions:instructions
                                                  tools:tools
                                                   tags:tags
                                             sourceName:nil
                                        sourceURLString:nil
                                         productContext:nil] autorelease];
}

- (NSString *)sectionIdentifier {
  return self.mealType;
}

- (NSString *)sectionTitle {
  if ([self.mealType isEqualToString:MRRUserRecipeMealTypeBreakfast]) {
    return @"Breakfast";
  }
  if ([self.mealType isEqualToString:MRRUserRecipeMealTypeLunch]) {
    return @"Lunch";
  }
  if ([self.mealType isEqualToString:MRRUserRecipeMealTypeDinner]) {
    return @"Dinner";
  }
  if ([self.mealType isEqualToString:MRRUserRecipeMealTypeDessert]) {
    return @"Dessert";
  }
  return @"Snack";
}

- (NSString *)durationText {
  return [NSString stringWithFormat:@"%ld mins", (long)self.readyInMinutes];
}

- (NSString *)calorieText {
  return self.calorieCount > 0 ? [NSString stringWithFormat:@"%ld kcal", (long)self.calorieCount] : @"Calories not set";
}

- (NSString *)servingsText {
  return self.servings == 1 ? @"1 serving" : [NSString stringWithFormat:@"%ld servings", (long)self.servings];
}

- (void)dealloc {
  [_remoteUpdatedAt release];
  [_localModifiedAt release];
  [_createdAt release];
  [_tags release];
  [_tools release];
  [_instructions release];
  [_ingredients release];
  [_photos release];
  [_heroImageURLString release];
  [_assetName release];
  [_mealType release];
  [_summaryText release];
  [_subtitle release];
  [_title release];
  [_recipeID release];
  [_userID release];
  [super dealloc];
}

@end
