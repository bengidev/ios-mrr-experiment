#import "MRRSavedRecipesStore.h"

#import <CoreData/CoreData.h>

#import "../CoreData/MRRCoreDataStack.h"
#import "../../Features/Onboarding/Data/OnboardingRecipeModels.h"

NSNotificationName const MRRSavedRecipesStoreDidChangeNotification = @"MRRSavedRecipesStoreDidChangeNotification";
NSErrorDomain const MRRSavedRecipesStoreErrorDomain = @"MRRSavedRecipesStoreErrorDomain";

static NSString *const MRRSavedRecipeEntityName = @"SavedRecipe";
static NSString *const MRRSavedRecipeIngredientEntityName = @"SavedRecipeIngredient";
static NSString *const MRRSavedRecipeInstructionEntityName = @"SavedRecipeInstruction";
static NSString *const MRRSavedRecipeToolEntityName = @"SavedRecipeTool";
static NSString *const MRRSavedRecipeTagEntityName = @"SavedRecipeTag";
static NSString *const MRRSavedRecipeSyncChangeEntityName = @"SavedRecipeSyncChange";

static NSString *const MRRSavedRecipeRelationshipIngredients = @"ingredients";
static NSString *const MRRSavedRecipeRelationshipInstructions = @"instructions";
static NSString *const MRRSavedRecipeRelationshipTools = @"tools";
static NSString *const MRRSavedRecipeRelationshipTags = @"tags";

static NSString *const MRRSavedRecipeSyncOperationUpsert = @"upsert";
static NSString *const MRRSavedRecipeSyncOperationDelete = @"delete";

static void MRRSavedRecipesStorePostChangeNotification(id object) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:MRRSavedRecipesStoreDidChangeNotification object:object];
  });
}

static NSString *MRRSavedRecipesStoreStringValue(id candidate) {
  if (![candidate isKindOfClass:[NSString class]]) {
    return @"";
  }
  return (NSString *)candidate;
}

static NSDate *MRRSavedRecipesStoreDateValue(id candidate) {
  if ([candidate isKindOfClass:[NSDate class]]) {
    return (NSDate *)candidate;
  }
  return nil;
}

static NSInteger MRRSavedRecipesStoreIntegerValue(id candidate) {
  if ([candidate respondsToSelector:@selector(integerValue)]) {
    return [candidate integerValue];
  }
  return 0;
}

@interface MRRSavedRecipesStore ()

@property(nonatomic, retain) MRRCoreDataStack *coreDataStack;

- (nullable NSManagedObject *)savedRecipeManagedObjectForUserID:(NSString *)userID
                                                       recipeID:(NSString *)recipeID
                                                        context:(NSManagedObjectContext *)context
                                                          error:(NSError *_Nullable *_Nullable)error;
- (nullable NSManagedObject *)syncChangeManagedObjectForUserID:(NSString *)userID
                                                      recipeID:(NSString *)recipeID
                                                       context:(NSManagedObjectContext *)context
                                                         error:(NSError *_Nullable *_Nullable)error;
- (BOOL)upsertSavedRecipeManagedObject:(NSManagedObject *)managedObject
                           withSnapshot:(MRRSavedRecipeSnapshot *)snapshot
                               context:(NSManagedObjectContext *)context
                          queueForSync:(BOOL)queueForSync
                                 error:(NSError *_Nullable *_Nullable)error;
- (void)replaceChildrenForRelationship:(NSString *)relationshipName
                             onRecipe:(NSManagedObject *)recipeManagedObject
                               values:(NSArray *)values
                           entityName:(NSString *)entityName
                        applyBlock:(void (^)(NSManagedObject *childManagedObject, id value))applyBlock
                              context:(NSManagedObjectContext *)context;
- (MRRSavedRecipeSnapshot *)snapshotFromSavedRecipeManagedObject:(NSManagedObject *)managedObject;
- (MRRSavedRecipeSyncChange *)syncChangeFromManagedObject:(NSManagedObject *)managedObject;
- (void)deleteChildrenForRecipeManagedObject:(NSManagedObject *)managedObject context:(NSManagedObjectContext *)context;

@end

@implementation MRRSavedRecipesStore

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

- (NSArray<MRRSavedRecipeSnapshot *> *)savedRecipesForUserID:(NSString *)userID error:(NSError **)error {
  __block NSMutableArray<MRRSavedRecipeSnapshot *> *snapshots = nil;
  __block NSError *fetchError = nil;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:MRRSavedRecipeEntityName] autorelease];
    request.predicate = [NSPredicate predicateWithFormat:@"userID == %@", userID];
    request.sortDescriptors = @[ [[[NSSortDescriptor alloc] initWithKey:@"savedAt" ascending:NO] autorelease],
                                 [[[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)] autorelease] ];
    NSArray<NSManagedObject *> *results = [self.coreDataStack.viewContext executeFetchRequest:request error:&fetchError];
    if (fetchError != nil) {
      [fetchError retain];
      return;
    }
    snapshots = [[NSMutableArray alloc] initWithCapacity:results.count];
    for (NSManagedObject *managedObject in results) {
      [snapshots addObject:[self snapshotFromSavedRecipeManagedObject:managedObject]];
    }
  }];
  if (fetchError != nil && error != NULL) {
    *error = [fetchError autorelease];
  } else if (fetchError != nil) {
    [fetchError autorelease];
  }
  return [snapshots autorelease] ?: @[];
}

- (MRRSavedRecipeSnapshot *)savedRecipeForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError **)error {
  __block MRRSavedRecipeSnapshot *snapshot = nil;
  __block NSError *fetchError = nil;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObject *managedObject = [self savedRecipeManagedObjectForUserID:userID recipeID:recipeID context:self.coreDataStack.viewContext error:&fetchError];
    if (fetchError != nil) {
      [fetchError retain];
      return;
    }
    if (managedObject != nil) {
      snapshot = [[self snapshotFromSavedRecipeManagedObject:managedObject] retain];
    }
  }];
  if (fetchError != nil && error != NULL) {
    *error = [fetchError autorelease];
  } else if (fetchError != nil) {
    [fetchError autorelease];
  }
  return [snapshot autorelease];
}

- (BOOL)isRecipeSavedForUserID:(NSString *)userID recipeID:(NSString *)recipeID error:(NSError **)error {
  return [self savedRecipeForUserID:userID recipeID:recipeID error:error] != nil;
}

- (BOOL)saveRecipeSnapshot:(MRRSavedRecipeSnapshot *)snapshot error:(NSError **)error {
  __block NSError *saveError = nil;
  __block BOOL didSave = YES;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSManagedObjectContext *context = self.coreDataStack.viewContext;
    NSManagedObject *managedObject = [self savedRecipeManagedObjectForUserID:snapshot.userID recipeID:snapshot.recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (managedObject == nil) {
      managedObject = [NSEntityDescription insertNewObjectForEntityForName:MRRSavedRecipeEntityName inManagedObjectContext:context];
    }
    didSave = [self upsertSavedRecipeManagedObject:managedObject withSnapshot:snapshot context:context queueForSync:YES error:&saveError];
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
    MRRSavedRecipesStorePostChangeNotification(self);
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
    NSManagedObject *managedObject = [self savedRecipeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
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
      syncChange = [NSEntityDescription insertNewObjectForEntityForName:MRRSavedRecipeSyncChangeEntityName inManagedObjectContext:context];
      [syncChange setValue:userID forKey:@"userID"];
      [syncChange setValue:recipeID forKey:@"recipeID"];
    }
    [syncChange setValue:MRRSavedRecipeSyncOperationDelete forKey:@"operationType"];
    [syncChange setValue:[NSDate date] forKey:@"queuedAt"];

    didSave = [self.coreDataStack saveViewContextIfNeeded:&saveError];
    if (saveError != nil) {
      [saveError retain];
    }
  }];
  if (didSave) {
    MRRSavedRecipesStorePostChangeNotification(self);
  }
  if (saveError != nil && error != NULL) {
    *error = [saveError autorelease];
  } else if (saveError != nil) {
    [saveError autorelease];
  }
  return didSave;
}

- (NSArray<MRRSavedRecipeSyncChange *> *)pendingSyncChangesForUserID:(NSString *)userID error:(NSError **)error {
  __block NSMutableArray<MRRSavedRecipeSyncChange *> *changes = nil;
  __block NSError *fetchError = nil;
  [self.coreDataStack.viewContext performBlockAndWait:^{
    NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:MRRSavedRecipeSyncChangeEntityName] autorelease];
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
    NSManagedObject *managedObject =
        [self syncChangeManagedObjectForUserID:userID recipeID:recipeID context:self.coreDataStack.viewContext error:&fetchError];
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
      NSManagedObject *savedRecipe = [self savedRecipeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
      if (saveError != nil) {
        [saveError retain];
        didSave = NO;
        return;
      }
      if (savedRecipe != nil) {
        [savedRecipe setValue:remoteUpdatedAt forKey:@"remoteUpdatedAt"];
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

- (BOOL)applyRemoteSnapshot:(MRRSavedRecipeSnapshot *)snapshot remoteUpdatedAt:(NSDate *)remoteUpdatedAt error:(NSError **)error {
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

    NSManagedObject *managedObject =
        [self savedRecipeManagedObjectForUserID:snapshot.userID recipeID:snapshot.recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    NSDate *existingRemoteUpdatedAt = MRRSavedRecipesStoreDateValue([managedObject valueForKey:@"remoteUpdatedAt"]);
    if (managedObject != nil && existingRemoteUpdatedAt != nil && [existingRemoteUpdatedAt compare:remoteUpdatedAt] != NSOrderedAscending) {
      return;
    }
    if (managedObject == nil) {
      managedObject = [NSEntityDescription insertNewObjectForEntityForName:MRRSavedRecipeEntityName inManagedObjectContext:context];
    }
    MRRSavedRecipeSnapshot *snapshotWithRemoteDate =
        [[[MRRSavedRecipeSnapshot alloc] initWithUserID:snapshot.userID
                                              recipeID:snapshot.recipeID
                                                 title:snapshot.title
                                              subtitle:snapshot.subtitle
                                             assetName:snapshot.assetName
                                      heroImageURLString:snapshot.heroImageURLString
                                           summaryText:snapshot.summaryText
                                              mealType:snapshot.mealType
                                            sourceName:snapshot.sourceName
                                       sourceURLString:snapshot.sourceURLString
                                        readyInMinutes:snapshot.readyInMinutes
                                              servings:snapshot.servings
                                          calorieCount:snapshot.calorieCount
                                       popularityScore:snapshot.popularityScore
                                          durationText:snapshot.durationText
                                           calorieText:snapshot.calorieText
                                          servingsText:snapshot.servingsText
                                           ingredients:snapshot.ingredients
                                          instructions:snapshot.instructions
                                                 tools:snapshot.tools
                                                  tags:snapshot.tags
                                        productContext:snapshot.productContext
                                               savedAt:snapshot.savedAt
                                       localModifiedAt:remoteUpdatedAt
                                       remoteUpdatedAt:remoteUpdatedAt] autorelease];
    didSave = [self upsertSavedRecipeManagedObject:managedObject withSnapshot:snapshotWithRemoteDate context:context queueForSync:NO error:&saveError];
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
    MRRSavedRecipesStorePostChangeNotification(self);
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
    NSManagedObject *managedObject = [self savedRecipeManagedObjectForUserID:userID recipeID:recipeID context:context error:&saveError];
    if (saveError != nil) {
      [saveError retain];
      didSave = NO;
      return;
    }
    if (managedObject == nil) {
      return;
    }
    NSDate *existingRemoteUpdatedAt = MRRSavedRecipesStoreDateValue([managedObject valueForKey:@"remoteUpdatedAt"]);
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
    MRRSavedRecipesStorePostChangeNotification(self);
  }
  if (saveError != nil && error != NULL) {
    *error = [saveError autorelease];
  } else if (saveError != nil) {
    [saveError autorelease];
  }
  return didSave;
}

- (NSManagedObject *)savedRecipeManagedObjectForUserID:(NSString *)userID
                                              recipeID:(NSString *)recipeID
                                               context:(NSManagedObjectContext *)context
                                                 error:(NSError **)error {
  NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:MRRSavedRecipeEntityName] autorelease];
  request.fetchLimit = 1;
  request.predicate = [NSPredicate predicateWithFormat:@"userID == %@ AND recipeID == %@", userID, recipeID];
  NSArray *results = [context executeFetchRequest:request error:error];
  return results.firstObject;
}

- (NSManagedObject *)syncChangeManagedObjectForUserID:(NSString *)userID
                                             recipeID:(NSString *)recipeID
                                              context:(NSManagedObjectContext *)context
                                                error:(NSError **)error {
  NSFetchRequest *request = [[[NSFetchRequest alloc] initWithEntityName:MRRSavedRecipeSyncChangeEntityName] autorelease];
  request.fetchLimit = 1;
  request.predicate = [NSPredicate predicateWithFormat:@"userID == %@ AND recipeID == %@", userID, recipeID];
  NSArray *results = [context executeFetchRequest:request error:error];
  return results.firstObject;
}

- (BOOL)upsertSavedRecipeManagedObject:(NSManagedObject *)managedObject
                           withSnapshot:(MRRSavedRecipeSnapshot *)snapshot
                               context:(NSManagedObjectContext *)context
                          queueForSync:(BOOL)queueForSync
                                 error:(NSError **)error {
  [managedObject setValue:snapshot.userID forKey:@"userID"];
  [managedObject setValue:snapshot.recipeID forKey:@"recipeID"];
  [managedObject setValue:snapshot.title forKey:@"title"];
  [managedObject setValue:snapshot.subtitle forKey:@"subtitle"];
  [managedObject setValue:snapshot.assetName forKey:@"assetName"];
  [managedObject setValue:snapshot.heroImageURLString forKey:@"heroImageURLString"];
  [managedObject setValue:snapshot.summaryText forKey:@"summaryText"];
  [managedObject setValue:snapshot.mealType forKey:@"mealType"];
  [managedObject setValue:snapshot.sourceName forKey:@"sourceName"];
  [managedObject setValue:snapshot.sourceURLString forKey:@"sourceURLString"];
  [managedObject setValue:@(snapshot.readyInMinutes) forKey:@"readyInMinutes"];
  [managedObject setValue:@(snapshot.servings) forKey:@"servings"];
  [managedObject setValue:@(snapshot.calorieCount) forKey:@"calorieCount"];
  [managedObject setValue:@(snapshot.popularityScore) forKey:@"popularityScore"];
  [managedObject setValue:snapshot.durationText forKey:@"durationText"];
  [managedObject setValue:snapshot.calorieText forKey:@"calorieText"];
  [managedObject setValue:snapshot.servingsText forKey:@"servingsText"];
  [managedObject setValue:snapshot.productContext.productName forKey:@"productName"];
  [managedObject setValue:snapshot.productContext.brandText forKey:@"productBrandText"];
  [managedObject setValue:snapshot.productContext.nutritionGradeText forKey:@"productNutritionGradeText"];
  [managedObject setValue:snapshot.productContext.quantityText forKey:@"productQuantityText"];
  [managedObject setValue:snapshot.savedAt forKey:@"savedAt"];
  [managedObject setValue:snapshot.localModifiedAt forKey:@"localModifiedAt"];
  [managedObject setValue:snapshot.remoteUpdatedAt forKey:@"remoteUpdatedAt"];

  [self replaceChildrenForRelationship:MRRSavedRecipeRelationshipIngredients
                              onRecipe:managedObject
                                values:snapshot.ingredients
                            entityName:MRRSavedRecipeIngredientEntityName
                             applyBlock:^(NSManagedObject *childManagedObject, MRRSavedRecipeIngredientSnapshot *value) {
                               [childManagedObject setValue:value.name forKey:@"name"];
                               [childManagedObject setValue:value.displayText forKey:@"displayText"];
                               [childManagedObject setValue:@(value.orderIndex) forKey:@"orderIndex"];
                             }
                               context:context];
  [self replaceChildrenForRelationship:MRRSavedRecipeRelationshipInstructions
                              onRecipe:managedObject
                                values:snapshot.instructions
                            entityName:MRRSavedRecipeInstructionEntityName
                             applyBlock:^(NSManagedObject *childManagedObject, MRRSavedRecipeInstructionSnapshot *value) {
                               [childManagedObject setValue:value.title forKey:@"title"];
                               [childManagedObject setValue:value.detailText forKey:@"detailText"];
                               [childManagedObject setValue:@(value.orderIndex) forKey:@"orderIndex"];
                             }
                               context:context];
  [self replaceChildrenForRelationship:MRRSavedRecipeRelationshipTools
                              onRecipe:managedObject
                                values:snapshot.tools
                            entityName:MRRSavedRecipeToolEntityName
                             applyBlock:^(NSManagedObject *childManagedObject, MRRSavedRecipeStringSnapshot *value) {
                               [childManagedObject setValue:value.value forKey:@"value"];
                               [childManagedObject setValue:@(value.orderIndex) forKey:@"orderIndex"];
                             }
                               context:context];
  [self replaceChildrenForRelationship:MRRSavedRecipeRelationshipTags
                              onRecipe:managedObject
                                values:snapshot.tags
                            entityName:MRRSavedRecipeTagEntityName
                             applyBlock:^(NSManagedObject *childManagedObject, MRRSavedRecipeStringSnapshot *value) {
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
      syncChange = [NSEntityDescription insertNewObjectForEntityForName:MRRSavedRecipeSyncChangeEntityName inManagedObjectContext:context];
      [syncChange setValue:snapshot.userID forKey:@"userID"];
      [syncChange setValue:snapshot.recipeID forKey:@"recipeID"];
    }
    [syncChange setValue:MRRSavedRecipeSyncOperationUpsert forKey:@"operationType"];
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

- (MRRSavedRecipeSnapshot *)snapshotFromSavedRecipeManagedObject:(NSManagedObject *)managedObject {
  NSArray *ingredientObjects = [[[managedObject valueForKey:MRRSavedRecipeRelationshipIngredients] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRSavedRecipeIngredientSnapshot *> *ingredients = [NSMutableArray arrayWithCapacity:ingredientObjects.count];
  for (NSManagedObject *ingredientManagedObject in ingredientObjects) {
    MRRSavedRecipeIngredientSnapshot *ingredient =
        [[[MRRSavedRecipeIngredientSnapshot alloc] initWithName:MRRSavedRecipesStoreStringValue([ingredientManagedObject valueForKey:@"name"])
                                                    displayText:MRRSavedRecipesStoreStringValue([ingredientManagedObject valueForKey:@"displayText"])
                                                     orderIndex:MRRSavedRecipesStoreIntegerValue([ingredientManagedObject valueForKey:@"orderIndex"])] autorelease];
    [ingredients addObject:ingredient];
  }

  NSArray *instructionObjects = [[[managedObject valueForKey:MRRSavedRecipeRelationshipInstructions] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRSavedRecipeInstructionSnapshot *> *instructions = [NSMutableArray arrayWithCapacity:instructionObjects.count];
  for (NSManagedObject *instructionManagedObject in instructionObjects) {
    MRRSavedRecipeInstructionSnapshot *instruction =
        [[[MRRSavedRecipeInstructionSnapshot alloc] initWithTitle:MRRSavedRecipesStoreStringValue([instructionManagedObject valueForKey:@"title"])
                                                       detailText:MRRSavedRecipesStoreStringValue([instructionManagedObject valueForKey:@"detailText"])
                                                       orderIndex:MRRSavedRecipesStoreIntegerValue([instructionManagedObject valueForKey:@"orderIndex"])] autorelease];
    [instructions addObject:instruction];
  }

  NSArray *toolObjects = [[[managedObject valueForKey:MRRSavedRecipeRelationshipTools] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRSavedRecipeStringSnapshot *> *tools = [NSMutableArray arrayWithCapacity:toolObjects.count];
  for (NSManagedObject *toolManagedObject in toolObjects) {
    MRRSavedRecipeStringSnapshot *tool =
        [[[MRRSavedRecipeStringSnapshot alloc] initWithValue:MRRSavedRecipesStoreStringValue([toolManagedObject valueForKey:@"value"])
                                                  orderIndex:MRRSavedRecipesStoreIntegerValue([toolManagedObject valueForKey:@"orderIndex"])] autorelease];
    [tools addObject:tool];
  }

  NSArray *tagObjects = [[[managedObject valueForKey:MRRSavedRecipeRelationshipTags] allObjects]
      sortedArrayUsingDescriptors:@[ [[[NSSortDescriptor alloc] initWithKey:@"orderIndex" ascending:YES] autorelease] ]];
  NSMutableArray<MRRSavedRecipeStringSnapshot *> *tags = [NSMutableArray arrayWithCapacity:tagObjects.count];
  for (NSManagedObject *tagManagedObject in tagObjects) {
    MRRSavedRecipeStringSnapshot *tag =
        [[[MRRSavedRecipeStringSnapshot alloc] initWithValue:MRRSavedRecipesStoreStringValue([tagManagedObject valueForKey:@"value"])
                                                  orderIndex:MRRSavedRecipesStoreIntegerValue([tagManagedObject valueForKey:@"orderIndex"])] autorelease];
    [tags addObject:tag];
  }

  MRRSavedRecipeProductContextSnapshot *productContext = nil;
  NSString *productName = MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"productName"]);
  if (productName.length > 0) {
    productContext = [[[MRRSavedRecipeProductContextSnapshot alloc] initWithProductName:productName
                                                                              brandText:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"productBrandText"])
                                                                     nutritionGradeText:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"productNutritionGradeText"])
                                                                           quantityText:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"productQuantityText"])] autorelease];
  }

  return [[[MRRSavedRecipeSnapshot alloc] initWithUserID:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"userID"])
                                                recipeID:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"recipeID"])
                                                   title:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"title"])
                                                subtitle:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"subtitle"])
                                               assetName:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"assetName"])
                                        heroImageURLString:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"heroImageURLString"])
                                             summaryText:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"summaryText"])
                                                mealType:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"mealType"])
                                              sourceName:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"sourceName"])
                                         sourceURLString:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"sourceURLString"])
                                          readyInMinutes:MRRSavedRecipesStoreIntegerValue([managedObject valueForKey:@"readyInMinutes"])
                                                servings:MRRSavedRecipesStoreIntegerValue([managedObject valueForKey:@"servings"])
                                            calorieCount:MRRSavedRecipesStoreIntegerValue([managedObject valueForKey:@"calorieCount"])
                                         popularityScore:MRRSavedRecipesStoreIntegerValue([managedObject valueForKey:@"popularityScore"])
                                            durationText:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"durationText"])
                                             calorieText:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"calorieText"])
                                            servingsText:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"servingsText"])
                                             ingredients:ingredients
                                            instructions:instructions
                                                   tools:tools
                                                    tags:tags
                                          productContext:productContext
                                                 savedAt:MRRSavedRecipesStoreDateValue([managedObject valueForKey:@"savedAt"]) ?: [NSDate date]
                                         localModifiedAt:MRRSavedRecipesStoreDateValue([managedObject valueForKey:@"localModifiedAt"]) ?: [NSDate date]
                                         remoteUpdatedAt:MRRSavedRecipesStoreDateValue([managedObject valueForKey:@"remoteUpdatedAt"])] autorelease];
}

- (MRRSavedRecipeSyncChange *)syncChangeFromManagedObject:(NSManagedObject *)managedObject {
  NSString *operationString = MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"operationType"]);
  MRRSavedRecipeSyncChangeOperation operation =
      [operationString isEqualToString:MRRSavedRecipeSyncOperationDelete] ? MRRSavedRecipeSyncChangeOperationDelete
                                                                          : MRRSavedRecipeSyncChangeOperationUpsert;
  return [[[MRRSavedRecipeSyncChange alloc] initWithUserID:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"userID"])
                                                  recipeID:MRRSavedRecipesStoreStringValue([managedObject valueForKey:@"recipeID"])
                                                 operation:operation
                                                  queuedAt:MRRSavedRecipesStoreDateValue([managedObject valueForKey:@"queuedAt"]) ?: [NSDate date]] autorelease];
}

- (void)deleteChildrenForRecipeManagedObject:(NSManagedObject *)managedObject context:(NSManagedObjectContext *)context {
  for (NSString *relationshipName in @[ MRRSavedRecipeRelationshipIngredients, MRRSavedRecipeRelationshipInstructions, MRRSavedRecipeRelationshipTools,
                                        MRRSavedRecipeRelationshipTags ]) {
    NSMutableSet *relationshipSet = [managedObject mutableSetValueForKey:relationshipName];
    NSArray *children = [relationshipSet allObjects];
    for (NSManagedObject *childManagedObject in children) {
      [relationshipSet removeObject:childManagedObject];
      [context deleteObject:childManagedObject];
    }
  }
}

@end
