#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MRRCoreDataStackErrorDomain;

typedef NS_ENUM(NSInteger, MRRCoreDataStackErrorCode) {
  MRRCoreDataStackErrorCodeModelNotFound = 1,
  MRRCoreDataStackErrorCodeStoreLoadFailed = 2,
};

@interface MRRCoreDataStack : NSObject

@property(nonatomic, retain, readonly) NSPersistentContainer *persistentContainer;
@property(nonatomic, retain, readonly) NSManagedObjectContext *viewContext;

- (nullable instancetype)initWithInMemoryStore:(BOOL)inMemoryStore error:(NSError *_Nullable *_Nullable)error;
- (NSManagedObjectContext *)newBackgroundContext;
- (BOOL)saveViewContextIfNeeded:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
