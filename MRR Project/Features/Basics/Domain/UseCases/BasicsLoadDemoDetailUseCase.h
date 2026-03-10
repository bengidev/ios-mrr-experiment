#import <Foundation/Foundation.h>
#import "../../../../Core/Domain/UseCases/DemoDetailLoading.h"

NS_ASSUME_NONNULL_BEGIN

@protocol MRRDemoRepository;

@interface BasicsLoadDemoDetailUseCase : NSObject <DemoDetailLoading>

- (instancetype)initWithRepository:(id<MRRDemoRepository>)repository NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
