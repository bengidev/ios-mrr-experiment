#import <UIKit/UIKit.h>

#import "HomeDataSource.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HomeRecipeCardCellStyle) {
  HomeRecipeCardCellStyleRail = 0,
  HomeRecipeCardCellStyleList = 1,
};

@interface HomeCategoryCell : UICollectionViewCell

- (void)configureWithCategory:(HomeCategory *)category selected:(BOOL)selected;

@end

@interface HomeRecipeCardCell : UICollectionViewCell

- (void)configureWithRecipeCard:(HomeRecipeCard *)recipeCard style:(HomeRecipeCardCellStyle)style;

@end

NS_ASSUME_NONNULL_END
