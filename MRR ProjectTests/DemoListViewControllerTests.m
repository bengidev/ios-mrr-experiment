#import <XCTest/XCTest.h>
#import "../MRR Project/Core/Presentation/ViewControllers/DemoDetailViewController.h"
#import "../MRR Project/Features/Basics/Data/BasicsDemoRepository.h"
#import "../MRR Project/Features/Basics/Domain/UseCases/BasicsLoadDemoDetailUseCase.h"
#import "../MRR Project/Features/Basics/Domain/UseCases/BasicsLoadDemoListUseCase.h"
#import "../MRR Project/Features/Basics/Presentation/Factories/BasicsScreenFactory.h"
#import "../MRR Project/Features/Basics/Presentation/ViewControllers/BasicsListViewController.h"
#import "../MRR Project/Features/Lifecycle/Data/LifecycleDemoRepository.h"
#import "../MRR Project/Features/Lifecycle/Domain/UseCases/LifecycleLoadDemoDetailUseCase.h"
#import "../MRR Project/Features/Lifecycle/Domain/UseCases/LifecycleLoadDemoListUseCase.h"
#import "../MRR Project/Features/Lifecycle/Presentation/Factories/LifecycleScreenFactory.h"
#import "../MRR Project/Features/Lifecycle/Presentation/ViewControllers/LifecycleListViewController.h"
#import "../MRR Project/Features/Relationships/Data/RelationshipsDemoRepository.h"
#import "../MRR Project/Features/Relationships/Domain/UseCases/RelationshipsLoadDemoDetailUseCase.h"
#import "../MRR Project/Features/Relationships/Domain/UseCases/RelationshipsLoadDemoListUseCase.h"
#import "../MRR Project/Features/Relationships/Presentation/Factories/RelationshipsScreenFactory.h"
#import "../MRR Project/Features/Relationships/Presentation/ViewControllers/RelationshipsListViewController.h"

@interface DemoListViewControllerTests : XCTestCase
@end

@implementation DemoListViewControllerTests

- (void)testSelectingDemoPushesDetailController {
    BasicsDemoRepository *repository = [[BasicsDemoRepository alloc] init];
    BasicsLoadDemoListUseCase *listUseCase = [[BasicsLoadDemoListUseCase alloc] initWithRepository:repository];
    BasicsLoadDemoDetailUseCase *detailUseCase = [[BasicsLoadDemoDetailUseCase alloc] initWithRepository:repository];
    BasicsScreenFactory *factory = [[BasicsScreenFactory alloc] initWithDetailUseCase:detailUseCase];
    BasicsListViewController *viewController = [[BasicsListViewController alloc] initWithListUseCase:listUseCase screenFactory:factory];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];

    [viewController view];
    [viewController selectDemoAtIndex:0];

    XCTAssertEqual(navigationController.viewControllers.count, 2U);
    XCTAssertTrue([navigationController.topViewController isKindOfClass:[DemoDetailViewController class]]);
}

- (void)testSelectingRelationshipsDemoPushesDetailController {
    RelationshipsDemoRepository *repository = [[RelationshipsDemoRepository alloc] init];
    RelationshipsLoadDemoListUseCase *listUseCase = [[RelationshipsLoadDemoListUseCase alloc] initWithRepository:repository];
    RelationshipsLoadDemoDetailUseCase *detailUseCase = [[RelationshipsLoadDemoDetailUseCase alloc] initWithRepository:repository];
    RelationshipsScreenFactory *factory = [[RelationshipsScreenFactory alloc] initWithDetailUseCase:detailUseCase];
    RelationshipsListViewController *viewController = [[RelationshipsListViewController alloc] initWithListUseCase:listUseCase screenFactory:factory];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];

    [viewController view];
    [viewController selectDemoAtIndex:0];

    XCTAssertEqual(navigationController.viewControllers.count, 2U);
    XCTAssertTrue([navigationController.topViewController isKindOfClass:[DemoDetailViewController class]]);
}

- (void)testSelectingLifecycleDemoPushesDetailController {
    LifecycleDemoRepository *repository = [[LifecycleDemoRepository alloc] init];
    LifecycleLoadDemoListUseCase *listUseCase = [[LifecycleLoadDemoListUseCase alloc] initWithRepository:repository];
    LifecycleLoadDemoDetailUseCase *detailUseCase = [[LifecycleLoadDemoDetailUseCase alloc] initWithRepository:repository];
    LifecycleScreenFactory *factory = [[LifecycleScreenFactory alloc] initWithDetailUseCase:detailUseCase];
    LifecycleListViewController *viewController = [[LifecycleListViewController alloc] initWithListUseCase:listUseCase screenFactory:factory];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];

    [viewController view];
    [viewController selectDemoAtIndex:0];

    XCTAssertEqual(navigationController.viewControllers.count, 2U);
    XCTAssertTrue([navigationController.topViewController isKindOfClass:[DemoDetailViewController class]]);
}

@end
