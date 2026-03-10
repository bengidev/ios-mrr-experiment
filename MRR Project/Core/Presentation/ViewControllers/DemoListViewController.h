#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DemoListPresenting;
@protocol DemoScreenBuilding;

@interface DemoListViewController : UIViewController

- (instancetype)initWithPresenter:(id<DemoListPresenting>)presenter
                    screenFactory:(id<DemoScreenBuilding>)screenFactory;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

- (void)selectDemoAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
