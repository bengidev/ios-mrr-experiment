#import <Foundation/Foundation.h>
#import "../../../../Core/Presentation/Protocols/DemoListPresenting.h"

NS_ASSUME_NONNULL_BEGIN

@class BasicsLoadDemoListUseCase;

@interface BasicsListPresenter : NSObject <DemoListPresenting>

- (instancetype)initWithUseCase:(BasicsLoadDemoListUseCase *)useCase NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
