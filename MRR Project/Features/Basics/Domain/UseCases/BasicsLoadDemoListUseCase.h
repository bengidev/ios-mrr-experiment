#import <Foundation/Foundation.h>
#import "../../../../Core/Domain/UseCases/DemoListLoading.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MRRDemoRepository;

@interface BasicsLoadDemoListUseCase : NSObject <DemoListLoading>

- (instancetype)initWithRepository:(id<MRRDemoRepository>)repository NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
