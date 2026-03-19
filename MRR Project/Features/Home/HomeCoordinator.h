#import <Foundation/Foundation.h>

#import "../Authentication/MRRAuthSession.h"
#import "../MainMenu/MRRFeatureCoordinator.h"
#import "HomeDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface HomeCoordinator : NSObject <MRRTabFeatureCoordinator>

- (instancetype)init;
- (instancetype)initWithSession:(nullable MRRAuthSession *)session;
- (instancetype)initWithSession:(nullable MRRAuthSession *)session dataProvider:(nullable id<HomeDataProviding>)dataProvider;

@end

NS_ASSUME_NONNULL_END
