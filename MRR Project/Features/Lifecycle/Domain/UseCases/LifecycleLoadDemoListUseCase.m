#import "LifecycleLoadDemoListUseCase.h"
#import "../../../../Core/Domain/Repositories/MRRDemoRepository.h"

@interface LifecycleLoadDemoListUseCase ()

@property (nonatomic, retain) id<MRRDemoRepository> repository;

@end

@implementation LifecycleLoadDemoListUseCase

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

- (NSArray *)loadCategories {
    return [self.repository fetchCategories];
}

- (NSArray *)loadDemoSummariesForCategoryIdentifier:(NSString *)categoryIdentifier {
    return [self.repository fetchDemoSummariesForCategoryIdentifier:categoryIdentifier];
}

@end
