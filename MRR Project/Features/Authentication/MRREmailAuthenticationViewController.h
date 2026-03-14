#import <UIKit/UIKit.h>

#import "MRRAuthenticationController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MRREmailAuthenticationMode) {
  MRREmailAuthenticationModeSignUp = 0,
  MRREmailAuthenticationModeSignIn = 1,
};

@class MRREmailAuthenticationViewController;

@protocol MRREmailAuthenticationViewControllerDelegate <NSObject>

- (void)emailAuthenticationViewControllerDidAuthenticate:(MRREmailAuthenticationViewController *)viewController;

@end

@interface MRREmailAuthenticationViewController : UIViewController

@property(nonatomic, assign, nullable) id<MRREmailAuthenticationViewControllerDelegate> delegate;

- (instancetype)initWithAuthenticationController:(id<MRRAuthenticationController>)authenticationController
                                            mode:(MRREmailAuthenticationMode)mode
                                   prefilledEmail:(nullable NSString *)prefilledEmail
                                  pendingLinkFlow:(BOOL)pendingLinkFlow;

@end

NS_ASSUME_NONNULL_END
