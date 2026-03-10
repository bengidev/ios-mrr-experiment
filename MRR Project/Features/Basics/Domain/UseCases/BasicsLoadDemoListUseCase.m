#import "BasicsLoadDemoListUseCase.h"
#import "../../../../Core/Domain/Repositories/MRRDemoRepository.h"

@interface BasicsLoadDemoListUseCase ()

@property (nonatomic, retain) id<MRRDemoRepository> repository;

@end

@implementation BasicsLoadDemoListUseCase

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
