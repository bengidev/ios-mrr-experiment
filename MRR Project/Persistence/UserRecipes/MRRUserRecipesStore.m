#import "MRRUserRecipesStore.h"

#import <CoreData/CoreData.h>

#import "../CoreData/MRRCoreDataStack.h"

NSNotificationName const MRRUserRecipesStoreDidChangeNotification = @"MRRUserRecipesStoreDidChangeNotification";
NSErrorDomain const MRRUserRecipesStoreErrorDomain = @"MRRUserRecipesStoreErrorDomain";

static NSString *const MRRUserRecipeEntityName = @"UserRecipe";
static NSString *const MRRUserRecipePhotoEntityName = @"UserRecipePhoto";
static NSString *const MRRUserRecipeIngredientEntityName = @"UserRecipeIngredient";
static NSString *const MRRUserRecipeInstructionEntityName = @"UserRecipeInstruction";
static NSString *const MRRUserRecipeToolEntityName = @"UserRecipeTool";
static NSString *const MRRUserRecipeTagEntityName = @"UserRecipeTag";
static NSString *const MRRUserRecipeSyncChangeEntityName = @"UserRecipeSyncChange";

static NSString *const MRRUserRecipeRelationshipPhotos = @"photos";
static NSString *const MRRUserRecipeRelationshipIngredients = @"ingredients";
static NSString *const MRRUserRecipeRelationshipInstructions = @"instructions";
static NSString *const MRRUserRecipeRelationshipTools = @"tools";
static NSString *const MRRUserRecipeRelationshipTags = @"tags";

static NSString *const MRRUserRecipeSyncOperationUpsert = @"upsert";
static NSString *const MRRUserRecipeSyncOperationDelete = @"delete";

static void MRRUserRecipesStorePostChangeNotification(id object) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:MRRUserRecipesStoreDidChangeNotification object:object];
  });
}

static NSString *MRRUserRecipesStoreStringValue(id candidate) {
  if (![candidate isKindOfClass:[NSString class]]) {
    return @"";
  }
  return (NSString *)candidate;
}

static NSDate *MRRUserRecipesStoreDateValue(id candidate) {
  if ([candidate isKindOfClass:[NSDate class]]) {
    return (NSDate *)candidate;
  }
  return nil;
}

static NSInteger MRRUserRecipesStoreIntegerValue(id candidate) {
  if ([candidate respondsToSelector:@selector(integerValue)]) {
    return [candidate integerValue];
  }
  return 0;
}

@interface MRRUserRecipesStore ()

@property(nonatomic, retain) MRRCoreDataStack *coreDataStack;

- (nullable NSManagedObject *)recipeManagedObjectForUserID:(NSString *)userID
                                                  recipeID:(NSString *)recipeID
                                                   context:(NSManagedObjectContext *)context
                                                     error:(NSError *_Nullable *_Nullable)error;
- (nullable NSManagedObject *)syncChangeManagedObjectForUserID:(NSString *)userID
                                                      recipeID:(NSString *)recipeID
                                                       context:(NSManagedObjectContext *)context
                                                         error:(NSError *_Nullable *_Nullable)error;
- (BOOL)upsertRecipeManagedObject:(NSManagedObject *)managedObject
                     withSnapshot:(MRRUserRecipeSnapshot *)snapshot
                          context:(NSManagedObjectContext *)context
                     queueForSync:(BOOL)queueForSync
                            error:(NSError *_Nullable *_Nullable)error;
- (void)replaceChildrenForRelationship:(NSString *)relationshipName
                              onRecipe:(NSManagedObject *)recipeManagedObject
                                values:(NSArray *)values
                            entityName:(NSString *)entityName
                            applyBlock:(void (^)(NSManagedObject *childManagedObject, id value))applyBlock
                               context:(NSManagedObjectContext *)context;
- (MRRUserRecipeSnapshot *)snapshotFromRecipeManagedObject:(NSManagedObject *)managedObject;
- (MRRUserRecipeSyncChange *)syncChangeFromManagedObject:(NSManagedObject *)managedObject;
- (void)deleteChildrenForRecipeManagedObject:(NSManagedObject *)managedObject context:(NSManagedObjectContext *)context;

@end

@implementation MRRUserRecipesStore

- (instancetype)initWithCoreDataStack:(MRRCoreDataStack *)coreDataStack {
  NSParameterAssert(coreDataStack != nil);

  self = [super init];
  if (self) {
    _coreDataStack = [coreDataStack retain];
  }
  return self;
}

- (void)dealloc {
  [_coreDataStack release];
  [super dealloc];
}

- (NSArray<MRRUserRecipeSnapshot *> *)userRecipesForUserID:(NSString *)userID error:(NSError **)error {
  __block NSMutableArray<MRRUserRecipeSnapshot *> *snapshots = nil;
  __block NSError *fetchError = nil;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:MRRUserRecipeEntityName] autorelease];
    request.predicate = [NSPredicate predicateWithFormat:@"userID == %@", userID];
    request.sortDescriptors = @[
      [[[NSSortDescriptor alloc] initWithKey:@"localModifiedAt" ascending:NO] autorelease],
      [[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)] autorelease]
    ];
    NSArray<NSManagedObject *> *results = [self.coreDataStack.viewContext executeFetchRequest:request error:&fetchError];
    if (fetchError != nil) {
      [fetchError retain];
      return;
    }
    snapshots = [[NSMutableArray alloc] initWithCapacity:results.count];
    for (NSManagedObject *managedObject in results) {
      [snapshots addObject:[self snapshotFromRecipeManagedObject:managedObject]];
    }
  }];
  if (fetchError != nil && error != NULL) {
    *error = [fetchError autorelease];
  } else if (fetchError != nil) {
    [fetchError autorelease];
  }
  return [snapshots autorelease] ?: @[];
}

- (MRRUserRecipeSnapshot *)userRecipeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError **)error {
  __block MRRUserRecipeSnapshot *snapshot = nil;
  __block NSError *fetchError = nil;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObject *managedObject = [self recipeManagedObjectForUserID:userID
                                                               recipeID:recipeID
                                                                context:self.coreDataStack.viewContext
                                                                  error:&fetchError];
    if (fetchError != nil) {
      [fetchError retain];
      return;
    }
    if (managedObject != nil) {
      snapshot = [[self snapshotFromRecipeManagedObject:managedObject] retain];
    }
  }];
  if (fetchError != nil && error != NULL) {
    *error = [fetchError autorelease];
  } else if (fetchError != nil) {
    [fetchError autorelease];
  }
  return [snapshot autorelease];
}

- (BOOL)saveRecipeSnapshot:(MRRUserRecipeSnapshot *)snapshot error:(NSError **)error {
  __block NSError *saveError = nil;
  __block BOOL didSave = YES;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObjectContext *context = self.coreDataStack.viewContext;
    NSManagedObject *managedObject = [self recipeManagedObjectForUserID:snapshot.userID recipeID:snapshot.recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (managedObject == nil) {
      managedObject = [NSEntityDescription insertNewObjectForEntityForName:MRRUserRecipeEntityName inManagedObjectContext:context];
    }
    didSave = [self upsertRecipeManagedObject:managedObject withSnapshot:snapshot context:context queueForSync:YES error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    didSave = [self.coreDataStack saveViewContextIfNeeded:&saveError];
    if (saveError != nil) {
      [saveError retain];
    }
  }];
  if (didSave) {
    MRRUserRecipesStorePostChangeNotification(self);
  }
  if (saveError != nil && error != NULL) {
    *error = [saveError autorelease];
  } else if (saveError != nil) {
    [saveError autorelease];
  }
  return didSave;
}

- (BOOL)removeRecipeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError **)error {
  __block NSError *saveError = nil;
  __block BOOL didSave = YES;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObjectContext *context = self.coreDataStack.viewContext;
    NSManagedObject *managedObject = [self recipeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (managedObject != nil) {
      [self deleteChildrenForRecipeManagedObject:managedObject context:context];
      [context deleteObject:managedObject];
    }

    NSManagedObject *syncChange = [self syncChangeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (syncChange == nil) {
      syncChange = [NSEntityDescription insertNewObjectForEntityForName:MRRUserRecipeSyncChangeEntityName inManagedObjectContext:context];
      [syncChange setValue:userID forKey:@"userID"];
      [syncChange setValue:recipeID forKey:@"recipeID"];
    }
    [syncChange setValue:MRRUserRecipeSyncOperationDelete forKey:@"operationType"];
    [syncChange setValue:[NSDate date] forKey:@"queuedAt"];

    didSave = [self.coreDataStack saveViewContextIfNeeded:&saveError];
    if (saveError != nil) {
      [saveError retain];
    }
  }];
  if (didSave) {
    MRRUserRecipesStorePostChangeNotification(self);
  }
  if (saveError != nil && error != NULL) {
    *error = [saveError autorelease];
  } else if (saveError != nil) {
    [saveError autorelease];
  }
  return didSave;
}

- (NSArray<MRRUserRecipeSyncChange *> *)pendingSyncChangesForUserID:(NSString *)userID error:(NSError **)error {
  __block NSMutableArray<MRRUserRecipeSyncChange *> *changes = nil;
  __block NSError *fetchError = nil;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:MRRUserRecipeSyncChangeEntityName] autorelease];
    request.predicate = [NSPredicate predicateWithFormat:@"userID == %@", userID];
    request.sortDescriptors = @[ [[[NSSortDescriptor alloc] initWithKey:@"queuedAt" ascending:YES] autorelease] ];
    NSArray<NSManagedObject *> *results = [self.coreDataStack.viewContext executeFetchRequest:request error:&fetchError];
    if (fetchError != nil) {
      [fetchError retain];
      return;
    }
    changes = [[NSMutableArray alloc] initWithCapacity:results.count];
    for (NSManagedObject *managedObject in results) {
      [changes addObject:[self syncChangeFromManagedObject:managedObject]];
    }
  }];
  if (fetchError != nil && error != NULL) {
    *error = [fetchError autorelease];
  } else if (fetchError != nil) {
    [fetchError autorelease];
  }
  return [changes autorelease] ?: @[];
}

- (BOOL)hasPendingSyncChangeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError **)error {
  __block NSError *fetchError = nil;
  __block BOOL found = NO;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObject *managedObject = [self syncChangeManagedObjectForUserID:userID
                                                                   recipeID:recipeID
                                                                    context:self.coreDataStack.viewContext
                                                                      error:&fetchError];
    if (fetchError != nil) {
      [fetchError retain];
      return;
    }
    found = managedObject != nil;
  }];
  if (fetchError != nil && error != NULL) {
    *error = [fetchError autorelease];
  } else if (fetchError != nil) {
    [fetchError autorelease];
  }
  return found;
}

- (BOOL)markPendingSyncChangeProcessedForUserID:(NSString *)userID
                                       recipeID:(NSString *)recipeID
                                remoteUpdatedAt:(NSDate *)remoteUpdatedAt
                                          error:(NSError **)error {
  __block NSError *saveError = nil;
  __block BOOL didSave = YES;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObjectContext *context = self.coreDataStack.viewContext;
    NSManagedObject *syncChange = [self syncChangeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (syncChange != nil) {
      [context deleteObject:syncChange];
    }
    if (remoteUpdatedAt != nil) {
      NSManagedObject *recipeManagedObject = [self recipeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
      if (saveError != nil) {
        [saveError retain];
        didSave = NO;
        return;
      }
      if (recipeManagedObject != nil) {
        [recipeManagedObject setValue:remoteUpdatedAt forKey:@"remoteUpdatedAt"];
      }
    }
    didSave = [self.coreDataStack saveViewContextIfNeeded:&saveError];
    if (saveError != nil) {
      [saveError retain];
    }
  }];
  if (saveError != nil && error != NULL) {
    *error = [saveError autorelease];
  } else if (saveError != nil) {
    [saveError autorelease];
  }
  return didSave;
}

- (BOOL)applyRemoteSnapshot:(MRRUserRecipeSnapshot *)snapshot remoteUpdatedAt:(NSDate *)remoteUpdatedAt error:(NSError **)error {
  __block NSError *saveError = nil;
  __block BOOL didSave = YES;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObjectContext *context = self.coreDataStack.viewContext;
    NSManagedObject *syncChange = [self syncChangeManagedObjectForUserID:snapshot.userID recipeID:snapshot.recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (syncChange != nil) {
      return;
    }

    NSManagedObject *managedObject = [self recipeManagedObjectForUserID:snapshot.userID recipeID:snapshot.recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    NSDate *existingRemoteUpdatedAt = MRRUserRecipesStoreDateValue([managedObject valueForKey:@"remoteUpdatedAt"]);
    if (managedObject != nil && existingRemoteUpdatedAt != nil && [existingRemoteUpdatedAt compare:remoteUpdatedAt] != NSOrderedAscending) {
      return;
    }
    if (managedObject == nil) {
      managedObject = [NSEntityDescription insertNewObjectForEntityForName:MRRUserRecipeEntityName inManagedObjectContext:context];
    }

    MRRUserRecipeSnapshot *snapshotWithRemoteDate = [[[MRRUserRecipeSnapshot alloc] initWithUserID:snapshot.userID
                                                                                          recipeID:snapshot.recipeID
                                                                                             title:snapshot.title
                                                                                          subtitle:snapshot.subtitle
                                                                                       summaryText:snapshot.summaryText
                                                                                          mealType:snapshot.mealType
                                                                                    readyInMinutes:snapshot.readyInMinutes
                                                                                          servings:snapshot.servings
                                                                                      calorieCount:snapshot.calorieCount
                                                                                         assetName:snapshot.assetName
                                                                                heroImageURLString:snapshot.heroImageURLString
                                                                                            photos:snapshot.photos
                                                                                       ingredients:snapshot.ingredients
                                                                                      instructions:snapshot.instructions
                                                                                             tools:snapshot.tools
                                                                                              tags:snapshot.tags
                                                                                         createdAt:snapshot.createdAt
                                                                                   localModifiedAt:remoteUpdatedAt
                                                                                   remoteUpdatedAt:remoteUpdatedAt] autorelease];
    didSave = [self upsertRecipeManagedObject:managedObject withSnapshot:snapshotWithRemoteDate context:context queueForSync:NO error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    didSave = [self.coreDataStack saveViewContextIfNeeded:&saveError];
    if (saveError != nil) {
      [saveError retain];
    }
  }];
  if (didSave) {
    MRRUserRecipesStorePostChangeNotification(self);
  }
  if (saveError != nil && error != NULL) {
    *error = [saveError autorelease];
  } else if (saveError != nil) {
    [saveError autorelease];
  }
  return didSave;
}

- (BOOL)applyRemoteDeletionForUserID:(NSString *)userID
                            recipeID:(NSString *)recipeID
                     remoteUpdatedAt:(NSDate *)remoteUpdatedAt
                               error:(NSError **)error {
  __block NSError *saveError = nil;
  __block BOOL didSave = YES;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObjectContext *context = self.coreDataStack.viewContext;
    NSManagedObject *syncChange = [self syncChangeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (syncChange != nil) {
      return;
    }

    NSManagedObject *managedObject = [self recipeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (managedObject == nil) {
      return;
    }
    NSDate *existingRemoteUpdatedAt = MRRUserRecipesStoreDateValue([managedObject valueForKey:@"remoteUpdatedAt"]);
    if (existingRemoteUpdatedAt != nil && [existingRemoteUpdatedAt compare:remoteUpdatedAt] != NSOrderedAscending) {
      return;
    }
    [self deleteChildrenForRecipeManagedObject:managedObject context:context];
    [context deleteObject:managedObject];
    didSave = [self.coreDataStack saveViewContextIfNeeded:&saveError];
    if (saveError != nil) {
      [saveError retain];
    }
  }];
  if (didSave) {
    MRRUserRecipesStorePostChangeNotification(self);
  }
  if (saveError != nil && error != NULL) {
    *error = [saveError autorelease];
  } else if (saveError != nil) {
    [saveError autorelease];
  }
  return didSave;
}

- (NSManagedObject *)recipeManagedObjectForUserID:(NSString *)userID
                                         recipeID:(NSString *)recipeID
                                          context:(NSManagedObjectContext *)context
                                            error:(NSError **)error {
  NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:MRRUserRecipeEntityName] autorelease];
  request.fetchLimit = 1;
  request.predicate = [NSPredicate predicateWithFormat:@"userID == %@ AND recipeID == %@", userID, recipeID];
  NSArray *results = [context executeFetchRequest:request error:error];
  return results.firstObject;
}

- (NSManagedObject *)syncChangeManagedObjectForUserID:(NSString *)userID
                                             recipeID:(NSString *)recipeID
                                              context:(NSManagedObjectContext *)context
                                                error:(NSError **)error {
  NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:MRRUserRecipeSyncChangeEntityName] autorelease];
  request.fetchLimit = 1;
  request.predicate = [NSPredicate predicateWithFormat:@"userID == %@ AND recipeID == %@", userID, recipeID];
  NSArray *results = [context executeFetchRequest:request error:error];
  return results.firstObject;
}

- (BOOL)upsertRecipeManagedObject:(NSManagedObject *)managedObject
                     withSnapshot:(MRRUserRecipeSnapshot *)snapshot
                          context:(NSManagedObjectContext *)context
                     queueForSync:(BOOL)queueForSync
                            error:(NSError **)error {
  [managedObject setValue:snapshot.userID forKey:@"userID"];
  [managedObject setValue:snapshot.recipeID forKey:@"recipeID"];
  [managedObject setValue:snapshot.title forKey:@"title"];
  [managedObject setValue:snapshot.subtitle forKey:@"subtitle"];
  [managedObject setValue:snapshot.summaryText forKey:@"summaryText"];
  [managedObject setValue:snapshot.mealType forKey:@"mealType"];
  [managedObject setValue:@(snapshot.readyInMinutes) forKey:@"readyInMinutes"];
  [managedObject setValue:@(snapshot.servings) forKey:@"servings"];
  [managedObject setValue:@(snapshot.calorieCount) forKey:@"calorieCount"];
  [managedObject setValue:snapshot.assetName forKey:@"assetName"];
  [managedObject setValue:snapshot.heroImageURLString forKey:@"heroImageURLString"];
  [managedObject setValue:snapshot.createdAt forKey:@"createdAt"];
  [managedObject setValue:snapshot.localModifiedAt forKey:@"localModifiedAt"];
  [managedObject setValue:snapshot.remoteUpdatedAt forKey:@"remoteUpdatedAt"];

  [self replaceChildrenForRelationship:MRRUserRecipeRelationshipPhotos
                              onRecipe:managedObject
                                values:snapshot.photos
                            entityName:MRRUserRecipePhotoEntityName
                            applyBlock:^(NSManagedObject *childManagedObject, MRRUserRecipePhotoSnapshot *value) {
                              [childManagedObject setValue:value.photoID forKey:@"photoID"];
                              [childManagedObject setValue:@(value.orderIndex) forKey:@"orderIndex"];
                              [childManagedObject setValue:value.localRelativePath forKey:@"localRelativePath"];
                              [childManagedObject setValue:value.remoteURLString forKey:@"remoteURLString"];
                            }
                               context:context];
  [self replaceChildrenForRelationship:MRRUserRecipeRelationshipIngredients
                              onRecipe:managedObject
                                values:snapshot.ingredients
                            entityName:MRRUserRecipeIngredientEntityName
                            applyBlock:^(NSManagedObject *childManagedObject, MRRUserRecipeIngredientSnapshot *value) {
                              [childManagedObject setValue:value.name forKey:@"name"];
                              [childManagedObject setValue:value.displayText forKey:@"displayText"];
                              [childManagedObject setValue:@(value.orderIndex) forKey:@"orderIndex"];
                            }
                               context:context];
  [self replaceChildrenForRelationship:MRRUserRecipeRelationshipInstructions
                              onRecipe:managedObject
                                values:snapshot.instructions
                            entityName:MRRUserRecipeInstructionEntityName
                            applyBlock:^(NSManagedObject *childManagedObject, MRRUserRecipeInstructionSnapshot *value) {
                              [childManagedObject setValue:value.title forKey:@"title"];
                              [childManagedObject setValue:value.detailText forKey:@"detailText"];
                              [childManagedObject setValue:@(value.orderIndex) forKey:@"orderIndex"];
                            }
                               context:context];
  [self replaceChildrenForRelationship:MRRUserRecipeRelationshipTools
                              onRecipe:managedObject
                                values:snapshot.tools
                            entityName:MRRUserRecipeToolEntityName
                            applyBlock:^(NSManagedObject *childManagedObject, MRRUserRecipeStringSnapshot *value) {
                              [childManagedObject setValue:value.value forKey:@"value"];
                              [childManagedObject setValue:@(value.orderIndex) forKey:@"orderIndex"];
                            }
                               context:context];
  [self replaceChildrenForRelationship:MRRUserRecipeRelationshipTags
                              onRecipe:managedObject
                                values:snapshot.tags
                            entityName:MRRUserRecipeTagEntityName
                            applyBlock:^(NSManagedObject *childManagedObject, MRRUserRecipeStringSnapshot *value) {
                              [childManagedObject setValue:value.value forKey:@"value"];
                              [childManagedObject setValue:@(value.orderIndex) forKey:@"orderIndex"];
                            }
                               context:context];

  if (queueForSync) {
    NSManagedObject *syncChange = [self syncChangeManagedObjectForUserID:snapshot.userID recipeID:snapshot.recipeID context:context error:error];
    if (syncChange == nil && error != NULL && *error != nil) {
      return NO;
    }
    if (syncChange == nil) {
      syncChange = [NSEntityDescription insertNewObjectForEntityForName:MRRUserRecipeSyncChangeEntityName inManagedObjectContext:context];
      [syncChange setValue:snapshot.userID forKey:@"userID"];
      [syncChange setValue:snapshot.recipeID forKey:@"recipeID"];
    }
    [syncChange setValue:MRRUserRecipeSyncOperationUpsert forKey:@"operationType"];
    [syncChange setValue:[NSDate date] forKey:@"queuedAt"];
  }
  return YES;
}

- (void)replaceChildrenForRelationship:(NSString *)relationshipName
                              onRecipe:(NSManagedObject *)recipeManagedObject
                                values:(NSArray *)values
                            entityName:(NSString *)entityName
                            applyBlock:(void (^)(NSManagedObject *childManagedObject, id value))applyBlock
                               context:(NSManagedObjectContext *)context {
  NSMutableSet *relationshipSet = [recipeManagedObject mutableSetValueForKey:relationshipName];
  NSArray *existingChildren = [relationshipSet allObjects];
  for (NSManagedObject *childManagedObject in existingChildren) {
    [relationshipSet removeObject:childManagedObject];
    [context deleteObject:childManagedObject];
  }
  for (id value in values) {
    NSManagedObject *childManagedObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
    applyBlock(childManagedObject, value);
    [relationshipSet addObject:childManagedObject];
  }
}

- (MRRUserRecipeSnapshot *)snapshotFromRecipeManagedObject:(NSManagedObject *)managedObject {
  NSArray *photoObjects = [[[managedObject valueForKey:MRRUserRecipeRelationshipPhotos] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRUserRecipePhotoSnapshot *> *photos = [NSMutableArray arrayWithCapacity:photoObjects.count];
  for (NSManagedObject *photoManagedObject in photoObjects) {
    NSString *photoID = MRRUserRecipesStoreStringValue([photoManagedObject valueForKey:@"photoID"]);
    NSString *remoteURLString = MRRUserRecipesStoreStringValue([photoManagedObject valueForKey:@"remoteURLString"]);
    NSString *localRelativePath = MRRUserRecipesStoreStringValue([photoManagedObject valueForKey:@"localRelativePath"]);
    if (photoID.length == 0 || (remoteURLString.length == 0 && localRelativePath.length == 0)) {
      continue;
    }
    MRRUserRecipePhotoSnapshot *photo =
        [[[MRRUserRecipePhotoSnapshot alloc] initWithPhotoID:photoID
                                                  orderIndex:MRRUserRecipesStoreIntegerValue([photoManagedObject valueForKey:@"orderIndex"])
                                             remoteURLString:remoteURLString
                                           localRelativePath:localRelativePath] autorelease];
    [photos addObject:photo];
  }

  NSArray *ingredientObjects = [[[managedObject valueForKey:MRRUserRecipeRelationshipIngredients] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRUserRecipeIngredientSnapshot *> *ingredients = [NSMutableArray arrayWithCapacity:ingredientObjects.count];
  for (NSManagedObject *ingredientManagedObject in ingredientObjects) {
    MRRUserRecipeIngredientSnapshot *ingredient = [[[MRRUserRecipeIngredientSnapshot alloc]
        initWithName:MRRUserRecipesStoreStringValue([ingredientManagedObject valueForKey:@"name"])
         displayText:MRRUserRecipesStoreStringValue([ingredientManagedObject valueForKey:@"displayText"])
          orderIndex:MRRUserRecipesStoreIntegerValue([ingredientManagedObject valueForKey:@"orderIndex"])] autorelease];
    [ingredients addObject:ingredient];
  }

  NSArray *instructionObjects = [[[managedObject valueForKey:MRRUserRecipeRelationshipInstructions] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRUserRecipeInstructionSnapshot *> *instructions = [NSMutableArray arrayWithCapacity:instructionObjects.count];
  for (NSManagedObject *instructionManagedObject in instructionObjects) {
    MRRUserRecipeInstructionSnapshot *instruction = [[[MRRUserRecipeInstructionSnapshot alloc]
        initWithTitle:MRRUserRecipesStoreStringValue([instructionManagedObject valueForKey:@"title"])
           detailText:MRRUserRecipesStoreStringValue([instructionManagedObject valueForKey:@"detailText"])
           orderIndex:MRRUserRecipesStoreIntegerValue([instructionManagedObject valueForKey:@"orderIndex"])] autorelease];
    [instructions addObject:instruction];
  }

  NSArray *toolObjects = [[[managedObject valueForKey:MRRUserRecipeRelationshipTools] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRUserRecipeStringSnapshot *> *tools = [NSMutableArray arrayWithCapacity:toolObjects.count];
  for (NSManagedObject *toolManagedObject in toolObjects) {
    MRRUserRecipeStringSnapshot *tool = [[[MRRUserRecipeStringSnapshot alloc]
        initWithValue:MRRUserRecipesStoreStringValue([toolManagedObject valueForKey:@"value"])
           orderIndex:MRRUserRecipesStoreIntegerValue([toolManagedObject valueForKey:@"orderIndex"])] autorelease];
    [tools addObject:tool];
  }

  NSArray *tagObjects = [[[managedObject valueForKey:MRRUserRecipeRelationshipTags] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRUserRecipeStringSnapshot *> *tags = [NSMutableArray arrayWithCapacity:tagObjects.count];
  for (NSManagedObject *tagManagedObject in tagObjects) {
    MRRUserRecipeStringSnapshot *tag = [[[MRRUserRecipeStringSnapshot alloc]
        initWithValue:MRRUserRecipesStoreStringValue([tagManagedObject valueForKey:@"value"])
           orderIndex:MRRUserRecipesStoreIntegerValue([tagManagedObject valueForKey:@"orderIndex"])] autorelease];
    [tags addObject:tag];
  }

  return [[[MRRUserRecipeSnapshot alloc] initWithUserID:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"userID"])
                                               recipeID:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"recipeID"])
                                                  title:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"title"])
                                               subtitle:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"subtitle"])
                                            summaryText:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"summaryText"])
                                               mealType:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"mealType"])
                                         readyInMinutes:MRRUserRecipesStoreIntegerValue([managedObject valueForKey:@"readyInMinutes"])
                                               servings:MRRUserRecipesStoreIntegerValue([managedObject valueForKey:@"servings"])
                                           calorieCount:MRRUserRecipesStoreIntegerValue([managedObject valueForKey:@"calorieCount"])
                                              assetName:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"assetName"])
                                     heroImageURLString:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"heroImageURLString"])
                                                 photos:photos
                                            ingredients:ingredients
                                           instructions:instructions
                                                  tools:tools
                                                   tags:tags
                                              createdAt:MRRUserRecipesStoreDateValue([managedObject valueForKey:@"createdAt"]) ?: [NSDate date]
                                        localModifiedAt:MRRUserRecipesStoreDateValue([managedObject valueForKey:@"localModifiedAt"]) ?: [NSDate date]
                                        remoteUpdatedAt:MRRUserRecipesStoreDateValue([managedObject valueForKey:@"remoteUpdatedAt"])] autorelease];
}

- (MRRUserRecipeSyncChange *)syncChangeFromManagedObject:(NSManagedObject *)managedObject {
  NSString *operationString = MRRUserRecipesStoreStringValue([managedObject valueForKey:@"operationType"]);
  MRRUserRecipeSyncChangeOperation operation = [operationString isEqualToString:MRRUserRecipeSyncOperationDelete]
                                                   ? MRRUserRecipeSyncChangeOperationDelete
                                                   : MRRUserRecipeSyncChangeOperationUpsert;
  return [[[MRRUserRecipeSyncChange alloc] initWithUserID:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"userID"])
                                                 recipeID:MRRUserRecipesStoreStringValue([managedObject valueForKey:@"recipeID"])
                                                operation:operation
                                                 queuedAt:MRRUserRecipesStoreDateValue([managedObject valueForKey:@"queuedAt"]) ?: [NSDate date]]
      autorelease];
}

- (void)deleteChildrenForRecipeManagedObject:(NSManagedObject *)managedObject context:(NSManagedObjectContext *)context {
  for (NSString *relationshipName in @[
         MRRUserRecipeRelationshipPhotos, MRRUserRecipeRelationshipIngredients, MRRUserRecipeRelationshipInstructions, MRRUserRecipeRelationshipTools,
         MRRUserRecipeRelationshipTags
       ]) {
    NSMutableSet *relationshipSet = [managedObject mutableSetValueForKey:relationshipName];
    NSArray *children = [relationshipSet allObjects];
    for (NSManagedObject *childManagedObject in children) {
      [relationshipSet removeObject:childManagedObject];
      [context deleteObject:childManagedObject];
    }
  }
}

@end
