#import "OnboardingRecipeModels.h"

@interface OnboardingRecipeInstruction ()

@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *detailText;

@end

@implementation OnboardingRecipeInstruction

- (instancetype)initWithTitle:(NSString *)title detailText:(NSString *)detailText {
  NSParameterAssert(title.length > 0);
  NSParameterAssert(detailText.length > 0);

  self = [super init];
  if (self) {
    _title = [title copy];
    _detailText = [detailText copy];
  }

  return self;
}

- (void)dealloc {
  [_title release];
  [_detailText release];
  [super dealloc];
}

@end

@interface OnboardingRecipeIngredient ()

@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, copy, readwrite) NSString *displayText;

@end

@implementation OnboardingRecipeIngredient

- (instancetype)initWithName:(NSString *)name displayText:(NSString *)displayText {
  NSParameterAssert(name.length > 0);
  NSParameterAssert(displayText.length > 0);

  self = [super init];
  if (self) {
    _name = [name copy];
    _displayText = [displayText copy];
  }

  return self;
}

- (void)dealloc {
  [_name release];
  [_displayText release];
  [super dealloc];
}

@end

@interface OnboardingRecipeProductContext ()

@property(nonatomic, copy, readwrite) NSString *productName;
@property(nonatomic, copy, readwrite, nullable) NSString *brandText;
@property(nonatomic, copy, readwrite, nullable) NSString *nutritionGradeText;
@property(nonatomic, copy, readwrite, nullable) NSString *quantityText;

@end

@implementation OnboardingRecipeProductContext

- (instancetype)initWithProductName:(NSString *)productName
                          brandText:(NSString *)brandText
                 nutritionGradeText:(NSString *)nutritionGradeText
                       quantityText:(NSString *)quantityText {
  NSParameterAssert(productName.length > 0);

  self = [super init];
  if (self) {
    _productName = [productName copy];
    _brandText = [brandText copy];
    _nutritionGradeText = [nutritionGradeText copy];
    _quantityText = [quantityText copy];
  }

  return self;
}

- (void)dealloc {
  [_productName release];
  [_brandText release];
  [_nutritionGradeText release];
  [_quantityText release];
  [super dealloc];
}

@end

@interface OnboardingRecipeDetail ()

@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *subtitle;
@property(nonatomic, copy, readwrite) NSString *assetName;
@property(nonatomic, copy, readwrite, nullable) NSString *heroImageURLString;
@property(nonatomic, copy, readwrite) NSString *durationText;
@property(nonatomic, copy, readwrite) NSString *calorieText;
@property(nonatomic, copy, readwrite) NSString *servingsText;
@property(nonatomic, copy, readwrite) NSString *summaryText;
@property(nonatomic, copy, readwrite) NSArray<OnboardingRecipeIngredient *> *ingredients;
@property(nonatomic, copy, readwrite) NSArray<OnboardingRecipeInstruction *> *instructions;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *tools;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *tags;
@property(nonatomic, copy, readwrite, nullable) NSString *sourceName;
@property(nonatomic, copy, readwrite, nullable) NSString *sourceURLString;
@property(nonatomic, retain, readwrite, nullable) OnboardingRecipeProductContext *productContext;

@end

@implementation OnboardingRecipeDetail

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                    assetName:(NSString *)assetName
           heroImageURLString:(NSString *)heroImageURLString
                 durationText:(NSString *)durationText
                  calorieText:(NSString *)calorieText
                 servingsText:(NSString *)servingsText
                  summaryText:(NSString *)summaryText
                  ingredients:(NSArray<OnboardingRecipeIngredient *> *)ingredients
                 instructions:(NSArray<OnboardingRecipeInstruction *> *)instructions
                        tools:(NSArray<NSString *> *)tools
                         tags:(NSArray<NSString *> *)tags
                   sourceName:(NSString *)sourceName
              sourceURLString:(NSString *)sourceURLString
               productContext:(OnboardingRecipeProductContext *)productContext {
  NSParameterAssert(title.length > 0);
  NSParameterAssert(subtitle.length > 0);
  NSParameterAssert(assetName.length > 0);
  NSParameterAssert(durationText.length > 0);
  NSParameterAssert(calorieText.length > 0);
  NSParameterAssert(servingsText.length > 0);
  NSParameterAssert(summaryText.length > 0);
  NSParameterAssert(ingredients.count > 0);
  NSParameterAssert(instructions.count > 0);
  NSParameterAssert(tools != nil);
  NSParameterAssert(tags != nil);

  self = [super init];
  if (self) {
    _title = [title copy];
    _subtitle = [subtitle copy];
    _assetName = [assetName copy];
    _heroImageURLString = [heroImageURLString copy];
    _durationText = [durationText copy];
    _calorieText = [calorieText copy];
    _servingsText = [servingsText copy];
    _summaryText = [summaryText copy];
    _ingredients = [ingredients copy];
    _instructions = [instructions copy];
    _tools = [tools copy];
    _tags = [tags copy];
    _sourceName = [sourceName copy];
    _sourceURLString = [sourceURLString copy];
    _productContext = [productContext retain];
  }

  return self;
}

- (void)dealloc {
  [_title release];
  [_subtitle release];
  [_assetName release];
  [_heroImageURLString release];
  [_durationText release];
  [_calorieText release];
  [_servingsText release];
  [_summaryText release];
  [_ingredients release];
  [_instructions release];
  [_tools release];
  [_tags release];
  [_sourceName release];
  [_sourceURLString release];
  [_productContext release];
  [super dealloc];
}

@end

@interface OnboardingRecipePreview ()

@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *subtitle;
@property(nonatomic, copy, readwrite) NSString *assetName;
@property(nonatomic, copy, readwrite, nullable) NSString *openFoodFactsBarcode;
@property(nonatomic, retain, readwrite) OnboardingRecipeDetail *fallbackDetail;

@end

@implementation OnboardingRecipePreview

- (instancetype)initWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                    assetName:(NSString *)assetName
         openFoodFactsBarcode:(NSString *)openFoodFactsBarcode
               fallbackDetail:(OnboardingRecipeDetail *)fallbackDetail {
  NSParameterAssert(title.length > 0);
  NSParameterAssert(subtitle.length > 0);
  NSParameterAssert(assetName.length > 0);
  NSParameterAssert(fallbackDetail != nil);

  self = [super init];
  if (self) {
    _title = [title copy];
    _subtitle = [subtitle copy];
    _assetName = [assetName copy];
    _openFoodFactsBarcode = [openFoodFactsBarcode copy];
    _fallbackDetail = [fallbackDetail retain];
  }

  return self;
}

- (void)dealloc {
  [_title release];
  [_subtitle release];
  [_assetName release];
  [_openFoodFactsBarcode release];
  [_fallbackDetail release];
  [super dealloc];
}

@end
