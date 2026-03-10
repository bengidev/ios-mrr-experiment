#import "../../../../Core/Presentation/ViewControllers/DemoListViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class BasicsLoadDemoListUseCase;
@class BasicsScreenFactory;

@interface BasicsListViewController : DemoListViewController

- (instancetype)initWithListUseCase:(BasicsLoadDemoListUseCase *)listUseCase
                       screenFactory:(BasicsScreenFactory *)screenFactory;

@end

NS_ASSUME_NONNULL_END
