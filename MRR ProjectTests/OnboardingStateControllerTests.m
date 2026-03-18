#import <XCTest/XCTest.h>

#import "../MRR Project/Features/Onboarding/Data/OnboardingRecipeCatalog.h"
#import "../MRR Project/Features/Onboarding/Data/OnboardingStateController.h"

@interface OnboardingStateControllerTests : XCTestCase

@property(nonatomic, copy) NSString *defaultsSuiteName;
@property(nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation OnboardingStateControllerTests

- (void)setUp {
  [super setUp];

  self.defaultsSuiteName = [NSString stringWithFormat:@"OnboardingStateControllerTests.%@", [NSUUID UUID].UUIDString];
  self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:self.defaultsSuiteName];
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
}

- (void)tearDown {
  [self.userDefaults removePersistentDomainForName:self.defaultsSuiteName];
  self.userDefaults = nil;
  self.defaultsSuiteName = nil;

  [super tearDown];
}

- (void)testOnboardingRecipesContainRequiredStructuredFields {
  OnboardingRecipeCatalog *recipeCatalog = [[OnboardingRecipeCatalog alloc] init];
  NSArray<OnboardingRecipePreview *> *recipes = [recipeCatalog allRecipePreviews];

  XCTAssertGreaterThan(recipes.count, 0);

  for (OnboardingRecipePreview *recipe in recipes) {
    XCTAssertGreaterThan(recipe.title.length, 0);
    XCTAssertGreaterThan(recipe.subtitle.length, 0);
    XCTAssertGreaterThan(recipe.assetName.length, 0);
    XCTAssertNotNil(recipe.fallbackDetail);
    XCTAssertGreaterThan(recipe.fallbackDetail.durationText.length, 0);
    XCTAssertGreaterThan(recipe.fallbackDetail.calorieText.length, 0);
    XCTAssertGreaterThan(recipe.fallbackDetail.servingsText.length, 0);
    XCTAssertGreaterThan(recipe.fallbackDetail.summaryText.length, 0);
    XCTAssertGreaterThan(recipe.fallbackDetail.ingredients.count, 0);
    XCTAssertGreaterThan(recipe.fallbackDetail.instructions.count, 0);

    for (OnboardingRecipeInstruction *instruction in recipe.fallbackDetail.instructions) {
      XCTAssertGreaterThan(instruction.title.length, 0);
      XCTAssertGreaterThan(instruction.detailText.length, 0);
    }
  }
}

- (void)testMarkOnboardingCompletedPersistsFlag {
  OnboardingStateController *stateController = [self makeStateController];

  XCTAssertFalse([stateController hasCompletedOnboarding]);

  [stateController markOnboardingCompleted];

  XCTAssertTrue([stateController hasCompletedOnboarding]);
  XCTAssertTrue([self.userDefaults boolForKey:MRRHasCompletedOnboardingDefaultsKey]);
}

- (OnboardingStateController *)makeStateController {
  return [[OnboardingStateController alloc] initWithUserDefaults:self.userDefaults];
}

@end
