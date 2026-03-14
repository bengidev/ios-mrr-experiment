#import <UIKit/UIKit.h>

#import "../Authentication/MRRAuthenticationController.h"

NS_ASSUME_NONNULL_BEGIN

@class HomeViewController;
@class MRRAuthSession;

@protocol HomeViewControllerDelegate <NSObject>

- (void)homeViewControllerDidSignOut:(HomeViewController *)viewController;

@end

@interface HomeViewController : UIViewController

@property(nonatomic, assign, nullable) id<HomeViewControllerDelegate> delegate;

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                         session:(MRRAuthSession *)session;

@end

NS_ASSUME_NONNULL_END
