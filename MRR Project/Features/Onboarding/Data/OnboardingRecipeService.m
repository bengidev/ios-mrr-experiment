#import "OnboardingRecipeService.h"

#import <stdarg.h>

NSErrorDomain const MRROnboardingRecipeSearchErrorDomain = @"com.bengidev.mrr.onboarding.recipeSearch";

static NSString *const MRRRecipeAPIConfigurationFileName = @"RecipeAPIConfig";
static NSString *const MRRRecipeAPIConfigurationExtension = @"plist";
static NSString *const MRRRecipeAPIConfigurationSpoonacularKey = @"SpoonacularAPIKey";
static NSString *const MRRRecipeAPIConfigurationOpenFoodFactsUserAgentKey = @"OpenFoodFactsUserAgent";

#if DEBUG
static void MRRRecipeAPIDebugLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

static void MRRRecipeAPIDebugLog(NSString *format, ...) {
  va_list arguments;
  va_start(arguments, format);
  NSString *message = [[[NSString alloc] initWithFormat:format arguments:arguments] autorelease];
  va_end(arguments);
  NSLog(@"[OnboardingRecipeAPI] %@", message);
}
#else
static void MRRRecipeAPIDebugLog(__unused NSString *format, ...) {}
#endif

static NSString *MRRTrimmedString(NSString *string) {
  return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *MRRNormalizedRecipeTitle(NSString *title) {
  NSMutableString *normalizedTitle = [NSMutableString stringWithCapacity:title.length];
  NSCharacterSet *allowedSet = [NSCharacterSet alphanumericCharacterSet];
  BOOL lastCharacterWasWhitespace = NO;

  NSString *lowercaseTitle = [title lowercaseString];
  for (NSUInteger index = 0; index < lowercaseTitle.length; index++) {
    unichar character = [lowercaseTitle characterAtIndex:index];
    if ([allowedSet characterIsMember:character]) {
      [normalizedTitle appendFormat:@"%C", character];
      lastCharacterWasWhitespace = NO;
      continue;
    }

    if (!lastCharacterWasWhitespace) {
      [normalizedTitle appendString:@" "];
      lastCharacterWasWhitespace = YES;
    }
  }

  return MRRTrimmedString(normalizedTitle);
}

static NSString *MRRStringOrNil(id value) {
  if (![value isKindOfClass:[NSString class]]) {
    return nil;
  }

  NSString *string = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  return string.length > 0 ? string : nil;
}

static NSString *MRRRecipeSummaryFromHTMLString(NSString *summary) {
  NSString *string = MRRStringOrNil(summary);
  if (string.length == 0) {
    return nil;
  }

  NSError *error = nil;
  NSRegularExpression *tagExpression = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:&error];
  if (tagExpression == nil || error != nil) {
    return string;
  }

  NSString *plainString = [tagExpression stringByReplacingMatchesInString:string
                                                                  options:0
                                                                    range:NSMakeRange(0, string.length)
                                                             withTemplate:@" "];
  plainString = [plainString stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "];
  plainString = [plainString stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
  plainString = [plainString stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
  plainString = [plainString stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];

  BOOL removedNoisySegments = NO;
  NSArray<NSString *> *noisyPatterns = @[
    @"(?i)[^.]*might be a good recipe to expand your[^.]*\\.",
    @"(?i)this recipe serves\\s+\\d+[^.]*\\.",
    @"(?i)one portion of this dish contains around[^.]*\\.",
    @"(?i)for \\$[^.]*per serving[^.]*\\.",
    @"(?i)\\d+\\s+person(?:s)? has tried and liked this recipe\\.",
    @"(?i)if you have[^.]*on hand, you can make it\\.",
    @"(?i)it is brought to you by[^.]*\\.",
    @"(?i)from preparation to the plate[^.]*\\.",
    @"(?i)taking all factors into account[^.]*\\.",
    @"(?i)if you like this recipe, take a look at these similar recipes:[^.]*\\."
  ];
  for (NSString *pattern in noisyPatterns) {
    NSRegularExpression *noiseExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    if (noiseExpression == nil) {
      continue;
    }

    NSString *cleanedString = [noiseExpression stringByReplacingMatchesInString:plainString
                                                                        options:0
                                                                          range:NSMakeRange(0, plainString.length)
                                                                   withTemplate:@" "];
    if (![cleanedString isEqualToString:plainString]) {
      removedNoisySegments = YES;
      plainString = cleanedString;
    }
  }

  NSRegularExpression *punctuationSpacingExpression =
      [NSRegularExpression regularExpressionWithPattern:@"\\s+([,.;:!?])" options:0 error:nil];
  plainString = [punctuationSpacingExpression stringByReplacingMatchesInString:plainString
                                                                       options:0
                                                                         range:NSMakeRange(0, plainString.length)
                                                                  withTemplate:@"$1"];

  NSRegularExpression *whitespaceExpression = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:nil];
  plainString = [whitespaceExpression stringByReplacingMatchesInString:plainString
                                                               options:0
                                                                 range:NSMakeRange(0, plainString.length)
                                                          withTemplate:@" "];
  plainString = [plainString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (plainString.length == 0) {
    return nil;
  }

  NSArray<NSString *> *sentences = [plainString componentsSeparatedByString:@". "];
  if (sentences.count > 2) {
    plainString = [[sentences subarrayWithRange:NSMakeRange(0, 2)] componentsJoinedByString:@". "];
    if (![plainString hasSuffix:@"."] && ![plainString hasSuffix:@"!"] && ![plainString hasSuffix:@"?"]) {
      plainString = [plainString stringByAppendingString:@"."];
    }
  }

  if (removedNoisySegments && plainString.length < 48) {
    return nil;
  }

  return plainString.length > 0 ? plainString : string;
}

static NSString *MRRCapitalizedNutritionGrade(NSString *nutritionGrade) {
  NSString *string = MRRStringOrNil(nutritionGrade);
  if (string.length == 0) {
    return nil;
  }

  return [string uppercaseString];
}

static NSError *MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCode code, NSString *description) {
  return [NSError errorWithDomain:MRROnboardingRecipeSearchErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : description ?: @"Recipe detail lookup failed."}];
}

static void MRRCompleteOnMainThread(void (^block)(void)) {
  if ([NSThread isMainThread]) {
    block();
    return;
  }

  dispatch_async(dispatch_get_main_queue(), block);
}

static NSArray<NSString *> *MRRNormalizedRecipeTitleTokens(NSString *title) {
  NSString *normalizedTitle = MRRNormalizedRecipeTitle(title);
  if (normalizedTitle.length == 0) {
    return @[];
  }

  return [normalizedTitle componentsSeparatedByString:@" "];
}

static BOOL MRRCandidateHasRequiredDetail(NSDictionary *candidate) {
  NSArray *ingredients = candidate[@"extendedIngredients"];
  NSArray *instructions = candidate[@"analyzedInstructions"];
  NSString *instructionText = MRRStringOrNil(candidate[@"instructions"]);
  return ([ingredients isKindOfClass:[NSArray class]] && ingredients.count > 0) &&
         (([instructions isKindOfClass:[NSArray class]] && instructions.count > 0) || instructionText.length > 0);
}

static NSInteger MRRRecipeCandidateMatchScore(NSDictionary *candidate, NSString *queryTitle) {
  NSString *candidateTitle = MRRStringOrNil(candidate[@"title"]);
  if (candidateTitle.length == 0) {
    return NSIntegerMin;
  }

  NSString *normalizedCandidateTitle = MRRNormalizedRecipeTitle(candidateTitle);
  NSString *normalizedQueryTitle = MRRNormalizedRecipeTitle(queryTitle);
  NSArray<NSString *> *queryTokens = MRRNormalizedRecipeTitleTokens(queryTitle);

  if ([candidateTitle caseInsensitiveCompare:queryTitle] == NSOrderedSame) {
    return 5000;
  }

  if ([normalizedCandidateTitle isEqualToString:normalizedQueryTitle]) {
    return 4000;
  }

  if ([normalizedCandidateTitle hasPrefix:normalizedQueryTitle]) {
    return 3000;
  }

  BOOL containsAllTokens = YES;
  for (NSString *token in queryTokens) {
    if (token.length == 0) {
      continue;
    }

    if ([normalizedCandidateTitle rangeOfString:token].location == NSNotFound) {
      containsAllTokens = NO;
      break;
    }
  }

  if (containsAllTokens) {
    return 2000;
  }

  return 1000;
}

static NSString *MRRDisplayTextForIngredient(NSDictionary *ingredient) {
  NSString *original = MRRStringOrNil(ingredient[@"original"]);
  if (original.length > 0) {
    return original;
  }

  NSString *name = MRRStringOrNil(ingredient[@"name"]);
  if (name.length > 0) {
    return name;
  }

  return @"Ingredient";
}

static NSArray<OnboardingRecipeIngredient *> *MRRIngredientsFromCandidate(NSDictionary *candidate) {
  NSArray *ingredientPayloads = candidate[@"extendedIngredients"];
  if (![ingredientPayloads isKindOfClass:[NSArray class]] || ingredientPayloads.count == 0) {
    return @[];
  }

  NSMutableArray<OnboardingRecipeIngredient *> *ingredients = [NSMutableArray arrayWithCapacity:ingredientPayloads.count];
  for (NSDictionary *ingredientPayload in ingredientPayloads) {
    if (![ingredientPayload isKindOfClass:[NSDictionary class]]) {
      continue;
    }

    NSString *name = MRRStringOrNil(ingredientPayload[@"name"]) ?: @"Ingredient";
    NSString *displayText = MRRDisplayTextForIngredient(ingredientPayload);
    [ingredients addObject:[[[OnboardingRecipeIngredient alloc] initWithName:name displayText:displayText] autorelease]];
  }

  return ingredients;
}

static NSArray<OnboardingRecipeInstruction *> *MRRInstructionsFromCandidate(NSDictionary *candidate) {
  NSMutableArray<OnboardingRecipeInstruction *> *instructions = [NSMutableArray array];
  NSArray *instructionSections = candidate[@"analyzedInstructions"];
  if ([instructionSections isKindOfClass:[NSArray class]]) {
    for (NSDictionary *section in instructionSections) {
      if (![section isKindOfClass:[NSDictionary class]]) {
        continue;
      }

      NSArray *steps = section[@"steps"];
      if (![steps isKindOfClass:[NSArray class]]) {
        continue;
      }

      for (NSDictionary *step in steps) {
        if (![step isKindOfClass:[NSDictionary class]]) {
          continue;
        }

        NSString *stepText = MRRStringOrNil(step[@"step"]);
        if (stepText.length == 0) {
          continue;
        }

        NSString *title = [NSString stringWithFormat:@"Step %@", step[@"number"] ?: @(instructions.count + 1)];
        [instructions addObject:[[[OnboardingRecipeInstruction alloc] initWithTitle:title detailText:stepText] autorelease]];
      }
    }
  }

  if (instructions.count > 0) {
    return instructions;
  }

  NSString *instructionText = MRRStringOrNil(candidate[@"instructions"]);
  if (instructionText.length == 0) {
    return @[];
  }

  NSArray<NSString *> *components = [instructionText componentsSeparatedByString:@"."];
  NSUInteger stepIndex = 1;
  for (NSString *component in components) {
    NSString *trimmedComponent = [component stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedComponent.length == 0) {
      continue;
    }

    NSString *title = [NSString stringWithFormat:@"Step %lu", (unsigned long)stepIndex];
    [instructions addObject:[[[OnboardingRecipeInstruction alloc] initWithTitle:title detailText:trimmedComponent] autorelease]];
    stepIndex += 1;
  }

  return instructions;
}

static NSString *MRRHumanizedTagString(NSString *value) {
  NSString *string = MRRStringOrNil(value);
  if (string.length == 0) {
    return nil;
  }

  string = [string stringByReplacingOccurrencesOfString:@"-" withString:@" "];
  string = [string stringByReplacingOccurrencesOfString:@"_" withString:@" "];
  NSRegularExpression *whitespaceExpression = [NSRegularExpression regularExpressionWithPattern:@"\\s+" options:0 error:nil];
  string = [whitespaceExpression stringByReplacingMatchesInString:string
                                                         options:0
                                                           range:NSMakeRange(0, string.length)
                                                    withTemplate:@" "];
  string = MRRTrimmedString(string);
  NSString *normalizedString = MRRNormalizedRecipeTitle(string);
  if ([normalizedString isEqualToString:@"main dish"] || [normalizedString isEqualToString:@"main course"]) {
    return @"Main Course";
  }
  return string.length > 0 ? [string localizedCapitalizedString] : nil;
}

static void MRRAppendUniqueString(NSMutableArray<NSString *> *results,
                                  NSMutableSet<NSString *> *seenValues,
                                  NSString *value,
                                  NSUInteger maxCount) {
  NSString *string = MRRHumanizedTagString(value);
  if (string.length == 0) {
    return;
  }

  NSString *normalizedValue = [[string lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (normalizedValue.length == 0 || [seenValues containsObject:normalizedValue]) {
    return;
  }

  if (maxCount > 0 && results.count >= maxCount) {
    return;
  }

  [seenValues addObject:normalizedValue];
  [results addObject:string];
}

static NSArray<NSString *> *MRRToolsFromCandidate(NSDictionary *candidate) {
  NSArray *instructionSections = candidate[@"analyzedInstructions"];
  if (![instructionSections isKindOfClass:[NSArray class]] || instructionSections.count == 0) {
    return @[];
  }

  NSMutableArray<NSString *> *tools = [NSMutableArray array];
  NSMutableSet<NSString *> *seenTools = [NSMutableSet set];

  for (NSDictionary *section in instructionSections) {
    if (![section isKindOfClass:[NSDictionary class]]) {
      continue;
    }

    NSArray *steps = section[@"steps"];
    if (![steps isKindOfClass:[NSArray class]]) {
      continue;
    }

    for (NSDictionary *step in steps) {
      if (![step isKindOfClass:[NSDictionary class]]) {
        continue;
      }

      NSArray *equipmentList = step[@"equipment"];
      if (![equipmentList isKindOfClass:[NSArray class]]) {
        continue;
      }

      for (NSDictionary *equipment in equipmentList) {
        if (![equipment isKindOfClass:[NSDictionary class]]) {
          continue;
        }

        NSString *toolName = MRRStringOrNil(equipment[@"localizedName"]) ?: MRRStringOrNil(equipment[@"name"]);
        MRRAppendUniqueString(tools, seenTools, toolName, 18);
      }
    }
  }

  return tools;
}

static NSArray<NSString *> *MRRTagsFromCandidate(NSDictionary *candidate,
                                                 __unused NSString *selectedTitle,
                                                 __unused NSArray<OnboardingRecipeIngredient *> *ingredients) {
  NSMutableArray<NSString *> *tags = [NSMutableArray array];
  NSMutableSet<NSString *> *seenTags = [NSMutableSet set];
  NSUInteger maximumTagCount = 6;

  NSArray<NSString *> *dishTypes = [candidate[@"dishTypes"] isKindOfClass:[NSArray class]] ? candidate[@"dishTypes"] : nil;
  for (NSString *value in dishTypes) {
    NSString *humanizedValue = MRRHumanizedTagString(value);
    if (humanizedValue.length > 0) {
      MRRAppendUniqueString(tags, seenTags, humanizedValue, maximumTagCount);
      break;
    }
  }

  NSArray<NSString *> *arrayKeys = @[ @"diets", @"cuisines" ];
  BOOL hasVegetarianVariant = NO;
  BOOL hasVeganTag = NO;
  BOOL hasGlutenFreeTag = NO;
  BOOL hasDairyFreeTag = NO;

  for (NSString *key in arrayKeys) {
    NSArray *values = [candidate[key] isKindOfClass:[NSArray class]] ? candidate[key] : nil;
    for (NSString *value in values) {
      NSString *humanizedValue = MRRHumanizedTagString(value);
      NSString *normalizedTag = [[MRRNormalizedRecipeTitle(humanizedValue) lowercaseString]
          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if (normalizedTag.length == 0) {
        continue;
      }

      if ([normalizedTag containsString:@"vegan"]) {
        if (!hasVeganTag) {
          MRRAppendUniqueString(tags, seenTags, humanizedValue, maximumTagCount);
          hasVeganTag = YES;
        }
        hasVegetarianVariant = YES;
        continue;
      }

      if ([normalizedTag containsString:@"vegetarian"]) {
        if (!hasVegetarianVariant && !hasVeganTag) {
          MRRAppendUniqueString(tags, seenTags, humanizedValue, maximumTagCount);
          hasVegetarianVariant = YES;
        }
        continue;
      }

      if ([normalizedTag isEqualToString:@"gluten free"]) {
        if (!hasGlutenFreeTag) {
          MRRAppendUniqueString(tags, seenTags, humanizedValue, maximumTagCount);
          hasGlutenFreeTag = YES;
        }
        continue;
      }

      if ([normalizedTag isEqualToString:@"dairy free"]) {
        if (!hasDairyFreeTag) {
          MRRAppendUniqueString(tags, seenTags, humanizedValue, maximumTagCount);
          hasDairyFreeTag = YES;
        }
        continue;
      }

      MRRAppendUniqueString(tags, seenTags, humanizedValue, maximumTagCount);
    }
  }

  if ([candidate[@"vegan"] respondsToSelector:@selector(boolValue)] && [candidate[@"vegan"] boolValue] && !hasVeganTag) {
    MRRAppendUniqueString(tags, seenTags, @"Vegan", maximumTagCount);
    hasVeganTag = YES;
    hasVegetarianVariant = YES;
  }

  if ([candidate[@"vegetarian"] respondsToSelector:@selector(boolValue)] && [candidate[@"vegetarian"] boolValue] && !hasVegetarianVariant &&
      !hasVeganTag) {
    MRRAppendUniqueString(tags, seenTags, @"Vegetarian", maximumTagCount);
    hasVegetarianVariant = YES;
  }

  if ([candidate[@"glutenFree"] respondsToSelector:@selector(boolValue)] && [candidate[@"glutenFree"] boolValue] && !hasGlutenFreeTag) {
    MRRAppendUniqueString(tags, seenTags, @"Gluten Free", maximumTagCount);
    hasGlutenFreeTag = YES;
  }

  if ([candidate[@"dairyFree"] respondsToSelector:@selector(boolValue)] && [candidate[@"dairyFree"] boolValue] && !hasDairyFreeTag) {
    MRRAppendUniqueString(tags, seenTags, @"Dairy Free", maximumTagCount);
    hasDairyFreeTag = YES;
  }

  if ([candidate[@"veryHealthy"] respondsToSelector:@selector(boolValue)] && [candidate[@"veryHealthy"] boolValue]) {
    MRRAppendUniqueString(tags, seenTags, @"Healthy", maximumTagCount);
  }

  return tags;
}

static NSString *MRRCalorieTextFromCandidate(NSDictionary *candidate, NSString *fallbackText) {
  NSDictionary *nutrition = candidate[@"nutrition"];
  NSArray *nutrients = [nutrition isKindOfClass:[NSDictionary class]] ? nutrition[@"nutrients"] : nil;
  if ([nutrients isKindOfClass:[NSArray class]]) {
    for (NSDictionary *nutrient in nutrients) {
      if (![nutrient isKindOfClass:[NSDictionary class]]) {
        continue;
      }

      NSString *name = [MRRStringOrNil(nutrient[@"name"]) lowercaseString];
      NSNumber *amount = [nutrient[@"amount"] isKindOfClass:[NSNumber class]] ? nutrient[@"amount"] : nil;
      if ([name containsString:@"calories"] && amount != nil) {
        return [NSString stringWithFormat:@"%ld kcal", (long)llround(amount.doubleValue)];
      }
    }
  }

  return fallbackText;
}

static NSString *MRRDurationTextFromCandidate(NSDictionary *candidate, NSString *fallbackText) {
  NSNumber *readyInMinutes = [candidate[@"readyInMinutes"] isKindOfClass:[NSNumber class]] ? candidate[@"readyInMinutes"] : nil;
  if (readyInMinutes != nil && readyInMinutes.integerValue > 0) {
    return [NSString stringWithFormat:@"%ld min", (long)readyInMinutes.integerValue];
  }

  return fallbackText;
}

static NSString *MRRServingsTextFromCandidate(NSDictionary *candidate, NSString *fallbackText) {
  NSNumber *servings = [candidate[@"servings"] isKindOfClass:[NSNumber class]] ? candidate[@"servings"] : nil;
  if (servings != nil && servings.integerValue > 0) {
    return [NSString stringWithFormat:@"%ld servings", (long)servings.integerValue];
  }

  return fallbackText;
}

@interface MRROpenFoodFactsClient : NSObject <MRROpenFoodFactsContextFetching>

@property(nonatomic, retain) NSURLSession *session;
@property(nonatomic, copy) NSString *userAgent;

- (instancetype)initWithSession:(NSURLSession *)session userAgent:(NSString *)userAgent;

@end

@implementation MRROpenFoodFactsClient

- (instancetype)initWithSession:(NSURLSession *)session userAgent:(NSString *)userAgent {
  NSParameterAssert(session != nil);
  NSParameterAssert(userAgent.length > 0);

  self = [super init];
  if (self) {
    _session = [session retain];
    _userAgent = [userAgent copy];
  }

  return self;
}

- (void)dealloc {
  [_session release];
  [_userAgent release];
  [super dealloc];
}

- (void)fetchProductContextForBarcode:(NSString *)barcode completion:(MRROnboardingRecipeProductContextCompletion)completion {
  NSParameterAssert(barcode.length > 0);
  NSParameterAssert(completion != nil);

  MRRRecipeAPIDebugLog(@"Open Food Facts request started for barcode \"%@\".", barcode);
  NSString *requestURLString = [NSString stringWithFormat:@"https://world.openfoodfacts.org/api/v2/product/%@?fields=product_name,brands,quantity,nutrition_grades",
                                                          barcode];
  NSURL *url = [NSURL URLWithString:requestURLString];
  if (url == nil) {
    MRRRecipeAPIDebugLog(@"Open Food Facts request aborted because the URL could not be formed for barcode \"%@\".", barcode);
    completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeInvalidResponse, @"Invalid Open Food Facts request URL."));
    return;
  }

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];

  [[self.session dataTaskWithRequest:request
                   completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                     NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
                     if (error != nil) {
                       MRRRecipeAPIDebugLog(@"Open Food Facts request failed for barcode \"%@\" (status=%ld): %@.", barcode, (long)statusCode,
                                            error.localizedDescription);
                       MRRCompleteOnMainThread(^{
                         completion(nil, error);
                       });
                       return;
                     }

                     NSDictionary *payload = data != nil ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
                     if (![payload isKindOfClass:[NSDictionary class]]) {
                       MRRRecipeAPIDebugLog(@"Open Food Facts returned an invalid payload for barcode \"%@\" (status=%ld).", barcode,
                                            (long)statusCode);
                       MRRCompleteOnMainThread(^{
                         completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeInvalidResponse,
                                                              @"Open Food Facts returned an invalid payload."));
                       });
                       return;
                     }

                     NSDictionary *product = [payload[@"product"] isKindOfClass:[NSDictionary class]] ? payload[@"product"] : nil;
                     NSString *productName = MRRStringOrNil(product[@"product_name"]);
                     if (productName.length == 0) {
                       MRRRecipeAPIDebugLog(@"Open Food Facts did not find usable product data for barcode \"%@\" (status=%ld).", barcode,
                                            (long)statusCode);
                       MRRCompleteOnMainThread(^{
                         completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeNoMatch,
                                                              @"Open Food Facts did not return a product match."));
                       });
                       return;
                     }

                     NSString *brandText = MRRStringOrNil(product[@"brands"]);
                     NSString *nutritionGradeText = MRRCapitalizedNutritionGrade(product[@"nutrition_grades"]);
                     NSString *quantityText = MRRStringOrNil(product[@"quantity"]);
                     MRRRecipeAPIDebugLog(@"Open Food Facts success for barcode \"%@\" (status=%ld): product=\"%@\" brand=\"%@\".", barcode,
                                          (long)statusCode, productName, brandText ?: @"-");
                     OnboardingRecipeProductContext *context =
                         [[[OnboardingRecipeProductContext alloc] initWithProductName:productName
                                                                            brandText:brandText
                                                                   nutritionGradeText:nutritionGradeText
                                                                         quantityText:quantityText] autorelease];
                     MRRCompleteOnMainThread(^{
                       completion(context, nil);
                     });
                   }] resume];
}

@end

@interface MRRRecipeAPIConfiguration ()

@property(nonatomic, copy, readwrite, nullable) NSString *spoonacularAPIKey;
@property(nonatomic, copy, readwrite, nullable) NSString *openFoodFactsUserAgent;

@end

@implementation MRRRecipeAPIConfiguration

- (instancetype)initWithSpoonacularAPIKey:(NSString *)spoonacularAPIKey openFoodFactsUserAgent:(NSString *)openFoodFactsUserAgent {
  self = [super init];
  if (self) {
    _spoonacularAPIKey = [spoonacularAPIKey copy];
    _openFoodFactsUserAgent = [openFoodFactsUserAgent copy];
  }

  return self;
}

- (void)dealloc {
  [_spoonacularAPIKey release];
  [_openFoodFactsUserAgent release];
  [super dealloc];
}

+ (instancetype)configurationFromMainBundle {
  NSString *path = [[NSBundle mainBundle] pathForResource:MRRRecipeAPIConfigurationFileName ofType:MRRRecipeAPIConfigurationExtension];
  NSDictionary *configurationDictionary = path != nil ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
  NSString *spoonacularAPIKey = MRRStringOrNil(configurationDictionary[MRRRecipeAPIConfigurationSpoonacularKey]);
  NSString *openFoodFactsUserAgent = MRRStringOrNil(configurationDictionary[MRRRecipeAPIConfigurationOpenFoodFactsUserAgentKey]);
  MRRRecipeAPIDebugLog(@"Loaded recipe API config from bundle: filePresent=%@ spoonacularKey=%@ openFoodFactsUserAgent=%@.",
                       path != nil ? @"YES" : @"NO", spoonacularAPIKey.length > 0 ? @"YES" : @"NO",
                       openFoodFactsUserAgent.length > 0 ? @"YES" : @"NO");
  return [[[self alloc] initWithSpoonacularAPIKey:spoonacularAPIKey openFoodFactsUserAgent:openFoodFactsUserAgent] autorelease];
}

@end

@interface MRRRemoteOnboardingRecipeSearcher ()

@property(nonatomic, retain) NSURLSession *session;
@property(nonatomic, retain) MRRRecipeAPIConfiguration *configuration;
@property(nonatomic, retain, nullable) id<MRROpenFoodFactsContextFetching> openFoodFactsClient;

- (void)performSpoonacularSearchForPreview:(OnboardingRecipePreview *)preview completion:(MRROnboardingRecipeDetailCompletion)completion;

@end

@implementation MRRRemoteOnboardingRecipeSearcher

- (instancetype)initWithSession:(NSURLSession *)session configuration:(MRRRecipeAPIConfiguration *)configuration {
  NSParameterAssert(session != nil);
  NSParameterAssert(configuration != nil);

  self = [super init];
  if (self) {
    _session = [session retain];
    _configuration = [configuration retain];
    if (configuration.openFoodFactsUserAgent.length > 0) {
      _openFoodFactsClient = [[MRROpenFoodFactsClient alloc] initWithSession:session userAgent:configuration.openFoodFactsUserAgent];
    }
  }

  return self;
}

- (void)dealloc {
  [_openFoodFactsClient release];
  [_configuration release];
  [_session release];
  [super dealloc];
}

- (void)fetchRecipeDetailForPreview:(OnboardingRecipePreview *)preview completion:(MRROnboardingRecipeDetailCompletion)completion {
  NSParameterAssert(preview != nil);
  NSParameterAssert(completion != nil);

  if (self.configuration.spoonacularAPIKey.length == 0) {
    MRRRecipeAPIDebugLog(@"Skipping live recipe lookup for \"%@\" because Spoonacular API key is not configured.", preview.title);
    completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeUnconfigured,
                                         @"Spoonacular API key is not configured."));
    return;
  }

  BOOL shouldFetchProductContext = preview.openFoodFactsBarcode.length > 0 && self.openFoodFactsClient != nil;
  MRRRecipeAPIDebugLog(@"Starting recipe lookup for \"%@\". openFoodFactsEnrichment=%@.", preview.title,
                       shouldFetchProductContext ? @"YES" : @"NO");
  if (!shouldFetchProductContext) {
    [self performSpoonacularSearchForPreview:preview completion:completion];
    return;
  }

  __block BOOL didComplete = NO;
  __block BOOL productContextFinished = NO;
  __block OnboardingRecipeProductContext *capturedProductContext = nil;
  __block OnboardingRecipeDetail *capturedDetail = nil;

  __block MRRRemoteOnboardingRecipeSearcher *blockSelf = self;
  [self.openFoodFactsClient fetchProductContextForBarcode:preview.openFoodFactsBarcode
                                               completion:^(OnboardingRecipeProductContext *productContext, NSError *error) {
                                                 if (didComplete) {
                                                   return;
                                                 }

                                                 productContextFinished = YES;
                                                 capturedProductContext = [productContext retain];
                                                 if (error != nil) {
                                                   MRRRecipeAPIDebugLog(@"Open Food Facts enrichment will be omitted for \"%@\": %@.", preview.title,
                                                                        error.localizedDescription);
                                                 }
                                                 if (capturedDetail == nil) {
                                                   return;
                                                 }

                                                 didComplete = YES;
                                                 OnboardingRecipeDetail *detail =
                                                     [[[OnboardingRecipeDetail alloc] initWithTitle:capturedDetail.title
                                                                                           subtitle:capturedDetail.subtitle
                                                                                          assetName:capturedDetail.assetName
                                                                                 heroImageURLString:capturedDetail.heroImageURLString
                                                                                       durationText:capturedDetail.durationText
                                                                                        calorieText:capturedDetail.calorieText
                                                                                       servingsText:capturedDetail.servingsText
                                                                                        summaryText:capturedDetail.summaryText
                                                                                        ingredients:capturedDetail.ingredients
                                                                                       instructions:capturedDetail.instructions
                                                                                               tools:capturedDetail.tools
                                                                                                tags:capturedDetail.tags
                                                                                         sourceName:capturedDetail.sourceName
                                                                                    sourceURLString:capturedDetail.sourceURLString
                                                                                     productContext:capturedProductContext] autorelease];
                                                 [capturedProductContext release];
                                                 capturedProductContext = nil;
                                                 [capturedDetail release];
                                                 capturedDetail = nil;
                                                 blockSelf = nil;
                                                 MRRRecipeAPIDebugLog(@"Returning live detail for \"%@\" with Open Food Facts context.", preview.title);
                                                 completion(detail, nil);
                                               }];

  [self performSpoonacularSearchForPreview:preview
                                completion:^(OnboardingRecipeDetail *detail, NSError *error) {
                                  if (didComplete) {
                                    return;
                                  }

                                  if (error != nil || detail == nil) {
                                    didComplete = YES;
                                    [capturedProductContext release];
                                    capturedProductContext = nil;
                                    blockSelf = nil;
                                    MRRRecipeAPIDebugLog(@"Recipe lookup failed for \"%@\": %@.", preview.title,
                                                         error.localizedDescription ?: @"No usable detail was returned.");
                                    completion(nil, error ?: MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeNoMatch,
                                                                                 @"No recipe detail match was found."));
                                    return;
                                  }

                                  if (productContextFinished) {
                                    didComplete = YES;
                                    OnboardingRecipeDetail *finalDetail =
                                        [[[OnboardingRecipeDetail alloc] initWithTitle:detail.title
                                                                              subtitle:detail.subtitle
                                                                             assetName:detail.assetName
                                                                    heroImageURLString:detail.heroImageURLString
                                                                          durationText:detail.durationText
                                                                           calorieText:detail.calorieText
                                                                          servingsText:detail.servingsText
                                                                           summaryText:detail.summaryText
                                                                           ingredients:detail.ingredients
                                                                          instructions:detail.instructions
                                                                                  tools:detail.tools
                                                                                   tags:detail.tags
                                                                            sourceName:detail.sourceName
                                                                        sourceURLString:detail.sourceURLString
                                                                        productContext:capturedProductContext] autorelease];
                                    [capturedProductContext release];
                                    capturedProductContext = nil;
                                    blockSelf = nil;
                                    MRRRecipeAPIDebugLog(@"Returning live detail for \"%@\" without product context.", preview.title);
                                    completion(finalDetail, nil);
                                    return;
                                  }

                                  capturedDetail = [detail retain];
                                }];
}

- (void)performSpoonacularSearchForPreview:(OnboardingRecipePreview *)preview completion:(MRROnboardingRecipeDetailCompletion)completion {
  MRRRecipeAPIDebugLog(@"Spoonacular search started for title \"%@\".", preview.title);
  NSURLComponents *components = [[[NSURLComponents alloc] initWithString:@"https://api.spoonacular.com/recipes/complexSearch"] autorelease];
  components.queryItems = @[
    [NSURLQueryItem queryItemWithName:@"apiKey" value:self.configuration.spoonacularAPIKey],
    [NSURLQueryItem queryItemWithName:@"query" value:preview.title],
    [NSURLQueryItem queryItemWithName:@"number" value:@"5"],
    [NSURLQueryItem queryItemWithName:@"addRecipeInformation" value:@"true"],
    [NSURLQueryItem queryItemWithName:@"fillIngredients" value:@"true"],
    [NSURLQueryItem queryItemWithName:@"instructionsRequired" value:@"true"]
  ];

  NSURL *url = components.URL;
  if (url == nil) {
    MRRRecipeAPIDebugLog(@"Spoonacular request aborted because the URL could not be formed for \"%@\".", preview.title);
    completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeInvalidResponse, @"Invalid Spoonacular request URL."));
    return;
  }

  [[self.session dataTaskWithURL:url
               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                 NSInteger statusCode = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 0;
                 if (error != nil) {
                   MRRRecipeAPIDebugLog(@"Spoonacular request failed for \"%@\" (status=%ld): %@.", preview.title, (long)statusCode,
                                        error.localizedDescription);
                   MRRCompleteOnMainThread(^{
                     completion(nil, error);
                   });
                   return;
                 }

                 NSDictionary *payload = data != nil ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
                 if (![payload isKindOfClass:[NSDictionary class]]) {
                   MRRRecipeAPIDebugLog(@"Spoonacular returned an invalid payload for \"%@\" (status=%ld).", preview.title,
                                        (long)statusCode);
                   MRRCompleteOnMainThread(^{
                     completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeInvalidResponse,
                                                          @"Spoonacular returned an invalid payload."));
                   });
                   return;
                 }

                 NSArray *results = [payload[@"results"] isKindOfClass:[NSArray class]] ? payload[@"results"] : nil;
                 NSArray *usableResults = [results filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *candidate,
                                                                                                                   NSDictionary *bindings) {
                   return [candidate isKindOfClass:[NSDictionary class]] && MRRCandidateHasRequiredDetail(candidate);
                 }]];
                 MRRRecipeAPIDebugLog(@"Spoonacular responded for \"%@\" (status=%ld): rawCandidates=%lu usableCandidates=%lu.", preview.title,
                                      (long)statusCode, (unsigned long)results.count, (unsigned long)usableResults.count);
                 if (results.count == 0) {
                    MRRCompleteOnMainThread(^{
                      completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeNoMatch,
                                                           @"Spoonacular did not return any recipe candidates."));
                   });
                   return;
                 }

                 NSArray *candidates = usableResults.count > 0 ? usableResults : results;
                 NSDictionary *bestCandidate = nil;
                 NSInteger bestScore = NSIntegerMin;

                 for (NSUInteger index = 0; index < candidates.count; index++) {
                   NSDictionary *candidate = candidates[index];
                   if (![candidate isKindOfClass:[NSDictionary class]]) {
                     continue;
                   }

                   NSInteger score = MRRRecipeCandidateMatchScore(candidate, preview.title) - (NSInteger)index;
                   if (score > bestScore) {
                     bestScore = score;
                     bestCandidate = candidate;
                   }
                 }

                 if (bestCandidate == nil || !MRRCandidateHasRequiredDetail(bestCandidate)) {
                   MRRRecipeAPIDebugLog(@"Spoonacular did not yield a usable best candidate for \"%@\".", preview.title);
                   MRRCompleteOnMainThread(^{
                     completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeNoMatch,
                                                          @"Spoonacular did not return a usable recipe detail match."));
                   });
                   return;
                 }

                 NSArray<OnboardingRecipeIngredient *> *ingredients = MRRIngredientsFromCandidate(bestCandidate);
                 NSArray<OnboardingRecipeInstruction *> *instructions = MRRInstructionsFromCandidate(bestCandidate);
                 NSArray<NSString *> *tools = MRRToolsFromCandidate(bestCandidate);
                 if (ingredients.count == 0 || instructions.count == 0) {
                   MRRRecipeAPIDebugLog(@"Selected Spoonacular candidate for \"%@\" is missing structured ingredients or instructions.", preview.title);
                   MRRCompleteOnMainThread(^{
                     completion(nil, MRRRecipeSearchError(MRROnboardingRecipeSearchErrorCodeInvalidResponse,
                                                          @"Spoonacular recipe detail is missing ingredients or instructions."));
                   });
                   return;
                 }

                 OnboardingRecipeDetail *fallbackDetail = preview.fallbackDetail;
                 NSString *summaryText = MRRRecipeSummaryFromHTMLString(bestCandidate[@"summary"]) ?: fallbackDetail.summaryText;
                 NSString *sourceName = MRRStringOrNil(bestCandidate[@"sourceName"]);
                 NSString *sourceURLString = MRRStringOrNil(bestCandidate[@"sourceUrl"]);
                 NSString *heroImageURLString = MRRStringOrNil(bestCandidate[@"image"]);
                 NSString *selectedTitle = MRRStringOrNil(bestCandidate[@"title"]) ?: preview.title;
                 NSArray<NSString *> *tags = MRRTagsFromCandidate(bestCandidate, selectedTitle, ingredients);
                 MRRRecipeAPIDebugLog(@"Selected Spoonacular candidate for \"%@\": title=\"%@\" score=%ld ingredients=%lu instructions=%lu source=\"%@\".",
                                      preview.title, selectedTitle, (long)bestScore, (unsigned long)ingredients.count,
                                      (unsigned long)instructions.count, sourceName ?: @"-");
                 OnboardingRecipeDetail *detail =
                     [[[OnboardingRecipeDetail alloc] initWithTitle:selectedTitle
                                                           subtitle:preview.subtitle
                                                          assetName:preview.assetName
                                                 heroImageURLString:heroImageURLString
                                                       durationText:MRRDurationTextFromCandidate(bestCandidate, fallbackDetail.durationText)
                                                        calorieText:MRRCalorieTextFromCandidate(bestCandidate, fallbackDetail.calorieText)
                                                       servingsText:MRRServingsTextFromCandidate(bestCandidate, fallbackDetail.servingsText)
                                                        summaryText:summaryText
                                                        ingredients:ingredients
                                                       instructions:instructions
                                                               tools:tools
                                                                tags:tags
                                                         sourceName:sourceName
                                                    sourceURLString:sourceURLString
                                                     productContext:nil] autorelease];

                 MRRCompleteOnMainThread(^{
                   MRRRecipeAPIDebugLog(@"Spoonacular detail ready for \"%@\".", preview.title);
                   completion(detail, nil);
                 });
               }] resume];
}

@end
