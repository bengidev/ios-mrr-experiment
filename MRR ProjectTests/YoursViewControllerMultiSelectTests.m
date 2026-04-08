//
//  YoursViewControllerMultiSelectTests.m
//  MRR ProjectTests
//
//  Multi-select functionality tests for YoursViewController
//

#import <XCTest/XCTest.h>
#import "YoursViewController.h"
#import "MRRUserRecipesStore.h"
#import "MRRSyncEngine.h"
#import "MRRPhotoStorage.h"

@interface YoursViewControllerMultiSelectTests : XCTestCase
@property(nonatomic, strong) YoursViewController *viewController;
@property(nonatomic, strong) MRRUserRecipesStore *mockStore;
@property(nonatomic, strong) MRRSyncEngine *mockSyncEngine;
@property(nonatomic, strong) MRRPhotoStorage *mockPhotoStorage;
@end

@implementation YoursViewControllerMultiSelectTests

- (void)setUp {
  [super setUp];
  // Create real dependencies for testing
  self.mockStore = [[MRRUserRecipesStore alloc] init];
  self.mockSyncEngine = [[MRRSyncEngine alloc] init];
  self.mockPhotoStorage = [[MRRPhotoStorage alloc] init];

  self.viewController = [[YoursViewController alloc] initWithSessionUserID:@"test-user"
                                                        userRecipesStore:self.mockStore
                                                              syncEngine:self.mockSyncEngine
                                                            photoStorage:self.mockPhotoStorage];
}

- (void)tearDown {
  self.viewController = nil;
  self.mockStore = nil;
  self.mockSyncEngine = nil;
  self.mockPhotoStorage = nil;
  [super tearDown];
}

#pragma mark - Selection Mode Tests

- (void)testInitialState_isNotInSelectionMode {
  XCTAssertFalse(self.viewController.isSelectionMode, @"Initial state should not be in selection mode");
}

- (void)testEnterSelectionMode_setsIsSelectionModeToYES {
  // When
  [self.viewController handleEditButtonTapped:nil];

  // Then
  XCTAssertTrue(self.viewController.isSelectionMode, @"Should enter selection mode");
}

- (void)testExitSelectionMode_setsIsSelectionModeToNO {
  // Given
  [self.viewController handleEditButtonTapped:nil];
  XCTAssertTrue(self.viewController.isSelectionMode);

  // When
  [self.viewController handleDoneButtonTapped:nil];

  // Then
  XCTAssertFalse(self.viewController.isSelectionMode, @"Should exit selection mode");
}

- (void)testExitSelectionMode_clearsSelectedRecipeIDs {
  // Given
  [self.viewController handleEditButtonTapped:nil];
  [self.viewController.selectedRecipeIDs addObject:@"recipe-123"];
  XCTAssertEqual(self.viewController.selectedRecipeIDs.count, 1);

  // When
  [self.viewController handleDoneButtonTapped:nil];

  // Then
  XCTAssertEqual(self.viewController.selectedRecipeIDs.count, 0, @"Should clear selected recipes");
}

#pragma mark - Recipe Selection Tests

- (void)testSelectedRecipeIDs_initiallyEmpty {
  XCTAssertEqual(self.viewController.selectedRecipeIDs.count, 0, @"Selected recipes should be empty initially");
}

- (void)testAddRecipeToSelection_increasesCount {
  // When
  [self.viewController.selectedRecipeIDs addObject:@"recipe-123"];

  // Then
  XCTAssertEqual(self.viewController.selectedRecipeIDs.count, 1);
  XCTAssertTrue([self.viewController.selectedRecipeIDs containsObject:@"recipe-123"]);
}

- (void)testRemoveRecipeFromSelection_decreasesCount {
  // Given
  [self.viewController.selectedRecipeIDs addObject:@"recipe-123"];
  [self.viewController.selectedRecipeIDs addObject:@"recipe-456"];
  XCTAssertEqual(self.viewController.selectedRecipeIDs.count, 2);

  // When
  [self.viewController.selectedRecipeIDs removeObject:@"recipe-123"];

  // Then
  XCTAssertEqual(self.viewController.selectedRecipeIDs.count, 1);
  XCTAssertFalse([self.viewController.selectedRecipeIDs containsObject:@"recipe-123"]);
  XCTAssertTrue([self.viewController.selectedRecipeIDs containsObject:@"recipe-456"]);
}

- (void)testMultipleRecipeSelection_countIsCorrect {
  // When
  [self.viewController.selectedRecipeIDs addObject:@"recipe-1"];
  [self.viewController.selectedRecipeIDs addObject:@"recipe-2"];
  [self.viewController.selectedRecipeIDs addObject:@"recipe-3"];

  // Then
  XCTAssertEqual(self.viewController.selectedRecipeIDs.count, 3);
}

#pragma mark - Selection State Persistence Tests

- (void)testSelectionState_clearsOnExit {
  // Given
  [self.viewController handleEditButtonTapped:nil];
  [self.viewController.selectedRecipeIDs addObject:@"recipe-123"];

  // When - exit selection mode
  [self.viewController handleDoneButtonTapped:nil];

  // Then - should be empty because Done clears selection
  XCTAssertEqual(self.viewController.selectedRecipeIDs.count, 0);
}

#pragma mark - Toolbar State Tests

- (void)testSelectionToolbar_initiallyNil {
  XCTAssertNil(self.viewController.selectionToolbar);
}

- (void)testEditBarButtonItem_initiallyNil {
  XCTAssertNil(self.viewController.editBarButtonItem);
}

- (void)testDoneBarButtonItem_initiallyNil {
  XCTAssertNil(self.viewController.doneBarButtonItem);
}

@end

