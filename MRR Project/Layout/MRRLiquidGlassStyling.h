#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MRRGlassButtonRole) {
  MRRGlassButtonRolePrimary = 0,
  MRRGlassButtonRoleSecondary = 1,
  MRRGlassButtonRoleInline = 2,
};

typedef NS_ENUM(NSInteger, MRRGlassSurfaceRole) {
  MRRGlassSurfaceRoleElevatedCard = 0,
  MRRGlassSurfaceRoleOverlay = 1,
  MRRGlassSurfaceRoleBadge = 2,
};

@interface MRRLiquidGlassStyling : NSObject

+ (BOOL)supportsNativeLiquidGlass;
+ (BOOL)shouldUseOpaqueFallbackForTransparency;
+ (void)applyButtonRole:(MRRGlassButtonRole)role toButton:(UIButton *)button;
+ (void)applySurfaceRole:(MRRGlassSurfaceRole)role toView:(UIView *)view;
+ (void)applyTextFieldStyling:(UITextField *)textField;

@end

NS_ASSUME_NONNULL_END
