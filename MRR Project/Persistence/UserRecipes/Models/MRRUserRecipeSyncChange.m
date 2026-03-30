#import "MRRUserRecipeSyncChange.h"

@interface MRRUserRecipeSyncChange ()

@property(nonatomic, copy, readwrite) NSString *userID;
@property(nonatomic, copy, readwrite) NSString *recipeID;
@property(nonatomic, assign, readwrite) MRRUserRecipeSyncChangeOperation operation;
@property(nonatomic, retain, readwrite) NSDate *queuedAt;

@end

@implementation MRRUserRecipeSyncChange

- (instancetype)initWithUserID:(NSString *)userID
                      recipeID:(NSString *)recipeID
                     operation:(MRRUserRecipeSyncChangeOperation)operation
                      queuedAt:(NSDate *)queuedAt {
  NSParameterAssert(userID.length > 0);
  NSParameterAssert(recipeID.length > 0);
  NSParameterAssert(queuedAt != nil);

  self = [super init];
  if (self) {
    _userID = [userID copy];
    _recipeID = [recipeID copy];
    _operation = operation;
    _queuedAt = [queuedAt retain];
  }
  return self;
}

- (void)dealloc {
  [_queuedAt release];
  [_recipeID release];
  [_userID release];
  [super dealloc];
}

@end
