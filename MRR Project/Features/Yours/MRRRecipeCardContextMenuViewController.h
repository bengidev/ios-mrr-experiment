#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A beautiful animated context menu for recipe cards.
 * 
 * Features:
 * - Dark blur backdrop with dimming
 * - Spring-animated menu presentation
 * - Staggered menu item animations
 * - Haptic feedback on presentation
 * - Smooth tap interactions with visual feedback
 * 
 * Usage:
 *   MRRRecipeCardContextMenuViewController *menu = [[[MRRRecipeCardContextMenuViewController alloc] initWithRecipeTitle:@"Recipe Name"] autorelease];
 *   [menu addActionWithTitle:@"Edit" imageName:@"square.and.pencil" isDestructive:NO handler:^{
 *       // Handle edit
 *   }];
 *   [menu addActionWithTitle:@"Delete" imageName:@"trash" isDestructive:YES handler:^{
 *       // Handle delete
 *   }];
 *   [self presentViewController:menu animated:YES completion:nil];
 */
@interface MRRRecipeCardContextMenuViewController : UIViewController

/**
 * Initializes the context menu with a recipe title.
 * @param recipeTitle The title of the recipe (displayed in menu header)
 * @return A new instance of the context menu view controller
 */
- (instancetype)initWithRecipeTitle:(NSString *)recipeTitle;

/**
 * Adds an action to the context menu.
 * Actions are displayed in the order they are added.
 * 
 * @param title The display title for the action
 * @param imageName The SF Symbol name for the action icon (iOS 13+)
 * @param isDestructive Whether this is a destructive action (renders in red)
 * @param handler The block to execute when the action is selected
 */
- (void)addActionWithTitle:(NSString *)title
                 imageName:(NSString *)imageName
             isDestructive:(BOOL)isDestructive
                   handler:(void (^)(void))handler;

/**
 * Sets a handler to be called when the menu is cancelled (backdrop tapped).
 * If not set, the menu will simply dismiss without calling any handler.
 */
@property(nonatomic, copy, nullable) void (^cancelHandler)(void);

@end

NS_ASSUME_NONNULL_END