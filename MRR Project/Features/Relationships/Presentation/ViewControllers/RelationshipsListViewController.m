#import "RelationshipsListViewController.h"
#import "../../Domain/UseCases/RelationshipsLoadDemoListUseCase.h"
#import "../Factories/RelationshipsScreenFactory.h"
#import "../Presenters/RelationshipsListPresenter.h"

@implementation RelationshipsListViewController

- (instancetype)initWithListUseCase:(RelationshipsLoadDemoListUseCase *)listUseCase
                       screenFactory:(RelationshipsScreenFactory *)screenFactory {
    RelationshipsListPresenter *presenter = [[[RelationshipsListPresenter alloc] initWithUseCase:listUseCase] autorelease];
    return [super initWithPresenter:presenter screenFactory:screenFactory];
}

@end
