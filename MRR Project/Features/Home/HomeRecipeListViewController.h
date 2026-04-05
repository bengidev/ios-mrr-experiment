#import <UIKit/UIKit.h>

#import "HomeDataSource.h"

NS_ASSUME_NONNULL_BEGIN

@class HomeRecipeListViewController;

@protocol HomeRecipeListViewControllerDelegate <NSObject>

- (void)homeRecipeListViewController:(HomeRecipeListViewController *)viewController
                 didSelectRecipeCard:(HomeRecipeCard *)recipeCard
                          sourceView:(nullable UIView *)sourceView;

@end

@interface HomeRecipeListViewController : UIViewController

@property(nonatomic, assign, nullable) id<HomeRecipeListViewControllerDelegate> delegate;

- (instancetype)initWithScreenTitle:(NSString *)screenTitle recipes:(NSArray<HomeRecipeCard *> *)recipes emptyMessage:(NSString *)emptyMessage;

@end

NS_ASSUME_NONNULL_END
