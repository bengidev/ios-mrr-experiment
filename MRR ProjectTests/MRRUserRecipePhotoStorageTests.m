#import <XCTest/XCTest.h>

#import "../MRR Project/Persistence/UserRecipes/MRRUserRecipePhotoStorage.h"

@interface MRRUserRecipePhotoStorageTests : XCTestCase

@property(nonatomic, strong) NSURL *baseDirectoryURL;
@property(nonatomic, strong) MRRLocalUserRecipePhotoStorage *storage;

@end

@implementation MRRUserRecipePhotoStorageTests

- (void)setUp {
  [super setUp];

  self.baseDirectoryURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString]
                                     isDirectory:YES];
  self.storage = [[MRRLocalUserRecipePhotoStorage alloc] initWithBaseDirectoryURL:self.baseDirectoryURL fileManager:[NSFileManager defaultManager]];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtURL:self.baseDirectoryURL error:nil];
  self.storage = nil;
  self.baseDirectoryURL = nil;
  [super tearDown];
}

- (void)testStoreLoadAndRemoveImageAtRelativePath {
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0, 20.0), YES, 1.0);
  [[UIColor orangeColor] setFill];
  UIRectFill(CGRectMake(0.0, 0.0, 20.0, 20.0));
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  NSError *storeError = nil;
  NSString *relativePath = [self.storage storeImage:image recipeID:@"recipe-1" photoID:@"photo-1" error:&storeError];
  XCTAssertNil(storeError);
  XCTAssertNotNil(relativePath);

  UIImage *loadedImage = [self.storage imageForRelativePath:relativePath];
  XCTAssertNotNil(loadedImage);
  XCTAssertNotNil([self.storage fileURLForRelativePath:relativePath]);

  NSError *removeError = nil;
  XCTAssertTrue([self.storage removeImageAtRelativePath:relativePath error:&removeError]);
  XCTAssertNil(removeError);
  XCTAssertNil([self.storage imageForRelativePath:relativePath]);
}

- (void)testRemoveImagesForRecipeIDDeletesRecipeDirectory {
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0, 20.0), YES, 1.0);
  [[UIColor blueColor] setFill];
  UIRectFill(CGRectMake(0.0, 0.0, 20.0, 20.0));
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  NSError *storeError = nil;
  NSString *relativePath = [self.storage storeImage:image recipeID:@"recipe-2" photoID:@"photo-a" error:&storeError];
  XCTAssertNil(storeError);
  XCTAssertNotNil(relativePath);

  NSError *removeError = nil;
  XCTAssertTrue([self.storage removeImagesForRecipeID:@"recipe-2" error:&removeError]);
  XCTAssertNil(removeError);
  XCTAssertNil([self.storage imageForRelativePath:relativePath]);
}

@end
