#import "BasicsScreenFactory.h"
#import "../../Domain/UseCases/BasicsLoadDemoDetailUseCase.h"
#import "../../../../Core/Presentation/Presenters/DemoDetailPresenter.h"
#import "../../../../Core/Presentation/ViewControllers/DemoDetailViewController.h"

@interface BasicsScreenFactory ()

@property (nonatomic, retain) BasicsLoadDemoDetailUseCase *detailUseCase;

@end

@implementation BasicsScreenFactory

- (instancetype)initWithDetailUseCase:(BasicsLoadDemoDetailUseCase *)detailUseCase {
    NSParameterAssert(detailUseCase != nil);

    self = [super init];
    if (self) {
        _detailUseCase = [detailUseCase retain];
    }

    return self;
}

- (void)dealloc {
    [_detailUseCase release];
    [super dealloc];
}

- (UIViewController *)detailViewControllerForDemoIdentifier:(NSString *)demoIdentifier {
    DemoDetailPresenter *presenter = [[[DemoDetailPresenter alloc] initWithUseCase:self.detailUseCase
                                                                     demoIdentifier:demoIdentifier] autorelease];
    DemoDetailViewController *viewController = [[[DemoDetailViewController alloc] initWithPresenter:presenter] autorelease];
    return viewController;
}

@end
