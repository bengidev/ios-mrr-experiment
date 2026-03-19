#import <UIKit/UIKit.h>

#import "HomeDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@class MRRAuthSession;

@interface HomeViewController : UIViewController

- (instancetype)init;
- (instancetype)initWithSession:(nullable MRRAuthSession *)session dataProvider:(id<HomeDataProviding>)dataProvider;

@end

NS_ASSUME_NONNULL_END
