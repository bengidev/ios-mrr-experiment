#import <XCTest/XCTest.h>
#import "../MRR Project/Core/Domain/Models/MRRDemoCategory.h"
#import "../MRR Project/Core/Domain/Models/MRRDemoDetail.h"
#import "../MRR Project/Core/Presentation/Presenters/DemoDetailPresenter.h"
#import "../MRR Project/Core/Presentation/Protocols/DemoDetailView.h"
#import "../MRR Project/Core/Presentation/Protocols/DemoListView.h"
#import "../MRR Project/Features/Basics/Data/BasicsDemoRepository.h"
#import "../MRR Project/Features/Basics/Domain/UseCases/BasicsLoadDemoDetailUseCase.h"
#import "../MRR Project/Features/Basics/Domain/UseCases/BasicsLoadDemoListUseCase.h"
#import "../MRR Project/Features/Basics/Presentation/Presenters/BasicsListPresenter.h"

@interface DemoListViewSpy : NSObject <DemoListView>
@property (nonatomic, strong) MRRDemoCategory *displayedCategory;
@property (nonatomic, copy) NSArray *displayedDemos;
@property (nonatomic, copy) NSString *errorMessage;
@end

@implementation DemoListViewSpy
- (void)displayCategory:(MRRDemoCategory *)category demos:(NSArray *)demos {
    self.displayedCategory = category;
    self.displayedDemos = demos;
}
- (void)displayListErrorMessage:(NSString *)message {
    self.errorMessage = message;
}
@end

@interface DemoDetailViewSpy : NSObject <DemoDetailView>
@property (nonatomic, strong) MRRDemoDetail *displayedDetail;
@property (nonatomic, copy) NSString *errorMessage;
@end

@implementation DemoDetailViewSpy
- (void)displayDemoDetail:(MRRDemoDetail *)detail {
    self.displayedDetail = detail;
}
- (void)displayDetailErrorMessage:(NSString *)message {
    self.errorMessage = message;
}
@end

@interface PresenterTests : XCTestCase
@end

@implementation PresenterTests

- (void)testListPresenterDisplaysMatchedCategory {
    BasicsDemoRepository *repository = [[BasicsDemoRepository alloc] init];
    BasicsLoadDemoListUseCase *useCase = [[BasicsLoadDemoListUseCase alloc] initWithRepository:repository];
    BasicsListPresenter *presenter = [[BasicsListPresenter alloc] initWithUseCase:useCase];
    DemoListViewSpy *viewSpy = [[DemoListViewSpy alloc] init];

    [presenter attachView:viewSpy];
    [presenter viewDidLoad];

    XCTAssertNil(viewSpy.errorMessage);
    XCTAssertEqualObjects(viewSpy.displayedCategory.identifier, MRRDemoCategoryIdentifierBasics);
    XCTAssertEqual(viewSpy.displayedDemos.count, 3U);
}

- (void)testDetailPresenterDisplaysRequestedDetail {
    BasicsDemoRepository *repository = [[BasicsDemoRepository alloc] init];
    BasicsLoadDemoDetailUseCase *useCase = [[BasicsLoadDemoDetailUseCase alloc] initWithRepository:repository];
    DemoDetailPresenter *presenter = [[DemoDetailPresenter alloc] initWithUseCase:useCase demoIdentifier:@"basics.property-semantics"];
    DemoDetailViewSpy *viewSpy = [[DemoDetailViewSpy alloc] init];

    [presenter attachView:viewSpy];
    [presenter viewDidLoad];

    XCTAssertNil(viewSpy.errorMessage);
    XCTAssertEqualObjects(viewSpy.displayedDetail.title, @"Property Semantics");
}

@end
