#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MRRSavedRecipeSyncChangeOperation) {
  MRRSavedRecipeSyncChangeOperationUpsert = 1,
  MRRSavedRecipeSyncChangeOperationDelete = 2,
};

@interface MRRSavedRecipeSyncChange : NSObject

@property(nonatomic, copy, readonly) NSString *userID;
@property(nonatomic, copy, readonly) NSString *recipeID;
@property(nonatomic, assign, readonly) MRRSavedRecipeSyncChangeOperation operation;
@property(nonatomic, retain, readonly) NSDate *queuedAt;

- (instancetype)initWithUserID:(NSString *)userID
                      recipeID:(NSString *)recipeID
                     operation:(MRRSavedRecipeSyncChangeOperation)operation
                      queuedAt:(NSDate *)queuedAt;

@end

NS_ASSUME_NONNULL_END
