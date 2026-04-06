#import "MRRCoreDataStack.h"

NSErrorDomain const MRRCoreDataStackErrorDomain = @"MRRCoreDataStackErrorDomain";

static NSString *const MRRCoreDataModelName = @"MRRProjectDataModel";

static NSURL *MRRCoreDataModelURL(void) {
  NSArray<NSBundle *> *candidateBundles = @[ [NSBundle mainBundle], [NSBundle bundleForClass:[MRRCoreDataStack class]] ];
  for (NSBundle *bundle in candidateBundles) {
    NSURL *modelURL = [bundle URLForResource:MRRCoreDataModelName withExtension:@"momd"];
    if (modelURL != nil) {
      return modelURL;
    }
  }
  return nil;
}

static BOOL MRRManagedObjectContextHasPersistentChanges(NSManagedObjectContext *context) {
  if (context.insertedObjects.count > 0 || context.deletedObjects.count > 0) {
    return YES;
  }
  for (NSManagedObject *object in context.updatedObjects) {
    if (object.changedValues.count > 0) {
      return YES;
    }
  }
  return NO;
}

@interface MRRCoreDataStack ()

@property(nonatomic, retain, readwrite) NSPersistentContainer *persistentContainer;
@property(nonatomic, retain, readwrite) NSManagedObjectContext *viewContext;

@end

@implementation MRRCoreDataStack

- (instancetype)initWithInMemoryStore:(BOOL)inMemoryStore error:(NSError **)error {
  self = [super init];
  if (!self) {
    return nil;
  }

  NSURL *modelURL = MRRCoreDataModelURL();
  if (modelURL == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRCoreDataStackErrorDomain
                                   code:MRRCoreDataStackErrorCodeModelNotFound
                               userInfo:@{NSLocalizedDescriptionKey : @"Core Data model MRRProjectDataModel tidak ditemukan."}];
    }
    [self release];
    return nil;
  }

  NSManagedObjectModel *managedObjectModel = [[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] autorelease];
  if (managedObjectModel == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRCoreDataStackErrorDomain
                                   code:MRRCoreDataStackErrorCodeModelNotFound
                               userInfo:@{NSLocalizedDescriptionKey : @"Core Data model tidak bisa dimuat."}];
    }
    [self release];
    return nil;
  }

  NSPersistentContainer *persistentContainer = [[[NSPersistentContainer alloc] initWithName:MRRCoreDataModelName
                                                                         managedObjectModel:managedObjectModel] autorelease];
  NSPersistentStoreDescription *description = [[[NSPersistentStoreDescription alloc] init] autorelease];
  if (inMemoryStore) {
    description.type = NSInMemoryStoreType;
    [description setURL:[NSURL fileURLWithPath:@"/dev/null"]];
  } else {
    // Explicitly set SQLite store type and URL for reliable persistence
    description.type = NSSQLiteStoreType;
    NSURL *storeURL = [[[NSPersistentContainer defaultDirectoryURL] URLByAppendingPathComponent:MRRCoreDataModelName]
                        URLByAppendingPathExtension:@"sqlite"];
    [description setURL:storeURL];
  }
  description.shouldMigrateStoreAutomatically = YES;
  description.shouldInferMappingModelAutomatically = YES;
  persistentContainer.persistentStoreDescriptions = @[ description ];

  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block NSError *loadError = nil;
  [persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *loadedDescription, NSError *loadedError) {
#pragma unused(loadedDescription)
    if (loadedError != nil) {
      loadError = [loadedError retain];
    }
    dispatch_semaphore_signal(semaphore);
  }];
  dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
  dispatch_release(semaphore);
#endif

  if (loadError != nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRCoreDataStackErrorDomain
                                   code:MRRCoreDataStackErrorCodeStoreLoadFailed
                               userInfo:@{NSLocalizedDescriptionKey : @"Persistent store Core Data gagal dimuat.", NSUnderlyingErrorKey : loadError}];
    }
    [loadError release];
    [self release];
    return nil;
  }

  self.persistentContainer = persistentContainer;
  self.viewContext = persistentContainer.viewContext;
  self.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;
  self.viewContext.automaticallyMergesChangesFromParent = YES;
  self.viewContext.name = @"MRRViewContext";

  return self;
}

- (void)dealloc {
  [_viewContext release];
  [_persistentContainer release];
  [super dealloc];
}

- (NSManagedObjectContext *)newBackgroundContext {
  NSManagedObjectContext *context = [self.persistentContainer newBackgroundContext];
  context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;
  context.automaticallyMergesChangesFromParent = YES;
  return [context autorelease];
}

- (BOOL)saveViewContextIfNeeded:(NSError **)error {
  __block NSError *saveError = nil;
  __block BOOL didSave = YES;
  [self.viewContext performBlockAndWait:^{
    if (!MRRManagedObjectContextHasPersistentChanges(self.viewContext)) {
      return;
    }
    didSave = [self.viewContext save:&saveError];
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

@end
