#import <Foundation/Foundation.h>
#import "../../../../Core/Presentation/Protocols/DemoScreenBuilding.h"

NS_ASSUME_NONNULL_BEGIN

@class LifecycleLoadDemoDetailUseCase;

@interface LifecycleScreenFactory : NSObject <DemoScreenBuilding>

- (instancetype)initWithDetailUseCase:(LifecycleLoadDemoDetailUseCase *)detailUseCase NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
