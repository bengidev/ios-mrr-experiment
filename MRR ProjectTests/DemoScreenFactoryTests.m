#import <XCTest/XCTest.h>
#import "../MRR Project/Core/Presentation/ViewControllers/DemoDetailViewController.h"
#import "../MRR Project/Features/Basics/Data/BasicsDemoRepository.h"
#import "../MRR Project/Features/Basics/Domain/UseCases/BasicsLoadDemoDetailUseCase.h"
#import "../MRR Project/Features/Basics/Presentation/Factories/BasicsScreenFactory.h"

@interface DemoScreenFactoryTests : XCTestCase
@end

@implementation DemoScreenFactoryTests

- (void)testFactoryBuildsConfiguredDetailController {
    BasicsDemoRepository *repository = [[BasicsDemoRepository alloc] init];
    BasicsLoadDemoDetailUseCase *useCase = [[BasicsLoadDemoDetailUseCase alloc] initWithRepository:repository];
    BasicsScreenFactory *factory = [[BasicsScreenFactory alloc] initWithDetailUseCase:useCase];

    UIViewController *viewController = [factory detailViewControllerForDemoIdentifier:@"basics.property-semantics"];
    [viewController view];

    XCTAssertTrue([viewController isKindOfClass:[DemoDetailViewController class]]);
    XCTAssertEqualObjects(viewController.title, @"Property Semantics");
}

@end
