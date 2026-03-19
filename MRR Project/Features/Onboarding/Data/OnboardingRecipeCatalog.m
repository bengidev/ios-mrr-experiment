#import "OnboardingRecipeCatalog.h"

static OnboardingRecipeInstruction *MRRInstruction(NSString *title, NSString *detailText) {
  return [[[OnboardingRecipeInstruction alloc] initWithTitle:title detailText:detailText] autorelease];
}

static OnboardingRecipeIngredient *MRRIngredient(NSString *text) {
  return [[[OnboardingRecipeIngredient alloc] initWithName:text displayText:text] autorelease];
}

static NSArray<OnboardingRecipeIngredient *> *MRRIngredients(NSArray<NSString *> *items) {
  NSMutableArray<OnboardingRecipeIngredient *> *ingredients = [NSMutableArray arrayWithCapacity:items.count];
  for (NSString *item in items) {
    [ingredients addObject:MRRIngredient(item)];
  }

  return ingredients;
}

static OnboardingRecipeDetail *MRRDetail(NSString *title,
                                         NSString *subtitle,
                                         NSString *assetName,
                                         NSString *durationText,
                                         NSString *calorieText,
                                         NSString *servingsText,
                                         NSString *summaryText,
                                         NSArray<NSString *> *ingredients,
                                         NSArray<OnboardingRecipeInstruction *> *instructions) {
  return [[[OnboardingRecipeDetail alloc] initWithTitle:title
                                               subtitle:subtitle
                                              assetName:assetName
                                     heroImageURLString:nil
                                           durationText:durationText
                                            calorieText:calorieText
                                           servingsText:servingsText
                                            summaryText:summaryText
                                            ingredients:MRRIngredients(ingredients)
                                           instructions:instructions
                                                  tools:@[]
                                                   tags:@[]
                                             sourceName:nil
                                        sourceURLString:nil
                                         productContext:nil] autorelease];
}

static OnboardingRecipeDetail *MRRDetailWithMetadata(NSString *title,
                                                     NSString *subtitle,
                                                     NSString *assetName,
                                                     NSString *durationText,
                                                     NSString *calorieText,
                                                     NSString *servingsText,
                                                     NSString *summaryText,
                                                     NSArray<NSString *> *ingredients,
                                                     NSArray<OnboardingRecipeInstruction *> *instructions,
                                                     NSArray<NSString *> *tools,
                                                     NSArray<NSString *> *tags) {
  return [[[OnboardingRecipeDetail alloc] initWithTitle:title
                                               subtitle:subtitle
                                              assetName:assetName
                                     heroImageURLString:nil
                                           durationText:durationText
                                            calorieText:calorieText
                                           servingsText:servingsText
                                            summaryText:summaryText
                                            ingredients:MRRIngredients(ingredients)
                                           instructions:instructions
                                                  tools:tools ?: @[]
                                                   tags:tags ?: @[]
                                             sourceName:nil
                                        sourceURLString:nil
                                         productContext:nil] autorelease];
}

static OnboardingRecipePreview *MRRPreview(NSString *title,
                                           NSString *subtitle,
                                           NSString *assetName,
                                           NSString *openFoodFactsBarcode,
                                           OnboardingRecipeDetail *fallbackDetail) {
  return [[[OnboardingRecipePreview alloc] initWithTitle:title
                                                subtitle:subtitle
                                               assetName:assetName
                                    openFoodFactsBarcode:openFoodFactsBarcode
                                          fallbackDetail:fallbackDetail] autorelease];
}

@implementation OnboardingRecipeCatalog

- (NSArray<OnboardingRecipePreview *> *)allRecipePreviews {
  return @[
    MRRPreview(
        @"Avocado Toast",
        @"Bright breakfast",
        @"avocado-toast",
        nil,
        MRRDetailWithMetadata(
            @"Avocado Toast",
            @"Bright breakfast",
            @"avocado-toast",
            @"10 min",
            @"280 kcal",
            @"2 servings",
            @"Creamy avocado, crisp sourdough, and a quick citrus finish make this an easy starter recipe for onboarding. "
            @"It feels familiar on the first glance, opens with bright texture, and gives new users a clear example of a dish "
            @"they could realistically make in a few calm steps at home.",
            @[ @"2 ripe avocados", @"4 slices sourdough", @"1 lemon", @"Chili flakes", @"Sea salt", @"Olive oil" ],
            @[
              MRRInstruction(@"Mash the base", @"Crush avocado with lemon juice, olive oil, and a pinch of salt until creamy."),
              MRRInstruction(@"Toast the bread", @"Toast sourdough until golden so the topping stays crisp and lifted."),
              MRRInstruction(@"Finish with contrast", @"Spread generously, then add chili flakes and another squeeze of lemon.")
            ],
            @[ @"Chef knife", @"Mixing bowl", @"Toaster or skillet" ],
            @[ @"Breakfast", @"Quick", @"Vegetarian" ])),
    MRRPreview(
        @"Seared Salmon",
        @"Fast weeknight dinner",
        @"salmon",
        nil,
        MRRDetail(
            @"Seared Salmon",
            @"Fast weeknight dinner",
            @"salmon",
            @"18 min",
            @"430 kcal",
            @"2 servings",
            @"Pan-seared salmon with a glossy finish and tender center delivers restaurant-style results in one skillet.",
            @[ @"2 salmon fillets", @"1 tbsp butter", @"2 garlic cloves", @"1 lemon", @"Black pepper", @"Parsley" ],
            @[
              MRRInstruction(@"Dry and season", @"Pat the salmon dry so the pan can create a strong golden crust."),
              MRRInstruction(@"Sear skin side down", @"Cook undisturbed for most of the time, then baste with butter and garlic."),
              MRRInstruction(@"Brighten before serving", @"Finish with lemon juice and parsley for a clean, fresh edge.")
            ])),
    MRRPreview(
        @"Pasta Carbonara",
        @"Silky comfort bowl",
        @"pasta-carbonara",
        nil,
        MRRDetail(
            @"Pasta Carbonara",
            @"Silky comfort bowl",
            @"pasta-carbonara",
            @"25 min",
            @"520 kcal",
            @"3 servings",
            @"A classic carbonara that relies on egg, cheese, and pasta water for a glossy sauce without heavy cream.",
            @[ @"250 g spaghetti", @"3 egg yolks", @"1 whole egg", @"Pecorino Romano", @"Pancetta", @"Black pepper" ],
            @[
              MRRInstruction(@"Build the sauce", @"Whisk egg yolks, whole egg, cheese, and pepper in a large warm bowl."),
              MRRInstruction(@"Render the pancetta", @"Cook slowly until the fat turns glossy and the edges become crisp."),
              MRRInstruction(@"Emulsify off heat", @"Toss pasta with pancetta, then stir into the egg mixture with pasta water.")
            ])),
    MRRPreview(
        @"Greek Salad",
        @"Crunchy midday plate",
        @"greek-salad",
        nil,
        MRRDetail(
            @"Greek Salad",
            @"Crunchy midday plate",
            @"greek-salad",
            @"12 min",
            @"240 kcal",
            @"2 servings",
            @"Juicy tomatoes, cucumber, olives, and feta make a refreshing bowl with almost no active cooking.",
            @[ @"Tomatoes", @"Cucumber", @"Red onion", @"Kalamata olives", @"Feta", @"Olive oil" ],
            @[
              MRRInstruction(@"Cut with intention", @"Keep the vegetables chunky so every bite still feels crisp and juicy."),
              MRRInstruction(@"Season the dressing", @"Shake olive oil with oregano, salt, and a small splash of vinegar."),
              MRRInstruction(@"Fold lightly", @"Dress at the last minute so the feta stays creamy and the vegetables stay bright.")
            ])),
    MRRPreview(
        @"Green Curry",
        @"Aromatic comfort",
        @"green-curry",
        nil,
        MRRDetail(
            @"Green Curry",
            @"Aromatic comfort",
            @"green-curry",
            @"30 min",
            @"470 kcal",
            @"3 servings",
            @"Fragrant curry paste, coconut milk, and herbs create a layered bowl that tastes rich without feeling heavy.",
            @[ @"Green curry paste", @"Coconut milk", @"Chicken or tofu", @"Thai basil", @"Green beans", @"Fish sauce" ],
            @[
              MRRInstruction(@"Wake up the paste", @"Cook the curry paste briefly in the pan until the aroma turns sharper and deeper."),
              MRRInstruction(@"Simmer gently", @"Add coconut milk and protein, then keep the heat steady so the sauce stays smooth."),
              MRRInstruction(@"Finish fresh", @"Stir in basil and green beans near the end for color and texture.")
            ])),
    MRRPreview(
        @"Ramen Bowl",
        @"Cozy late-night pick",
        @"ramen",
        nil,
        MRRDetail(
            @"Ramen Bowl",
            @"Cozy late-night pick",
            @"ramen",
            @"22 min",
            @"560 kcal",
            @"2 servings",
            @"This simplified ramen leans on a strong broth, springy noodles, and a short list of toppings for impact.",
            @[ @"Ramen noodles", @"Stock", @"Soy sauce", @"Soft-boiled eggs", @"Scallions", @"Mushrooms" ],
            @[
              MRRInstruction(@"Build the broth", @"Season the hot stock with soy sauce and aromatics before the noodles go in."),
              MRRInstruction(@"Cook noodles separately", @"Boil just until springy so the broth stays clear and balanced."),
              MRRInstruction(@"Layer the toppings", @"Top with eggs, mushrooms, and scallions right before serving.")
            ])),
    MRRPreview(
        @"Pizza Night",
        @"Crowd-pleasing classic",
        @"pizza",
        nil,
        MRRDetail(
            @"Pizza Night",
            @"Crowd-pleasing classic",
            @"pizza",
            @"35 min",
            @"610 kcal",
            @"4 servings",
            @"A crisp base, bright tomato sauce, and bubbling cheese turn this into a familiar recipe users want to open.",
            @[ @"Pizza dough", @"Tomato sauce", @"Mozzarella", @"Basil", @"Olive oil", @"Semolina" ],
            @[
              MRRInstruction(@"Stretch the base", @"Press from the center outward to keep a thicker, airy edge around the crust."),
              MRRInstruction(@"Top with restraint", @"Use a thin layer of sauce and cheese so the crust still bakes crisp."),
              MRRInstruction(@"Bake hot and fast", @"Finish with basil and olive oil after baking so the flavors stay vivid.")
            ])),
    MRRPreview(
        @"Beef Bourguignon",
        @"Slow-cooked showpiece",
        @"beef-bourguignon",
        nil,
        MRRDetail(
            @"Beef Bourguignon",
            @"Slow-cooked showpiece",
            @"beef-bourguignon",
            @"45 min",
            @"650 kcal",
            @"4 servings",
            @"A richer option for the carousel, with deep sauce, tender beef, and a clear sense of progression in the steps.",
            @[ @"Beef chuck", @"Carrots", @"Shallots", @"Mushrooms", @"Red wine", @"Stock" ],
            @[
              MRRInstruction(@"Brown the beef", @"Color the beef in batches so the pot develops deep flavor before braising."),
              MRRInstruction(@"Build the sauce", @"Add vegetables, wine, and stock, then scrape the browned bits into the liquid."),
              MRRInstruction(@"Finish with patience", @"Simmer until the beef is tender and the sauce turns glossy and concentrated.")
            ]))
  ];
}

@end
