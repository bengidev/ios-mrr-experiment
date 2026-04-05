#import "MRRSavedRecipesSyncEngine.h"

@import FirebaseFirestore;

#import "../MRRSavedRecipesStore.h"

static NSString *const MRRSavedRecipesFirestoreCollectionUsers = @"users";
static NSString *const MRRSavedRecipesFirestoreCollectionSavedRecipes = @"savedRecipes";

static NSString *const MRRSavedRecipesFirestoreKeyAssetName = @"assetName";
static NSString *const MRRSavedRecipesFirestoreKeyCalorieCount = @"calorieCount";
static NSString *const MRRSavedRecipesFirestoreKeyCalorieText = @"calorieText";
static NSString *const MRRSavedRecipesFirestoreKeyDurationText = @"durationText";
static NSString *const MRRSavedRecipesFirestoreKeyHeroImageURLString = @"heroImageURLString";
static NSString *const MRRSavedRecipesFirestoreKeyIngredients = @"ingredients";
static NSString *const MRRSavedRecipesFirestoreKeyInstructions = @"instructions";
static NSString *const MRRSavedRecipesFirestoreKeyIsDeleted = @"isDeleted";
static NSString *const MRRSavedRecipesFirestoreKeyMealType = @"mealType";
static NSString *const MRRSavedRecipesFirestoreKeyPopularityScore = @"popularityScore";
static NSString *const MRRSavedRecipesFirestoreKeyProductBrandText = @"productBrandText";
static NSString *const MRRSavedRecipesFirestoreKeyProductName = @"productName";
static NSString *const MRRSavedRecipesFirestoreKeyProductNutritionGradeText = @"productNutritionGradeText";
static NSString *const MRRSavedRecipesFirestoreKeyProductQuantityText = @"productQuantityText";
static NSString *const MRRSavedRecipesFirestoreKeyReadyInMinutes = @"readyInMinutes";
static NSString *const MRRSavedRecipesFirestoreKeyRecipeID = @"recipeID";
static NSString *const MRRSavedRecipesFirestoreKeySavedAt = @"savedAt";
static NSString *const MRRSavedRecipesFirestoreKeyServings = @"servings";
static NSString *const MRRSavedRecipesFirestoreKeyServingsText = @"servingsText";
static NSString *const MRRSavedRecipesFirestoreKeySourceName = @"sourceName";
static NSString *const MRRSavedRecipesFirestoreKeySourceURLString = @"sourceURLString";
static NSString *const MRRSavedRecipesFirestoreKeySubtitle = @"subtitle";
static NSString *const MRRSavedRecipesFirestoreKeySummaryText = @"summaryText";
static NSString *const MRRSavedRecipesFirestoreKeyTags = @"tags";
static NSString *const MRRSavedRecipesFirestoreKeyTitle = @"title";
static NSString *const MRRSavedRecipesFirestoreKeyTools = @"tools";
static NSString *const MRRSavedRecipesFirestoreKeyUpdatedAt = @"updatedAt";
static NSString *const MRRSavedRecipesFirestoreKeyUserID = @"userID";

static NSArray<NSDictionary<NSString *, id> *> *MRRSavedRecipesFirestoreIngredientPayload(NSArray<MRRSavedRecipeIngredientSnapshot *> *ingredients) {
  NSMutableArray<NSDictionary<NSString *, id> *> *payload = [NSMutableArray arrayWithCapacity:ingredients.count];
  for (MRRSavedRecipeIngredientSnapshot *ingredient in ingredients) {
    [payload addObject:@{@"name" : ingredient.name ?: @"", @"displayText" : ingredient.displayText ?: @"", @"orderIndex" : @(ingredient.orderIndex)}];
  }
  return payload;
}

static NSArray<NSDictionary<NSString *, id> *> *MRRSavedRecipesFirestoreInstructionPayload(
    NSArray<MRRSavedRecipeInstructionSnapshot *> *instructions) {
  NSMutableArray<NSDictionary<NSString *, id> *> *payload = [NSMutableArray arrayWithCapacity:instructions.count];
  for (MRRSavedRecipeInstructionSnapshot *instruction in instructions) {
    [payload addObject:@{
      @"title" : instruction.title ?: @"",
      @"detailText" : instruction.detailText ?: @"",
      @"orderIndex" : @(instruction.orderIndex)
    }];
  }
  return payload;
}

static NSArray<NSDictionary<NSString *, id> *> *MRRSavedRecipesFirestoreStringPayload(NSArray<MRRSavedRecipeStringSnapshot *> *values) {
  NSMutableArray<NSDictionary<NSString *, id> *> *payload = [NSMutableArray arrayWithCapacity:values.count];
  for (MRRSavedRecipeStringSnapshot *value in values) {
    [payload addObject:@{@"value" : value.value ?: @"", @"orderIndex" : @(value.orderIndex)}];
  }
  return payload;
}

static NSDate *MRRSavedRecipesFirestoreDateValue(id candidate) {
  if ([candidate isKindOfClass:[NSDate class]]) {
    return (NSDate *)candidate;
  }
  if ([candidate isKindOfClass:[FIRTimestamp class]]) {
    return [(FIRTimestamp *)candidate dateValue];
  }
  return nil;
}

static NSString *MRRSavedRecipesFirestoreStringValue(id candidate) {
  if (![candidate isKindOfClass:[NSString class]]) {
    return @"";
  }
  return (NSString *)candidate;
}

static NSInteger MRRSavedRecipesFirestoreIntegerValue(id candidate) {
  if ([candidate respondsToSelector:@selector(integerValue)]) {
    return [candidate integerValue];
  }
  return 0;
}

@interface MRRSavedRecipesSyncEngine ()

@property(nonatomic, retain) MRRSavedRecipesStore *store;
@property(nonatomic, retain) FIRFirestore *firestore;
@property(nonatomic, retain, nullable) id<FIRListenerRegistration> listenerRegistration;
@property(nonatomic, copy, nullable) NSString *activeUserID;
@property(nonatomic, retain) NSMutableArray *pendingCompletions;
@property(nonatomic, assign) BOOL syncInFlight;

- (FIRCollectionReference *)savedRecipesCollectionForUserID:(NSString *)userID;
- (NSDictionary<NSString *, id> *)firestorePayloadForSnapshot:(MRRSavedRecipeSnapshot *)snapshot updatedAt:(NSDate *)updatedAt;
- (nullable MRRSavedRecipeSnapshot *)snapshotFromDocument:(FIRDocumentSnapshot *)document userID:(NSString *)userID;
- (void)drainNextPendingChangeForUserID:(NSString *)userID completion:(nullable MRRSavedRecipesSyncCompletion)completion;
- (void)completeQueuedCompletionsWithError:(nullable NSError *)error;
- (void)handleRemoteSnapshot:(FIRQuerySnapshot *)snapshot userID:(NSString *)userID;

@end

@implementation MRRSavedRecipesSyncEngine

- (instancetype)initWithStore:(MRRSavedRecipesStore *)store {
  NSParameterAssert(store != nil);

  self = [super init];
  if (self) {
    _store = [store retain];
    _firestore = [[FIRFirestore firestore] retain];
    _pendingCompletions = [[NSMutableArray alloc] init];

    FIRFirestoreSettings *settings = [[[FIRFirestoreSettings alloc] init] autorelease];
    settings.cacheSettings = [[[FIRMemoryCacheSettings alloc] init] autorelease];
    _firestore.settings = settings;
  }
  return self;
}

- (void)dealloc {
  [self.listenerRegistration remove];
  [_pendingCompletions release];
  [_activeUserID release];
  [_listenerRegistration release];
  [_firestore release];
  [_store release];
  [super dealloc];
}

- (void)startSyncForUserID:(NSString *)userID completion:(MRRSavedRecipesSyncCompletion)completion {
  if (userID.length == 0) {
    if (completion != nil) {
      completion(nil);
    }
    return;
  }

  if (self.listenerRegistration != nil) {
    [self.listenerRegistration remove];
    self.listenerRegistration = nil;
  }
  self.activeUserID = userID;

  FIRCollectionReference *collection = [self savedRecipesCollectionForUserID:userID];
  [collection getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
    if (error == nil && snapshot != nil) {
      [self handleRemoteSnapshot:snapshot userID:userID];
    }
    if (completion != nil) {
      completion(error);
    }
  }];

  self.listenerRegistration = [[collection addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
    if (error != nil || snapshot == nil) {
      return;
    }
    [self handleRemoteSnapshot:snapshot userID:userID];
  }] retain];

  [self requestImmediateSyncForUserID:userID];
}

- (void)stopSync {
  [self.listenerRegistration remove];
  self.listenerRegistration = nil;
  self.activeUserID = nil;
  [self.pendingCompletions removeAllObjects];
  self.syncInFlight = NO;
}

- (void)requestImmediateSyncForUserID:(NSString *)userID {
  [self flushPendingChangesForUserID:userID completion:nil];
}

- (void)flushPendingChangesForUserID:(NSString *)userID completion:(MRRSavedRecipesSyncCompletion)completion {
  if (userID.length == 0) {
    if (completion != nil) {
      completion(nil);
    }
    return;
  }
  if (completion != nil) {
    [self.pendingCompletions addObject:[[completion copy] autorelease]];
  }
  if (self.syncInFlight) {
    return;
  }
  self.syncInFlight = YES;
  [self drainNextPendingChangeForUserID:userID completion:nil];
}

- (FIRCollectionReference *)savedRecipesCollectionForUserID:(NSString *)userID {
  FIRCollectionReference *usersCollection = [self.firestore collectionWithPath:MRRSavedRecipesFirestoreCollectionUsers];
  FIRDocumentReference *userDocument = [usersCollection documentWithPath:userID];
  return [userDocument collectionWithPath:MRRSavedRecipesFirestoreCollectionSavedRecipes];
}

- (NSDictionary<NSString *, id> *)firestorePayloadForSnapshot:(MRRSavedRecipeSnapshot *)snapshot updatedAt:(NSDate *)updatedAt {
  NSMutableDictionary<NSString *, id> *payload = [NSMutableDictionary dictionary];
  payload[MRRSavedRecipesFirestoreKeyUserID] = snapshot.userID;
  payload[MRRSavedRecipesFirestoreKeyRecipeID] = snapshot.recipeID;
  payload[MRRSavedRecipesFirestoreKeyTitle] = snapshot.title;
  payload[MRRSavedRecipesFirestoreKeySubtitle] = snapshot.subtitle;
  payload[MRRSavedRecipesFirestoreKeyAssetName] = snapshot.assetName;
  payload[MRRSavedRecipesFirestoreKeySummaryText] = snapshot.summaryText;
  payload[MRRSavedRecipesFirestoreKeyMealType] = snapshot.mealType;
  payload[MRRSavedRecipesFirestoreKeyDurationText] = snapshot.durationText;
  payload[MRRSavedRecipesFirestoreKeyCalorieText] = snapshot.calorieText;
  payload[MRRSavedRecipesFirestoreKeyServingsText] = snapshot.servingsText;
  payload[MRRSavedRecipesFirestoreKeyReadyInMinutes] = @(snapshot.readyInMinutes);
  payload[MRRSavedRecipesFirestoreKeyServings] = @(snapshot.servings);
  payload[MRRSavedRecipesFirestoreKeyCalorieCount] = @(snapshot.calorieCount);
  payload[MRRSavedRecipesFirestoreKeyPopularityScore] = @(snapshot.popularityScore);
  payload[MRRSavedRecipesFirestoreKeySavedAt] = snapshot.savedAt;
  payload[MRRSavedRecipesFirestoreKeyUpdatedAt] = updatedAt;
  payload[MRRSavedRecipesFirestoreKeyIsDeleted] = @NO;
  payload[MRRSavedRecipesFirestoreKeyIngredients] = MRRSavedRecipesFirestoreIngredientPayload(snapshot.ingredients);
  payload[MRRSavedRecipesFirestoreKeyInstructions] = MRRSavedRecipesFirestoreInstructionPayload(snapshot.instructions);
  payload[MRRSavedRecipesFirestoreKeyTools] = MRRSavedRecipesFirestoreStringPayload(snapshot.tools);
  payload[MRRSavedRecipesFirestoreKeyTags] = MRRSavedRecipesFirestoreStringPayload(snapshot.tags);
  if (snapshot.heroImageURLString.length > 0) {
    payload[MRRSavedRecipesFirestoreKeyHeroImageURLString] = snapshot.heroImageURLString;
  }
  if (snapshot.sourceName.length > 0) {
    payload[MRRSavedRecipesFirestoreKeySourceName] = snapshot.sourceName;
  }
  if (snapshot.sourceURLString.length > 0) {
    payload[MRRSavedRecipesFirestoreKeySourceURLString] = snapshot.sourceURLString;
  }
  if (snapshot.productContext.productName.length > 0) {
    payload[MRRSavedRecipesFirestoreKeyProductName] = snapshot.productContext.productName;
  }
  if (snapshot.productContext.brandText.length > 0) {
    payload[MRRSavedRecipesFirestoreKeyProductBrandText] = snapshot.productContext.brandText;
  }
  if (snapshot.productContext.nutritionGradeText.length > 0) {
    payload[MRRSavedRecipesFirestoreKeyProductNutritionGradeText] = snapshot.productContext.nutritionGradeText;
  }
  if (snapshot.productContext.quantityText.length > 0) {
    payload[MRRSavedRecipesFirestoreKeyProductQuantityText] = snapshot.productContext.quantityText;
  }
  return payload;
}

- (MRRSavedRecipeSnapshot *)snapshotFromDocument:(FIRDocumentSnapshot *)document userID:(NSString *)userID {
  NSDictionary *data = document.data;
  if (![data isKindOfClass:[NSDictionary class]]) {
    return nil;
  }

  NSArray *ingredientEntries = [data objectForKey:MRRSavedRecipesFirestoreKeyIngredients];
  NSMutableArray<MRRSavedRecipeIngredientSnapshot *> *ingredients = [NSMutableArray array];
  for (NSDictionary *ingredientEntry in ingredientEntries ?: @[]) {
    if (![ingredientEntry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    MRRSavedRecipeIngredientSnapshot *snapshot = [[[MRRSavedRecipeIngredientSnapshot alloc]
        initWithName:MRRSavedRecipesFirestoreStringValue([ingredientEntry objectForKey:@"name"])
         displayText:MRRSavedRecipesFirestoreStringValue([ingredientEntry objectForKey:@"displayText"])
          orderIndex:MRRSavedRecipesFirestoreIntegerValue([ingredientEntry objectForKey:@"orderIndex"])] autorelease];
    [ingredients addObject:snapshot];
  }

  NSArray *instructionEntries = [data objectForKey:MRRSavedRecipesFirestoreKeyInstructions];
  NSMutableArray<MRRSavedRecipeInstructionSnapshot *> *instructions = [NSMutableArray array];
  for (NSDictionary *instructionEntry in instructionEntries ?: @[]) {
    if (![instructionEntry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    MRRSavedRecipeInstructionSnapshot *snapshot = [[[MRRSavedRecipeInstructionSnapshot alloc]
        initWithTitle:MRRSavedRecipesFirestoreStringValue([instructionEntry objectForKey:@"title"])
           detailText:MRRSavedRecipesFirestoreStringValue([instructionEntry objectForKey:@"detailText"])
           orderIndex:MRRSavedRecipesFirestoreIntegerValue([instructionEntry objectForKey:@"orderIndex"])] autorelease];
    [instructions addObject:snapshot];
  }

  NSArray *toolEntries = [data objectForKey:MRRSavedRecipesFirestoreKeyTools];
  NSMutableArray<MRRSavedRecipeStringSnapshot *> *tools = [NSMutableArray array];
  for (NSDictionary *toolEntry in toolEntries ?: @[]) {
    if (![toolEntry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    MRRSavedRecipeStringSnapshot *snapshot = [[[MRRSavedRecipeStringSnapshot alloc]
        initWithValue:MRRSavedRecipesFirestoreStringValue([toolEntry objectForKey:@"value"])
           orderIndex:MRRSavedRecipesFirestoreIntegerValue([toolEntry objectForKey:@"orderIndex"])] autorelease];
    [tools addObject:snapshot];
  }

  NSArray *tagEntries = [data objectForKey:MRRSavedRecipesFirestoreKeyTags];
  NSMutableArray<MRRSavedRecipeStringSnapshot *> *tags = [NSMutableArray array];
  for (NSDictionary *tagEntry in tagEntries ?: @[]) {
    if (![tagEntry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    MRRSavedRecipeStringSnapshot *snapshot = [[[MRRSavedRecipeStringSnapshot alloc]
        initWithValue:MRRSavedRecipesFirestoreStringValue([tagEntry objectForKey:@"value"])
           orderIndex:MRRSavedRecipesFirestoreIntegerValue([tagEntry objectForKey:@"orderIndex"])] autorelease];
    [tags addObject:snapshot];
  }

  MRRSavedRecipeProductContextSnapshot *productContext = nil;
  NSString *productName = MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyProductName]);
  if (productName.length > 0) {
    productContext = [[[MRRSavedRecipeProductContextSnapshot alloc]
        initWithProductName:productName
                  brandText:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyProductBrandText])
         nutritionGradeText:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyProductNutritionGradeText])
               quantityText:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyProductQuantityText])] autorelease];
  }

  return [[[MRRSavedRecipeSnapshot alloc]
          initWithUserID:userID
                recipeID:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyRecipeID]).length > 0
                             ? MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyRecipeID])
                             : document.documentID
                   title:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyTitle])
                subtitle:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeySubtitle])
               assetName:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyAssetName])
      heroImageURLString:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyHeroImageURLString])
             summaryText:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeySummaryText])
                mealType:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyMealType])
              sourceName:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeySourceName])
         sourceURLString:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeySourceURLString])
          readyInMinutes:MRRSavedRecipesFirestoreIntegerValue([data objectForKey:MRRSavedRecipesFirestoreKeyReadyInMinutes])
                servings:MRRSavedRecipesFirestoreIntegerValue([data objectForKey:MRRSavedRecipesFirestoreKeyServings])
            calorieCount:MRRSavedRecipesFirestoreIntegerValue([data objectForKey:MRRSavedRecipesFirestoreKeyCalorieCount])
         popularityScore:MRRSavedRecipesFirestoreIntegerValue([data objectForKey:MRRSavedRecipesFirestoreKeyPopularityScore])
            durationText:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyDurationText])
             calorieText:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyCalorieText])
            servingsText:MRRSavedRecipesFirestoreStringValue([data objectForKey:MRRSavedRecipesFirestoreKeyServingsText])
             ingredients:ingredients
            instructions:instructions
                   tools:tools
                    tags:tags
          productContext:productContext
                 savedAt:MRRSavedRecipesFirestoreDateValue([data objectForKey:MRRSavedRecipesFirestoreKeySavedAt]) ?: [NSDate date]
         localModifiedAt:MRRSavedRecipesFirestoreDateValue([data objectForKey:MRRSavedRecipesFirestoreKeyUpdatedAt]) ?: [NSDate date]
         remoteUpdatedAt:MRRSavedRecipesFirestoreDateValue([data objectForKey:MRRSavedRecipesFirestoreKeyUpdatedAt])] autorelease];
}

- (void)drainNextPendingChangeForUserID:(NSString *)userID completion:(MRRSavedRecipesSyncCompletion)completion {
  NSError *fetchError = nil;
  NSArray<MRRSavedRecipeSyncChange *> *changes = [self.store pendingSyncChangesForUserID:userID error:&fetchError];
  if (fetchError != nil) {
    self.syncInFlight = NO;
    if (completion != nil) {
      completion(fetchError);
    }
    [self completeQueuedCompletionsWithError:fetchError];
    return;
  }

  MRRSavedRecipeSyncChange *change = changes.firstObject;
  if (change == nil) {
    self.syncInFlight = NO;
    if (completion != nil) {
      completion(nil);
    }
    [self completeQueuedCompletionsWithError:nil];
    return;
  }

  FIRDocumentReference *documentReference = [[self savedRecipesCollectionForUserID:userID] documentWithPath:change.recipeID];
  NSDate *remoteUpdatedAt = [NSDate date];

  if (change.operation == MRRSavedRecipeSyncChangeOperationDelete) {
    NSDictionary *payload = @{
      MRRSavedRecipesFirestoreKeyUserID : userID,
      MRRSavedRecipesFirestoreKeyRecipeID : change.recipeID,
      MRRSavedRecipesFirestoreKeyIsDeleted : @YES,
      MRRSavedRecipesFirestoreKeyUpdatedAt : remoteUpdatedAt
    };
    [documentReference setData:payload
                         merge:YES
                    completion:^(NSError *error) {
                      if (error != nil) {
                        self.syncInFlight = NO;
                        if (completion != nil) {
                          completion(error);
                        }
                        [self completeQueuedCompletionsWithError:error];
                        return;
                      }
                      NSError *markError = nil;
                      [self.store markPendingSyncChangeProcessedForUserID:userID
                                                                 recipeID:change.recipeID
                                                          remoteUpdatedAt:remoteUpdatedAt
                                                                    error:&markError];
                      if (markError != nil) {
                        self.syncInFlight = NO;
                        if (completion != nil) {
                          completion(markError);
                        }
                        [self completeQueuedCompletionsWithError:markError];
                        return;
                      }
                      [self drainNextPendingChangeForUserID:userID completion:completion];
                    }];
    return;
  }

  NSError *snapshotError = nil;
  MRRSavedRecipeSnapshot *snapshot = [self.store savedRecipeForUserID:userID recipeID:change.recipeID error:&snapshotError];
  if (snapshotError != nil) {
    self.syncInFlight = NO;
    if (completion != nil) {
      completion(snapshotError);
    }
    [self completeQueuedCompletionsWithError:snapshotError];
    return;
  }
  if (snapshot == nil) {
    NSError *markError = nil;
    [self.store markPendingSyncChangeProcessedForUserID:userID recipeID:change.recipeID remoteUpdatedAt:nil error:&markError];
    if (markError != nil) {
      self.syncInFlight = NO;
      if (completion != nil) {
        completion(markError);
      }
      [self completeQueuedCompletionsWithError:markError];
      return;
    }
    [self drainNextPendingChangeForUserID:userID completion:completion];
    return;
  }

  NSDictionary *payload = [self firestorePayloadForSnapshot:snapshot updatedAt:remoteUpdatedAt];
  [documentReference setData:payload
                       merge:YES
                  completion:^(NSError *error) {
                    if (error != nil) {
                      self.syncInFlight = NO;
                      if (completion != nil) {
                        completion(error);
                      }
                      [self completeQueuedCompletionsWithError:error];
                      return;
                    }
                    NSError *markError = nil;
                    [self.store markPendingSyncChangeProcessedForUserID:userID
                                                               recipeID:change.recipeID
                                                        remoteUpdatedAt:remoteUpdatedAt
                                                                  error:&markError];
                    if (markError != nil) {
                      self.syncInFlight = NO;
                      if (completion != nil) {
                        completion(markError);
                      }
                      [self completeQueuedCompletionsWithError:markError];
                      return;
                    }
                    [self drainNextPendingChangeForUserID:userID completion:completion];
                  }];
}

- (void)completeQueuedCompletionsWithError:(NSError *)error {
  NSArray *completions = [[self.pendingCompletions copy] autorelease];
  [self.pendingCompletions removeAllObjects];
  for (id completionObject in completions) {
    MRRSavedRecipesSyncCompletion completion = completionObject;
    completion(error);
  }
}

- (void)handleRemoteSnapshot:(FIRQuerySnapshot *)snapshot userID:(NSString *)userID {
  for (FIRDocumentSnapshot *document in snapshot.documents) {
    if (document.metadata.hasPendingWrites) {
      continue;
    }
    NSDictionary *data = document.data;
    if (![data isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSDate *remoteUpdatedAt = MRRSavedRecipesFirestoreDateValue([data objectForKey:MRRSavedRecipesFirestoreKeyUpdatedAt]) ?: [NSDate date];
    BOOL isDeleted = [[data objectForKey:MRRSavedRecipesFirestoreKeyIsDeleted] boolValue];
    if (isDeleted) {
      [self.store applyRemoteDeletionForUserID:userID recipeID:document.documentID remoteUpdatedAt:remoteUpdatedAt error:nil];
      continue;
    }
    MRRSavedRecipeSnapshot *recipeSnapshot = [self snapshotFromDocument:document userID:userID];
    if (recipeSnapshot == nil) {
      continue;
    }
    [self.store applyRemoteSnapshot:recipeSnapshot remoteUpdatedAt:remoteUpdatedAt error:nil];
  }
}

@end
