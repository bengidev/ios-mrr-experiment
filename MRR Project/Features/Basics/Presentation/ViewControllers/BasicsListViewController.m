#import "BasicsListViewController.h"
#import "../../Domain/UseCases/BasicsLoadDemoListUseCase.h"
#import "../Factories/BasicsScreenFactory.h"
#import "../Presenters/BasicsListPresenter.h"

@implementation BasicsListViewController

- (instancetype)initWithListUseCase:(BasicsLoadDemoListUseCase *)listUseCase
                       screenFactory:(BasicsScreenFactory *)screenFactory {
    BasicsListPresenter *presenter = [[[BasicsListPresenter alloc] initWithUseCase:listUseCase] autorelease];
    return [super initWithPresenter:presenter screenFactory:screenFactory];
}

@end
