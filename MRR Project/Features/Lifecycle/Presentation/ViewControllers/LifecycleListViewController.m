#import "LifecycleListViewController.h"
#import "../../Domain/UseCases/LifecycleLoadDemoListUseCase.h"
#import "../Factories/LifecycleScreenFactory.h"
#import "../Presenters/LifecycleListPresenter.h"

@implementation LifecycleListViewController

- (instancetype)initWithListUseCase:(LifecycleLoadDemoListUseCase *)listUseCase
                       screenFactory:(LifecycleScreenFactory *)screenFactory {
    LifecycleListPresenter *presenter = [[[LifecycleListPresenter alloc] initWithUseCase:listUseCase] autorelease];
    return [super initWithPresenter:presenter screenFactory:screenFactory];
}

@end
