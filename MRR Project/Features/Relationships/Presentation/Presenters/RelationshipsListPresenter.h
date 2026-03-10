#import <Foundation/Foundation.h>
#import "../../../../Core/Presentation/Protocols/DemoListPresenting.h"

NS_ASSUME_NONNULL_BEGIN

@class RelationshipsLoadDemoListUseCase;

@interface RelationshipsListPresenter : NSObject <DemoListPresenting>

- (instancetype)initWithUseCase:(RelationshipsLoadDemoListUseCase *)useCase NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
