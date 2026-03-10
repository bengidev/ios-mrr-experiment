#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MRRDemoDetail;

@protocol DemoDetailLoading <NSObject>

- (nullable MRRDemoDetail *)loadDemoDetailForIdentifier:(NSString *)demoIdentifier;

@end

NS_ASSUME_NONNULL_END
