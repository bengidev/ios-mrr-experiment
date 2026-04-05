#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeSectionHeaderView : UIView

@property(nonatomic, retain, readonly) UILabel *titleLabel;
@property(nonatomic, retain, readonly) UIButton *seeAllButton;

- (void)configureWithTitle:(NSString *)title identifierPrefix:(NSString *)identifierPrefix showsSeeAll:(BOOL)showsSeeAll;

@end

NS_ASSUME_NONNULL_END
