#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MRRUserRecipeSyncChangeOperation) {
  MRRUserRecipeSyncChangeOperationUpsert = 1,
  MRRUserRecipeSyncChangeOperationDelete = 2,
};

@interface MRRUserRecipeSyncChange : NSObject

@property(nonatomic, copy, readonly) NSString *userID;
@property(nonatomic, copy, readonly) NSString *recipeID;
@property(nonatomic, assign, readonly) MRRUserRecipeSyncChangeOperation operation;
@property(nonatomic, retain, readonly) NSDate *queuedAt;

- (instancetype)initWithUserID:(NSString *)userID
                      recipeID:(NSString *)recipeID
                     operation:(MRRUserRecipeSyncChangeOperation)operation
                      queuedAt:(NSDate *)queuedAt;

@end

NS_ASSUME_NONNULL_END
