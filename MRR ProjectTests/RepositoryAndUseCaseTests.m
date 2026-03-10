#import <XCTest/XCTest.h>
#import "../MRR Project/Core/Domain/Models/MRRDemoCategory.h"
#import "../MRR Project/Core/Domain/Models/MRRDemoDetail.h"
#import "../MRR Project/Features/Basics/Data/BasicsDemoRepository.h"
#import "../MRR Project/Features/Basics/Domain/UseCases/BasicsLoadDemoDetailUseCase.h"
#import "../MRR Project/Features/Relationships/Data/RelationshipsDemoRepository.h"
#import "../MRR Project/Features/Relationships/Domain/UseCases/RelationshipsLoadDemoListUseCase.h"
#import "../MRR Project/Features/Lifecycle/Data/LifecycleDemoRepository.h"
#import "../MRR Project/Features/Lifecycle/Domain/UseCases/LifecycleLoadDemoDetailUseCase.h"

@interface RepositoryAndUseCaseTests : XCTestCase
@end

@implementation RepositoryAndUseCaseTests

- (void)testRepositoryExposesThreeCategories {
    BasicsDemoRepository *repository = [[BasicsDemoRepository alloc] init];
    NSArray<MRRDemoCategory *> *categories = [repository fetchCategories];

    XCTAssertEqual(categories.count, 1U);
    XCTAssertEqualObjects(categories[0].identifier, MRRDemoCategoryIdentifierBasics);
}

- (void)testListUseCaseReturnsSummariesForRelationships {
    RelationshipsDemoRepository *repository = [[RelationshipsDemoRepository alloc] init];
    RelationshipsLoadDemoListUseCase *useCase = [[RelationshipsLoadDemoListUseCase alloc] initWithRepository:repository];

    NSArray *summaries = [useCase loadDemoSummariesForCategoryIdentifier:MRRDemoCategoryIdentifierRelationships];

    XCTAssertEqual(summaries.count, 3U);
}

- (void)testDetailUseCaseReturnsExpectedSections {
    LifecycleDemoRepository *repository = [[LifecycleDemoRepository alloc] init];
    LifecycleLoadDemoDetailUseCase *useCase = [[LifecycleLoadDemoDetailUseCase alloc] initWithRepository:repository];

    MRRDemoDetail *detail = [useCase loadDemoDetailForIdentifier:@"lifecycle.dealloc-order"];

    XCTAssertNotNil(detail);
    XCTAssertEqualObjects(detail.title, @"dealloc Order");
    XCTAssertEqual(detail.sections.count, 2U);
}

@end
