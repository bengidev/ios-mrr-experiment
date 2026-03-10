#import <Foundation/Foundation.h>
#import "../../../../Core/Presentation/Protocols/DemoListPresenting.h"

NS_ASSUME_NONNULL_BEGIN

@class LifecycleLoadDemoListUseCase;

@interface LifecycleListPresenter : NSObject <DemoListPresenting>

- (instancetype)initWithUseCase:(LifecycleLoadDemoListUseCase *)useCase NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
