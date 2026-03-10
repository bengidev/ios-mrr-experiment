#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DemoListView;

@protocol DemoListPresenting <NSObject>

- (void)attachView:(id<DemoListView>)view;
- (void)viewDidLoad;

@end

NS_ASSUME_NONNULL_END
