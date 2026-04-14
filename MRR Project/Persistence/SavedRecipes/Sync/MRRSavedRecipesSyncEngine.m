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

@class MRRSavedRecipesSyncEngine;

@interface MRRSavedRecipesSyncEngineTargetBox : NSObject

@property(nonatomic, assign, nullable) MRRSavedRecipesSyncEngine *target;

@end

@implementation MRRSavedRecipesSyncEngineTargetBox
@end

@interface MRRSavedRecipesSyncEngine ()

@property(nonatomic, retain) MRRSavedRecipesStore *store;
@property(nonatomic, retain) FIRFirestore *firestore;
@property(nonatomic, retain, nullable) id<FIRListenerRegistration> listenerRegistration;
@property(nonatomic, copy, nullable) NSString *activeUserID;
@property(nonatomic, retain) NSMutableArray *pendingCompletions;
@property(nonatomic, retain) MRRSavedRecipesSyncEngineTargetBox *listenerTargetBox;
@property(nonatomic, assign) BOOL syncInFlight;
@property(nonatomic, assign) BOOL cloudSyncDisabled;
@property(nonatomic, retain, nullable) dispatch_source_t flushTimeoutTimer;

- (FIRCollectionReference *)savedRecipesCollectionForUserID:(NSString *)userID;
- (NSDictionary<NSString *, id> *)firestorePayloadForSnapshot:(MRRSavedRecipeSnapshot *)snapshot updatedAt:(NSDate *)updatedAt;
- (nullable MRRSavedRecipeSnapshot *)snapshotFromDocument:(FIRDocumentSnapshot *)document userID:(NSString *)userID;
- (void)drainNextPendingChangeForUserID:(NSString *)userID completion:(nullable MRRSavedRecipesSyncCompletion)completion;
- (void)completeQueuedCompletionsWithError:(nullable NSError *)error;
- (void)handleRemoteSnapshot:(FIRQuerySnapshot *)snapshot userID:(NSString *)userID;
- (void)scheduleFlushTimeoutWithUserID:(NSString *)userID;
- (void)cancelFlushTimeout;
- (void)flushTimedOut;
- (BOOL)shouldFallbackToLocalModeForError:(nullable NSError *)error;
- (void)disableCloudSyncForError:(NSError *)error context:(NSString *)context completePendingFlushes:(BOOL)completePendingFlushes;

@end

@implementation MRRSavedRecipesSyncEngine

static NSString *const MRRSavedRecipesSyncLogPrefix = @"[SavedRecipesSync]";
static NSString *const MRRFirestoreUnavailableMessageFragment = @"Cloud Firestore API has not been used in project";
static NSString *const MRRFirestoreAPIMessageFragment = @"firestore.googleapis.com";

static FIRFirestore *MRRSavedRecipesCreateFirestoreSafely(void) {
  @try {
    return [FIRFirestore firestore];
  } @catch (NSException *exception) {
    NSLog(@"%@ Firestore unavailable before FirebaseApp.configure(). Falling back to local-only mode. exception=%@",
          MRRSavedRecipesSyncLogPrefix, exception.reason ?: exception.name);
    return nil;
  }
}

- (instancetype)initWithStore:(MRRSavedRecipesStore *)store {
  NSParameterAssert(store != nil);

  self = [super init];
  if (self) {
    _store = [store retain];
    _firestore = [MRRSavedRecipesCreateFirestoreSafely() retain];
    _pendingCompletions = [[NSMutableArray alloc] init];
    _listenerTargetBox = [[MRRSavedRecipesSyncEngineTargetBox alloc] init];
    _listenerTargetBox.target = self;

    if (_firestore == nil) {
      _cloudSyncDisabled = YES;
    } else {
      FIRFirestoreSettings *settings = [[[_firestore settings] copy] autorelease];
      if (settings == nil) {
        settings = [[[FIRFirestoreSettings alloc] init] autorelease];
      }
      if (![settings.cacheSettings isKindOfClass:[FIRMemoryCacheSettings class]]) {
        settings.cacheSettings = [[[FIRMemoryCacheSettings alloc] init] autorelease];
        @try {
          _firestore.settings = settings;
        } @catch (__unused NSException *exception) {
        }
      }
    }
  }
  return self;
}

- (void)dealloc {
  self.listenerTargetBox.target = nil;
  [self.listenerRegistration remove];
  [self cancelFlushTimeout];
  [_flushTimeoutTimer release];
  [_listenerTargetBox release];
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
  if (self.cloudSyncDisabled) {
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
  MRRSavedRecipesSyncEngineTargetBox *targetBox = [[self.listenerTargetBox retain] autorelease];
  [collection getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
    MRRSavedRecipesSyncEngine *target = targetBox.target;
    if (target != nil && [target shouldFallbackToLocalModeForError:error]) {
      [target disableCloudSyncForError:error context:@"initial fetch" completePendingFlushes:NO];
      if (completion != nil) {
        completion(nil);
      }
      return;
    }
    if (target != nil && error == nil && snapshot != nil) {
      [target handleRemoteSnapshot:snapshot userID:userID];
    }
    if (completion != nil) {
      completion(error);
    }
  }];

  self.listenerRegistration = [[collection addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
    MRRSavedRecipesSyncEngine *target = targetBox.target;
    if (target == nil) {
      return;
    }
    if ([target shouldFallbackToLocalModeForError:error]) {
      [target disableCloudSyncForError:error context:@"listener" completePendingFlushes:YES];
      return;
    }
    if (error != nil || snapshot == nil) {
      return;
    }

    [target handleRemoteSnapshot:snapshot userID:userID];
  }] retain];

  [self requestImmediateSyncForUserID:userID];
}

- (void)stopSync {
  [self.listenerRegistration remove];
  self.listenerRegistration = nil;
  self.activeUserID = nil;
  [self.pendingCompletions removeAllObjects];
  self.syncInFlight = NO;
  [self cancelFlushTimeout];
}

- (void)requestImmediateSyncForUserID:(NSString *)userID {
  [self flushPendingChangesForUserID:userID completion:nil];
}

static const NSTimeInterval MRRSavedRecipesFlushTimeoutSeconds = 30.0;

- (void)scheduleFlushTimeoutWithUserID:(NSString *)userID {
  [self cancelFlushTimeout];

  __block NSString *capturedUserID = [userID copy];
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  if (timer == nil) {
    [capturedUserID release];
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MRRSavedRecipesFlushTimeoutSeconds * NSEC_PER_SEC)),
                           DISPATCH_TIME_FOREVER, (1ull * NSEC_PER_SEC));
  dispatch_source_set_event_handler(timer, ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf == nil) {
      return;
    }
    if (strongSelf.syncInFlight) {
      [strongSelf flushTimedOut];
    }
    [strongSelf cancelFlushTimeout];
    [capturedUserID release];
  });

  self.flushTimeoutTimer = timer;
  dispatch_resume(timer);
}

- (void)cancelFlushTimeout {
  if (self.flushTimeoutTimer != nil) {
    dispatch_source_cancel(self.flushTimeoutTimer);
    self.flushTimeoutTimer = nil;
  }
}

- (void)flushTimedOut {
  self.syncInFlight = NO;
  NSError *timeoutError = [NSError errorWithDomain:@"MRRSavedRecipesSyncEngine"
                                               code:-2001
                                           userInfo:@{NSLocalizedDescriptionKey : @"Sync flush timed out. Proceeding with logout."}];
  [self completeQueuedCompletionsWithError:timeoutError];
}

- (void)flushPendingChangesForUserID:(NSString *)userID completion:(MRRSavedRecipesSyncCompletion)completion {
  if (userID.length == 0) {
    if (completion != nil) {
      completion(nil);
    }
    return;
  }
  if (self.cloudSyncDisabled) {
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
  [self scheduleFlushTimeoutWithUserID:userID];
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
                        if ([self shouldFallbackToLocalModeForError:error]) {
                          [self disableCloudSyncForError:error context:@"delete flush" completePendingFlushes:YES];
                          return;
                        }
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
                      if ([self shouldFallbackToLocalModeForError:error]) {
                        [self disableCloudSyncForError:error context:@"upsert flush" completePendingFlushes:YES];
                        return;
                      }
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
  [self cancelFlushTimeout];
  NSArray *completions = [[self.pendingCompletions copy] autorelease];
  [self.pendingCompletions removeAllObjects];
  for (id completionObject in completions) {
    MRRSavedRecipesSyncCompletion completion = completionObject;
    completion(error);
  }
}

- (BOOL)shouldFallbackToLocalModeForError:(NSError *)error {
  if (error == nil) {
    return NO;
  }

  if ([error.domain isEqualToString:FIRFirestoreErrorDomain]) {
    return (error.code == FIRFirestoreErrorCodeUnavailable || error.code == FIRFirestoreErrorCodeFailedPrecondition ||
            error.code == FIRFirestoreErrorCodeUnimplemented);
  }

  NSString *description = error.localizedDescription ?: @"";
  return ([description rangeOfString:MRRFirestoreUnavailableMessageFragment options:NSCaseInsensitiveSearch].location != NSNotFound ||
          [description rangeOfString:MRRFirestoreAPIMessageFragment options:NSCaseInsensitiveSearch].location != NSNotFound);
}

- (void)disableCloudSyncForError:(NSError *)error context:(NSString *)context completePendingFlushes:(BOOL)completePendingFlushes {
  if (!self.cloudSyncDisabled) {
    NSLog(@"%@ Firestore unavailable during %@. Switching to local-only mode. domain=%@ code=%ld description=%@",
          MRRSavedRecipesSyncLogPrefix, context, error.domain ?: @"(nil)", (long)error.code, error.localizedDescription ?: @"");
  }
  self.cloudSyncDisabled = YES;
  [self.listenerRegistration remove];
  self.listenerRegistration = nil;
  self.activeUserID = nil;
  self.syncInFlight = NO;
  [self cancelFlushTimeout];
  if (completePendingFlushes) {
    [self completeQueuedCompletionsWithError:nil];
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
