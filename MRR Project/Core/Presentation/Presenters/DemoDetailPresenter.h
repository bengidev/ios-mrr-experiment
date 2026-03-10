#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DemoDetailLoading;
@protocol DemoDetailView;

@interface DemoDetailPresenter : NSObject

- (instancetype)initWithUseCase:(id<DemoDetailLoading>)useCase
                  demoIdentifier:(NSString *)demoIdentifier NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)attachView:(id<DemoDetailView>)view;
- (void)viewDidLoad;

@end

NS_ASSUME_NONNULL_END
