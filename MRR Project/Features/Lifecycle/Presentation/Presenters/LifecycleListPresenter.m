#import "LifecycleListPresenter.h"
#import "../../Domain/UseCases/LifecycleLoadDemoListUseCase.h"
#import "../../../../Core/Domain/Models/MRRDemoCategory.h"
#import "../../../../Core/Presentation/Protocols/DemoListView.h"

@interface LifecycleListPresenter ()

@property (nonatomic, retain) LifecycleLoadDemoListUseCase *useCase;
@property (nonatomic, assign) id<DemoListView> view;

@end

@implementation LifecycleListPresenter

- (instancetype)initWithUseCase:(LifecycleLoadDemoListUseCase *)useCase {
    NSParameterAssert(useCase != nil);

    self = [super init];
    if (self) {
        _useCase = [useCase retain];
    }

    return self;
}

- (void)dealloc {
    [_useCase release];
    [super dealloc];
}

- (void)attachView:(id<DemoListView>)view {
    _view = view;
}

- (void)viewDidLoad {
    NSArray *categories = [self.useCase loadCategories];
    MRRDemoCategory *matchedCategory = nil;

    for (MRRDemoCategory *category in categories) {
        if ([category.identifier isEqualToString:MRRDemoCategoryIdentifierLifecycle]) {
            matchedCategory = category;
            break;
        }
    }

    if (matchedCategory == nil) {
        [self.view displayListErrorMessage:@"The requested category could not be found."];
        return;
    }

    [self.view displayCategory:matchedCategory
                         demos:[self.useCase loadDemoSummariesForCategoryIdentifier:MRRDemoCategoryIdentifierLifecycle]];
}

@end
