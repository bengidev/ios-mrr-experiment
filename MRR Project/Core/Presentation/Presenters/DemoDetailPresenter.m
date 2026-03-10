#import "DemoDetailPresenter.h"
#import "../../Domain/UseCases/DemoDetailLoading.h"
#import "../../Domain/Models/MRRDemoDetail.h"
#import "../Protocols/DemoDetailView.h"

@interface DemoDetailPresenter ()

@property (nonatomic, retain) id<DemoDetailLoading> useCase;
@property (nonatomic, copy) NSString *demoIdentifier;
@property (nonatomic, assign) id<DemoDetailView> view;

@end

@implementation DemoDetailPresenter

- (instancetype)initWithUseCase:(id<DemoDetailLoading>)useCase
                  demoIdentifier:(NSString *)demoIdentifier {
    NSParameterAssert(useCase != nil);
    NSParameterAssert(demoIdentifier != nil);

    self = [super init];
    if (self) {
        _useCase = [useCase retain];
        _demoIdentifier = [demoIdentifier copy];
    }

    return self;
}

- (void)dealloc {
    [_useCase release];
    [_demoIdentifier release];
    [super dealloc];
}

- (void)attachView:(id<DemoDetailView>)view {
    _view = view;
}

- (void)viewDidLoad {
    MRRDemoDetail *detail = [self.useCase loadDemoDetailForIdentifier:self.demoIdentifier];

    if (detail == nil) {
        [self.view displayDetailErrorMessage:@"The requested demo detail could not be loaded."];
        return;
    }

    [self.view displayDemoDetail:detail];
}

@end
