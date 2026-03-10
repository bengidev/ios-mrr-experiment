#import "../../../../Core/Presentation/ViewControllers/DemoListViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class RelationshipsLoadDemoListUseCase;
@class RelationshipsScreenFactory;

@interface RelationshipsListViewController : DemoListViewController

- (instancetype)initWithListUseCase:(RelationshipsLoadDemoListUseCase *)listUseCase
                       screenFactory:(RelationshipsScreenFactory *)screenFactory;

@end

NS_ASSUME_NONNULL_END
