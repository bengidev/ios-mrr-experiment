#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MRRUserRecipePhotoStorageErrorDomain;

typedef NS_ENUM(NSInteger, MRRUserRecipePhotoStorageErrorCode) {
  MRRUserRecipePhotoStorageErrorCodeImageEncodingFailed = 1,
  MRRUserRecipePhotoStorageErrorCodeDirectoryCreationFailed = 2,
  MRRUserRecipePhotoStorageErrorCodeFileWriteFailed = 3,
  MRRUserRecipePhotoStorageErrorCodeFileDeleteFailed = 4,
};

@protocol MRRUserRecipePhotoStorage <NSObject>

- (nullable NSString *)storeImage:(UIImage *)image
                         recipeID:(NSString *)recipeID
                          photoID:(NSString *)photoID
                            error:(NSError *_Nullable *_Nullable)error;
- (nullable UIImage *)imageForRelativePath:(NSString *)relativePath;
- (nullable NSURL *)fileURLForRelativePath:(NSString *)relativePath;
- (BOOL)removeImageAtRelativePath:(NSString *)relativePath error:(NSError *_Nullable *_Nullable)error;
- (BOOL)removeImagesForRecipeID:(NSString *)recipeID error:(NSError *_Nullable *_Nullable)error;

@end

@interface MRRLocalUserRecipePhotoStorage : NSObject <MRRUserRecipePhotoStorage>

- (instancetype)init;
- (instancetype)initWithBaseDirectoryURL:(nullable NSURL *)baseDirectoryURL
                             fileManager:(nullable NSFileManager *)fileManager NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
