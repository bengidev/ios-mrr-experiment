#import <XCTest/XCTest.h>

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
  OnboardingStateController *stateController = [self makeStateController];

  NSArray<OnboardingRecipe *> *recipes = [stateController onboardingRecipes];

  XCTAssertGreaterThan(recipes.count, 0);

  for (OnboardingRecipe *recipe in recipes) {
    XCTAssertGreaterThan(recipe.title.length, 0);
    XCTAssertGreaterThan(recipe.subtitle.length, 0);
    XCTAssertGreaterThan(recipe.assetName.length, 0);
    XCTAssertGreaterThan(recipe.durationText.length, 0);
    XCTAssertGreaterThan(recipe.calorieText.length, 0);
    XCTAssertGreaterThan(recipe.servingsText.length, 0);
    XCTAssertGreaterThan(recipe.summaryText.length, 0);
    XCTAssertGreaterThan(recipe.ingredients.count, 0);
    XCTAssertGreaterThan(recipe.instructions.count, 0);

    for (OnboardingRecipeInstruction *instruction in recipe.instructions) {
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
