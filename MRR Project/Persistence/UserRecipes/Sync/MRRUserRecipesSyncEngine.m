#import "MRRUserRecipesSyncEngine.h"

@import FirebaseFirestore;

#import "../MRRUserRecipesStore.h"

static NSString *const MRRUserRecipesFirestoreCollectionUsers = @"users";
static NSString *const MRRUserRecipesFirestoreCollectionYourRecipes = @"yourRecipes";

static NSString *const MRRUserRecipesFirestoreKeyAssetName = @"assetName";
static NSString *const MRRUserRecipesFirestoreKeyCalorieCount = @"calorieCount";
static NSString *const MRRUserRecipesFirestoreKeyCreatedAt = @"createdAt";
static NSString *const MRRUserRecipesFirestoreKeyHeroImageURLString = @"heroImageURLString";
static NSString *const MRRUserRecipesFirestoreKeyIngredients = @"ingredients";
static NSString *const MRRUserRecipesFirestoreKeyInstructions = @"instructions";
static NSString *const MRRUserRecipesFirestoreKeyIsDeleted = @"isDeleted";
static NSString *const MRRUserRecipesFirestoreKeyMealType = @"mealType";
static NSString *const MRRUserRecipesFirestoreKeyPhotoURLStrings = @"photoURLStrings";
static NSString *const MRRUserRecipesFirestoreKeyReadyInMinutes = @"readyInMinutes";
static NSString *const MRRUserRecipesFirestoreKeyRecipeID = @"recipeID";
static NSString *const MRRUserRecipesFirestoreKeyServings = @"servings";
static NSString *const MRRUserRecipesFirestoreKeySubtitle = @"subtitle";
static NSString *const MRRUserRecipesFirestoreKeySummaryText = @"summaryText";
static NSString *const MRRUserRecipesFirestoreKeyTags = @"tags";
static NSString *const MRRUserRecipesFirestoreKeyTitle = @"title";
static NSString *const MRRUserRecipesFirestoreKeyTools = @"tools";
static NSString *const MRRUserRecipesFirestoreKeyUpdatedAt = @"updatedAt";
static NSString *const MRRUserRecipesFirestoreKeyUserID = @"userID";

static NSArray<NSDictionary<NSString *, id> *> *MRRUserRecipesFirestoreIngredientPayload(NSArray<MRRUserRecipeIngredientSnapshot *> *ingredients) {
  NSMutableArray<NSDictionary<NSString *, id> *> *payload = [NSMutableArray arrayWithCapacity:ingredients.count];
  for (MRRUserRecipeIngredientSnapshot *ingredient in ingredients) {
    [payload addObject:@{@"name" : ingredient.name ?: @"", @"displayText" : ingredient.displayText ?: @"", @"orderIndex" : @(ingredient.orderIndex)}];
  }
  return payload;
}

static NSArray<NSDictionary<NSString *, id> *> *MRRUserRecipesFirestoreInstructionPayload(NSArray<MRRUserRecipeInstructionSnapshot *> *instructions) {
  NSMutableArray<NSDictionary<NSString *, id> *> *payload = [NSMutableArray arrayWithCapacity:instructions.count];
  for (MRRUserRecipeInstructionSnapshot *instruction in instructions) {
    [payload addObject:@{
      @"title" : instruction.title ?: @"",
      @"detailText" : instruction.detailText ?: @"",
      @"orderIndex" : @(instruction.orderIndex)
    }];
  }
  return payload;
}

static NSArray<NSDictionary<NSString *, id> *> *MRRUserRecipesFirestoreStringPayload(NSArray<MRRUserRecipeStringSnapshot *> *values) {
  NSMutableArray<NSDictionary<NSString *, id> *> *payload = [NSMutableArray arrayWithCapacity:values.count];
  for (MRRUserRecipeStringSnapshot *value in values) {
    [payload addObject:@{@"value" : value.value ?: @"", @"orderIndex" : @(value.orderIndex)}];
  }
  return payload;
}

static NSString *MRRUserRecipesFirestoreStringValue(id candidate);

static NSString *MRRUserRecipesTrimmedString(id candidate) {
  return [MRRUserRecipesFirestoreStringValue(candidate) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSArray<NSString *> *MRRUserRecipesFirestorePhotoURLPayload(NSArray<MRRUserRecipePhotoSnapshot *> *photos) {
  NSMutableArray<NSString *> *payload = [NSMutableArray array];
  for (MRRUserRecipePhotoSnapshot *photo in photos ?: @[]) {
    NSString *remoteURLString = MRRUserRecipesTrimmedString(photo.remoteURLString ?: @"");
    if (remoteURLString.length == 0) {
      continue;
    }
    [payload addObject:remoteURLString];
  }
  return payload;
}

static NSDate *MRRUserRecipesFirestoreDateValue(id candidate) {
  if ([candidate isKindOfClass:[NSDate class]]) {
    return (NSDate *)candidate;
  }
  if ([candidate isKindOfClass:[FIRTimestamp class]]) {
    return [(FIRTimestamp *)candidate dateValue];
  }
  return nil;
}

static NSString *MRRUserRecipesFirestoreStringValue(id candidate) {
  if (![candidate isKindOfClass:[NSString class]]) {
    return @"";
  }
  return (NSString *)candidate;
}

static NSInteger MRRUserRecipesFirestoreIntegerValue(id candidate) {
  if ([candidate respondsToSelector:@selector(integerValue)]) {
    return [candidate integerValue];
  }
  return 0;
}

@class MRRUserRecipesSyncEngine;

@interface MRRUserRecipesSyncEngineTargetBox : NSObject

@property(nonatomic, assign, nullable) MRRUserRecipesSyncEngine *target;

@end

@implementation MRRUserRecipesSyncEngineTargetBox
@end

@interface MRRUserRecipesSyncEngine ()

@property(nonatomic, retain) MRRUserRecipesStore *store;
@property(nonatomic, retain) FIRFirestore *firestore;
@property(nonatomic, retain, nullable) id<FIRListenerRegistration> listenerRegistration;
@property(nonatomic, copy, nullable) NSString *activeUserID;
@property(nonatomic, retain) NSMutableArray *pendingCompletions;
@property(nonatomic, retain) MRRUserRecipesSyncEngineTargetBox *listenerTargetBox;
@property(nonatomic, assign) BOOL syncInFlight;
@property(nonatomic, assign) BOOL cloudSyncDisabled;
@property(nonatomic, retain, nullable) dispatch_source_t flushTimeoutTimer;

- (FIRCollectionReference *)userRecipesCollectionForUserID:(NSString *)userID;
- (NSDictionary<NSString *, id> *)firestorePayloadForSnapshot:(MRRUserRecipeSnapshot *)snapshot updatedAt:(NSDate *)updatedAt;
- (nullable MRRUserRecipeSnapshot *)snapshotFromDocument:(FIRDocumentSnapshot *)document userID:(NSString *)userID;
- (nullable MRRUserRecipeSnapshot *)snapshotFromDictionary:(NSDictionary<NSString *, id> *)data
                                                    userID:(NSString *)userID
                                                documentID:(NSString *)documentID;
- (void)drainNextPendingChangeForUserID:(NSString *)userID completion:(nullable MRRUserRecipesSyncCompletion)completion;
- (void)completeQueuedCompletionsWithError:(nullable NSError *)error;
- (void)handleRemoteSnapshot:(FIRQuerySnapshot *)snapshot userID:(NSString *)userID;
- (void)scheduleFlushTimeoutWithUserID:(NSString *)userID;
- (void)cancelFlushTimeout;
- (void)flushTimedOut;
- (BOOL)shouldFallbackToLocalModeForError:(nullable NSError *)error;
- (void)disableCloudSyncForError:(NSError *)error context:(NSString *)context completePendingFlushes:(BOOL)completePendingFlushes;

@end

@implementation MRRUserRecipesSyncEngine

static NSString *const MRRUserRecipesSyncLogPrefix = @"[UserRecipesSync]";
static NSString *const MRRUserRecipesFirestoreUnavailableMessageFragment = @"Cloud Firestore API has not been used in project";
static NSString *const MRRUserRecipesFirestoreAPIMessageFragment = @"firestore.googleapis.com";

static FIRFirestore *MRRUserRecipesCreateFirestoreSafely(void) {
  @try {
    return [FIRFirestore firestore];
  } @catch (NSException *exception) {
    NSLog(@"%@ Firestore unavailable before FirebaseApp.configure(). Falling back to local-only mode. exception=%@",
          MRRUserRecipesSyncLogPrefix, exception.reason ?: exception.name);
    return nil;
  }
}

- (instancetype)initWithStore:(MRRUserRecipesStore *)store {
  return [self initWithStore:store firestore:nil];
}

- (instancetype)initWithStore:(MRRUserRecipesStore *)store firestore:(FIRFirestore *)firestore {
  NSParameterAssert(store != nil);

  self = [super init];
  if (self) {
    _store = [store retain];
    FIRFirestore *resolvedFirestore = firestore;
    if (resolvedFirestore == nil) {
      resolvedFirestore = MRRUserRecipesCreateFirestoreSafely();
    }
    _firestore = [resolvedFirestore retain];
    _pendingCompletions = [[NSMutableArray alloc] init];
    _listenerTargetBox = [[MRRUserRecipesSyncEngineTargetBox alloc] init];
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

- (void)startSyncForUserID:(NSString *)userID completion:(MRRUserRecipesSyncCompletion)completion {
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

  FIRCollectionReference *collection = [self userRecipesCollectionForUserID:userID];
  MRRUserRecipesSyncEngineTargetBox *targetBox = [[self.listenerTargetBox retain] autorelease];
  [collection getDocumentsWithCompletion:^(FIRQuerySnapshot *snapshot, NSError *error) {
    MRRUserRecipesSyncEngine *target = targetBox.target;
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
    MRRUserRecipesSyncEngine *target = targetBox.target;
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

static const NSTimeInterval MRRUserRecipesFlushTimeoutSeconds = 30.0;

- (void)scheduleFlushTimeoutWithUserID:(NSString *)userID {
  [self cancelFlushTimeout];

  __block NSString *capturedUserID = [userID copy];
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  if (timer == nil) {
    [capturedUserID release];
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MRRUserRecipesFlushTimeoutSeconds * NSEC_PER_SEC)),
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
  NSError *timeoutError = [NSError errorWithDomain:@"MRRUserRecipesSyncEngine"
                                               code:-2001
                                           userInfo:@{NSLocalizedDescriptionKey : @"User recipes sync flush timed out. Proceeding with logout."}];
  [self completeQueuedCompletionsWithError:timeoutError];
}

- (void)flushPendingChangesForUserID:(NSString *)userID completion:(MRRUserRecipesSyncCompletion)completion {
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

- (FIRCollectionReference *)userRecipesCollectionForUserID:(NSString *)userID {
  FIRCollectionReference *usersCollection = [self.firestore collectionWithPath:MRRUserRecipesFirestoreCollectionUsers];
  FIRDocumentReference *userDocument = [usersCollection documentWithPath:userID];
  return [userDocument collectionWithPath:MRRUserRecipesFirestoreCollectionYourRecipes];
}

- (NSDictionary<NSString *, id> *)firestorePayloadForSnapshot:(MRRUserRecipeSnapshot *)snapshot updatedAt:(NSDate *)updatedAt {
  NSMutableDictionary<NSString *, id> *payload = [NSMutableDictionary dictionary];
  payload[MRRUserRecipesFirestoreKeyUserID] = snapshot.userID;
  payload[MRRUserRecipesFirestoreKeyRecipeID] = snapshot.recipeID;
  payload[MRRUserRecipesFirestoreKeyTitle] = snapshot.title;
  payload[MRRUserRecipesFirestoreKeySubtitle] = snapshot.subtitle;
  payload[MRRUserRecipesFirestoreKeySummaryText] = snapshot.summaryText;
  payload[MRRUserRecipesFirestoreKeyMealType] = snapshot.mealType;
  payload[MRRUserRecipesFirestoreKeyReadyInMinutes] = @(snapshot.readyInMinutes);
  payload[MRRUserRecipesFirestoreKeyServings] = @(snapshot.servings);
  payload[MRRUserRecipesFirestoreKeyCalorieCount] = @(snapshot.calorieCount);
  payload[MRRUserRecipesFirestoreKeyAssetName] = snapshot.assetName;
  payload[MRRUserRecipesFirestoreKeyCreatedAt] = snapshot.createdAt;
  payload[MRRUserRecipesFirestoreKeyUpdatedAt] = updatedAt;
  payload[MRRUserRecipesFirestoreKeyIsDeleted] = @NO;
  payload[MRRUserRecipesFirestoreKeyIngredients] = MRRUserRecipesFirestoreIngredientPayload(snapshot.ingredients);
  payload[MRRUserRecipesFirestoreKeyInstructions] = MRRUserRecipesFirestoreInstructionPayload(snapshot.instructions);
  payload[MRRUserRecipesFirestoreKeyTools] = MRRUserRecipesFirestoreStringPayload(snapshot.tools);
  payload[MRRUserRecipesFirestoreKeyTags] = MRRUserRecipesFirestoreStringPayload(snapshot.tags);
  NSArray<NSString *> *photoURLStrings = MRRUserRecipesFirestorePhotoURLPayload(snapshot.photos);
  if (photoURLStrings.count > 0) {
    payload[MRRUserRecipesFirestoreKeyPhotoURLStrings] = photoURLStrings;
    payload[MRRUserRecipesFirestoreKeyHeroImageURLString] = photoURLStrings.firstObject;
  } else if (snapshot.heroImageURLString.length > 0) {
    payload[MRRUserRecipesFirestoreKeyHeroImageURLString] = snapshot.heroImageURLString;
  }
  return payload;
}

- (MRRUserRecipeSnapshot *)snapshotFromDocument:(FIRDocumentSnapshot *)document userID:(NSString *)userID {
  NSDictionary *data = document.data;
  if (![data isKindOfClass:[NSDictionary class]]) {
    return nil;
  }
  return [self snapshotFromDictionary:data userID:userID documentID:document.documentID];
}

- (MRRUserRecipeSnapshot *)snapshotFromDictionary:(NSDictionary<NSString *, id> *)data userID:(NSString *)userID documentID:(NSString *)documentID {
  NSArray *photoURLStringEntries = [data objectForKey:MRRUserRecipesFirestoreKeyPhotoURLStrings];
  NSMutableArray<MRRUserRecipePhotoSnapshot *> *photos = [NSMutableArray array];
  NSInteger photoOrderIndex = 0;
  for (NSString *photoURLStringEntry in photoURLStringEntries ?: @[]) {
    NSString *remoteURLString = MRRUserRecipesFirestoreStringValue(photoURLStringEntry);
    if (remoteURLString.length == 0) {
      continue;
    }
    NSString *photoIdentifier = [NSString stringWithFormat:@"%@.photo.%ld", documentID.length > 0 ? documentID : @"remote", (long)photoOrderIndex];
    MRRUserRecipePhotoSnapshot *photoSnapshot = [[[MRRUserRecipePhotoSnapshot alloc] initWithPhotoID:photoIdentifier
                                                                                          orderIndex:photoOrderIndex
                                                                                     remoteURLString:remoteURLString
                                                                                   localRelativePath:nil] autorelease];
    [photos addObject:photoSnapshot];
    photoOrderIndex += 1;
  }

  NSArray *ingredientEntries = [data objectForKey:MRRUserRecipesFirestoreKeyIngredients];
  NSMutableArray<MRRUserRecipeIngredientSnapshot *> *ingredients = [NSMutableArray array];
  for (NSDictionary *ingredientEntry in ingredientEntries ?: @[]) {
    if (![ingredientEntry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSString *name = MRRUserRecipesFirestoreStringValue([ingredientEntry objectForKey:@"name"]);
    NSString *displayText = MRRUserRecipesFirestoreStringValue([ingredientEntry objectForKey:@"displayText"]);
    if (name.length == 0 || displayText.length == 0) {
      continue;
    }
    MRRUserRecipeIngredientSnapshot *snapshot = [[[MRRUserRecipeIngredientSnapshot alloc]
        initWithName:name
         displayText:displayText
          orderIndex:MRRUserRecipesFirestoreIntegerValue([ingredientEntry objectForKey:@"orderIndex"])] autorelease];
    [ingredients addObject:snapshot];
  }

  NSArray *instructionEntries = [data objectForKey:MRRUserRecipesFirestoreKeyInstructions];
  NSMutableArray<MRRUserRecipeInstructionSnapshot *> *instructions = [NSMutableArray array];
  for (NSDictionary *instructionEntry in instructionEntries ?: @[]) {
    if (![instructionEntry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSString *title = MRRUserRecipesFirestoreStringValue([instructionEntry objectForKey:@"title"]);
    NSString *detailText = MRRUserRecipesFirestoreStringValue([instructionEntry objectForKey:@"detailText"]);
    if (title.length == 0 || detailText.length == 0) {
      continue;
    }
    MRRUserRecipeInstructionSnapshot *snapshot = [[[MRRUserRecipeInstructionSnapshot alloc]
        initWithTitle:title
           detailText:detailText
           orderIndex:MRRUserRecipesFirestoreIntegerValue([instructionEntry objectForKey:@"orderIndex"])] autorelease];
    [instructions addObject:snapshot];
  }

  NSArray *toolEntries = [data objectForKey:MRRUserRecipesFirestoreKeyTools];
  NSMutableArray<MRRUserRecipeStringSnapshot *> *tools = [NSMutableArray array];
  for (NSDictionary *toolEntry in toolEntries ?: @[]) {
    if (![toolEntry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSString *value = MRRUserRecipesFirestoreStringValue([toolEntry objectForKey:@"value"]);
    if (value.length == 0) {
      continue;
    }
    MRRUserRecipeStringSnapshot *snapshot =
        [[[MRRUserRecipeStringSnapshot alloc] initWithValue:value
                                                 orderIndex:MRRUserRecipesFirestoreIntegerValue([toolEntry objectForKey:@"orderIndex"])] autorelease];
    [tools addObject:snapshot];
  }

  NSArray *tagEntries = [data objectForKey:MRRUserRecipesFirestoreKeyTags];
  NSMutableArray<MRRUserRecipeStringSnapshot *> *tags = [NSMutableArray array];
  for (NSDictionary *tagEntry in tagEntries ?: @[]) {
    if (![tagEntry isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSString *value = MRRUserRecipesFirestoreStringValue([tagEntry objectForKey:@"value"]);
    if (value.length == 0) {
      continue;
    }
    MRRUserRecipeStringSnapshot *snapshot =
        [[[MRRUserRecipeStringSnapshot alloc] initWithValue:value
                                                 orderIndex:MRRUserRecipesFirestoreIntegerValue([tagEntry objectForKey:@"orderIndex"])] autorelease];
    [tags addObject:snapshot];
  }

  NSString *resolvedRecipeID = MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeyRecipeID]).length > 0
                                   ? MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeyRecipeID])
                                   : documentID;
  NSString *resolvedHeroImageURLString = photos.count > 0
                                             ? photos.firstObject.remoteURLString
                                             : MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeyHeroImageURLString]);

  return [[[MRRUserRecipeSnapshot alloc]
          initWithUserID:userID
                recipeID:resolvedRecipeID
                   title:MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeyTitle])
                subtitle:MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeySubtitle])
             summaryText:MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeySummaryText])
                mealType:MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeyMealType])
          readyInMinutes:MRRUserRecipesFirestoreIntegerValue([data objectForKey:MRRUserRecipesFirestoreKeyReadyInMinutes])
                servings:MRRUserRecipesFirestoreIntegerValue([data objectForKey:MRRUserRecipesFirestoreKeyServings])
            calorieCount:MRRUserRecipesFirestoreIntegerValue([data objectForKey:MRRUserRecipesFirestoreKeyCalorieCount])
               assetName:MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeyAssetName]).length > 0
                             ? MRRUserRecipesFirestoreStringValue([data objectForKey:MRRUserRecipesFirestoreKeyAssetName])
                             : [MRRUserRecipeSnapshot defaultAssetName]
      heroImageURLString:resolvedHeroImageURLString
                  photos:photos
             ingredients:ingredients
            instructions:instructions
                   tools:tools
                    tags:tags
               createdAt:MRRUserRecipesFirestoreDateValue([data objectForKey:MRRUserRecipesFirestoreKeyCreatedAt]) ?: [NSDate date]
         localModifiedAt:MRRUserRecipesFirestoreDateValue([data objectForKey:MRRUserRecipesFirestoreKeyUpdatedAt]) ?: [NSDate date]
         remoteUpdatedAt:MRRUserRecipesFirestoreDateValue([data objectForKey:MRRUserRecipesFirestoreKeyUpdatedAt])] autorelease];
}

- (void)drainNextPendingChangeForUserID:(NSString *)userID completion:(MRRUserRecipesSyncCompletion)completion {
  NSError *fetchError = nil;
  NSArray<MRRUserRecipeSyncChange *> *changes = [self.store pendingSyncChangesForUserID:userID error:&fetchError];
  if (fetchError != nil) {
    self.syncInFlight = NO;
    if (completion != nil) {
      completion(fetchError);
    }
    [self completeQueuedCompletionsWithError:fetchError];
    return;
  }

  MRRUserRecipeSyncChange *change = changes.firstObject;
  if (change == nil) {
    self.syncInFlight = NO;
    if (completion != nil) {
      completion(nil);
    }
    [self completeQueuedCompletionsWithError:nil];
    return;
  }

  FIRDocumentReference *documentReference = [[self userRecipesCollectionForUserID:userID] documentWithPath:change.recipeID];
  NSDate *remoteUpdatedAt = [NSDate date];

  if (change.operation == MRRUserRecipeSyncChangeOperationDelete) {
    NSDictionary *payload = @{
      MRRUserRecipesFirestoreKeyUserID : userID,
      MRRUserRecipesFirestoreKeyRecipeID : change.recipeID,
      MRRUserRecipesFirestoreKeyIsDeleted : @YES,
      MRRUserRecipesFirestoreKeyUpdatedAt : remoteUpdatedAt
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
  MRRUserRecipeSnapshot *snapshot = [self.store userRecipeForUserID:userID recipeID:change.recipeID error:&snapshotError];
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
    MRRUserRecipesSyncCompletion completion = completionObject;
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
  return ([description rangeOfString:MRRUserRecipesFirestoreUnavailableMessageFragment options:NSCaseInsensitiveSearch].location != NSNotFound ||
          [description rangeOfString:MRRUserRecipesFirestoreAPIMessageFragment options:NSCaseInsensitiveSearch].location != NSNotFound);
}

- (void)disableCloudSyncForError:(NSError *)error context:(NSString *)context completePendingFlushes:(BOOL)completePendingFlushes {
  if (!self.cloudSyncDisabled) {
    NSLog(@"%@ Firestore unavailable during %@. Switching to local-only mode. domain=%@ code=%ld description=%@",
          MRRUserRecipesSyncLogPrefix, context, error.domain ?: @"(nil)", (long)error.code, error.localizedDescription ?: @"");
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
    NSDate *remoteUpdatedAt = MRRUserRecipesFirestoreDateValue([data objectForKey:MRRUserRecipesFirestoreKeyUpdatedAt]) ?: [NSDate date];
    BOOL isDeleted = [[data objectForKey:MRRUserRecipesFirestoreKeyIsDeleted] boolValue];
    if (isDeleted) {
      [self.store applyRemoteDeletionForUserID:userID recipeID:document.documentID remoteUpdatedAt:remoteUpdatedAt error:nil];
      continue;
    }
    MRRUserRecipeSnapshot *recipeSnapshot = [self snapshotFromDocument:document userID:userID];
    if (recipeSnapshot == nil) {
      continue;
    }
    [self.store applyRemoteSnapshot:recipeSnapshot remoteUpdatedAt:remoteUpdatedAt error:nil];
  }
}

@end
