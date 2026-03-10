#import <Foundation/Foundation.h>
#import "../../../../Core/Presentation/Protocols/DemoScreenBuilding.h"

NS_ASSUME_NONNULL_BEGIN

@class BasicsLoadDemoDetailUseCase;

@interface BasicsScreenFactory : NSObject <DemoScreenBuilding>

- (instancetype)initWithDetailUseCase:(BasicsLoadDemoDetailUseCase *)detailUseCase NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
