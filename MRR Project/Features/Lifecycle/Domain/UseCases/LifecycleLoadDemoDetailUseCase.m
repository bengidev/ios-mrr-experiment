#import "LifecycleLoadDemoDetailUseCase.h"
#import "../../../../Core/Domain/Repositories/MRRDemoRepository.h"

@interface LifecycleLoadDemoDetailUseCase ()

@property (nonatomic, retain) id<MRRDemoRepository> repository;

@end

@implementation LifecycleLoadDemoDetailUseCase

- (instancetype)initWithRepository:(id<MRRDemoRepository>)repository {
    NSParameterAssert(repository != nil);

    self = [super init];
    if (self) {
        _repository = [repository retain];
    }

    return self;
}

- (void)dealloc {
    [_repository release];
    [super dealloc];
}

- (id)loadDemoDetailForIdentifier:(NSString *)demoIdentifier {
    return [self.repository fetchDemoDetailForIdentifier:demoIdentifier];
}

@end
