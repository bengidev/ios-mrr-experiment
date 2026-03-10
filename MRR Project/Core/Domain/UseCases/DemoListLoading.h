#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MRRDemoCategory;
@class MRRDemoSummary;

@protocol DemoListLoading <NSObject>

- (NSArray<MRRDemoCategory *> *)loadCategories;
- (NSArray<MRRDemoSummary *> *)loadDemoSummariesForCategoryIdentifier:(NSString *)categoryIdentifier;

@end

NS_ASSUME_NONNULL_END
