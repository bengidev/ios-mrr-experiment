#import "../../../../Core/Presentation/ViewControllers/DemoListViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class LifecycleLoadDemoListUseCase;
@class LifecycleScreenFactory;

@interface LifecycleListViewController : DemoListViewController

- (instancetype)initWithListUseCase:(LifecycleLoadDemoListUseCase *)listUseCase
                       screenFactory:(LifecycleScreenFactory *)screenFactory;

@end

NS_ASSUME_NONNULL_END
