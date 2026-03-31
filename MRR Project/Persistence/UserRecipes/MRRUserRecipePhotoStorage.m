#import "MRRUserRecipePhotoStorage.h"

NSErrorDomain const MRRUserRecipePhotoStorageErrorDomain = @"MRRUserRecipePhotoStorageErrorDomain";

static NSString *MRRUserRecipePhotoStorageTrimmedString(NSString *value) {
  return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@interface MRRLocalUserRecipePhotoStorage ()

@property(nonatomic, retain) NSURL *baseDirectoryURL;
@property(nonatomic, retain) NSFileManager *fileManager;

- (BOOL)ensureBaseDirectoryExists:(NSError *_Nullable *_Nullable)error;
- (nullable NSURL *)resolvedBaseDirectoryURL;
- (nullable NSURL *)directoryURLForRecipeID:(NSString *)recipeID;

@end

@implementation MRRLocalUserRecipePhotoStorage

- (instancetype)init {
  return [self initWithBaseDirectoryURL:nil fileManager:nil];
}

- (instancetype)initWithBaseDirectoryURL:(NSURL *)baseDirectoryURL fileManager:(NSFileManager *)fileManager {
  self = [super init];
  if (self) {
    _baseDirectoryURL = [baseDirectoryURL retain];
    _fileManager = [(fileManager ?: [NSFileManager defaultManager]) retain];
  }
  return self;
}

- (void)dealloc {
  [_fileManager release];
  [_baseDirectoryURL release];
  [super dealloc];
}

- (NSURL *)resolvedBaseDirectoryURL {
  if (self.baseDirectoryURL != nil) {
    return self.baseDirectoryURL;
  }

  NSURL *applicationSupportURL =
      [[self.fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] firstObject];
  if (applicationSupportURL == nil) {
    return nil;
  }

  return [applicationSupportURL URLByAppendingPathComponent:@"UserRecipePhotos" isDirectory:YES];
}

- (NSURL *)directoryURLForRecipeID:(NSString *)recipeID {
  NSString *resolvedRecipeID = MRRUserRecipePhotoStorageTrimmedString(recipeID ?: @"");
  if (resolvedRecipeID.length == 0) {
    return nil;
  }
  NSURL *baseDirectoryURL = [self resolvedBaseDirectoryURL];
  if (baseDirectoryURL == nil) {
    return nil;
  }
  return [baseDirectoryURL URLByAppendingPathComponent:resolvedRecipeID isDirectory:YES];
}

- (BOOL)ensureBaseDirectoryExists:(NSError **)error {
  NSURL *baseDirectoryURL = [self resolvedBaseDirectoryURL];
  if (baseDirectoryURL == nil) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRUserRecipePhotoStorageErrorDomain
                                   code:MRRUserRecipePhotoStorageErrorCodeDirectoryCreationFailed
                               userInfo:@{NSLocalizedDescriptionKey : @"Photo storage directory could not be resolved."}];
    }
    return NO;
  }

  return [self.fileManager createDirectoryAtURL:baseDirectoryURL
                    withIntermediateDirectories:YES
                                     attributes:nil
                                          error:error];
}

- (NSString *)storeImage:(UIImage *)image recipeID:(NSString *)recipeID photoID:(NSString *)photoID error:(NSError **)error {
  NSString *resolvedPhotoID = MRRUserRecipePhotoStorageTrimmedString(photoID ?: @"");
  NSURL *recipeDirectoryURL = [self directoryURLForRecipeID:recipeID];
  if (image == nil || recipeDirectoryURL == nil || resolvedPhotoID.length == 0) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRUserRecipePhotoStorageErrorDomain
                                   code:MRRUserRecipePhotoStorageErrorCodeFileWriteFailed
                               userInfo:@{NSLocalizedDescriptionKey : @"Photo could not be prepared for storage."}];
    }
    return nil;
  }

  NSError *directoryError = nil;
  if (![self ensureBaseDirectoryExists:&directoryError] ||
      ![self.fileManager createDirectoryAtURL:recipeDirectoryURL withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
    if (error != NULL) {
      *error = directoryError ?: [NSError errorWithDomain:MRRUserRecipePhotoStorageErrorDomain
                                                     code:MRRUserRecipePhotoStorageErrorCodeDirectoryCreationFailed
                                                 userInfo:@{NSLocalizedDescriptionKey : @"Photo directory could not be created."}];
    }
    return nil;
  }

  NSData *imageData = UIImageJPEGRepresentation(image, 0.88);
  if (imageData.length == 0) {
    if (error != NULL) {
      *error = [NSError errorWithDomain:MRRUserRecipePhotoStorageErrorDomain
                                   code:MRRUserRecipePhotoStorageErrorCodeImageEncodingFailed
                               userInfo:@{NSLocalizedDescriptionKey : @"Photo could not be encoded."}];
    }
    return nil;
  }

  NSURL *fileURL = [recipeDirectoryURL URLByAppendingPathComponent:[resolvedPhotoID stringByAppendingPathExtension:@"jpg"]];
  NSError *writeError = nil;
  if (![imageData writeToURL:fileURL options:NSDataWritingAtomic error:&writeError]) {
    if (error != NULL) {
      *error = writeError ?: [NSError errorWithDomain:MRRUserRecipePhotoStorageErrorDomain
                                                 code:MRRUserRecipePhotoStorageErrorCodeFileWriteFailed
                                             userInfo:@{NSLocalizedDescriptionKey : @"Photo could not be written."}];
    }
    return nil;
  }

  NSURL *baseDirectoryURL = [self resolvedBaseDirectoryURL];
  NSString *basePath = baseDirectoryURL.path ?: @"";
  NSString *filePath = fileURL.path ?: @"";
  if (basePath.length == 0 || filePath.length == 0 || ![filePath hasPrefix:basePath]) {
    return nil;
  }

  NSString *relativePath = [filePath substringFromIndex:basePath.length];
  while ([relativePath hasPrefix:@"/"]) {
    relativePath = [relativePath substringFromIndex:1];
  }
  return relativePath;
}

- (UIImage *)imageForRelativePath:(NSString *)relativePath {
  NSURL *fileURL = [self fileURLForRelativePath:relativePath];
  if (fileURL == nil) {
    return nil;
  }
  return [UIImage imageWithContentsOfFile:fileURL.path];
}

- (NSURL *)fileURLForRelativePath:(NSString *)relativePath {
  NSString *resolvedRelativePath = MRRUserRecipePhotoStorageTrimmedString(relativePath ?: @"");
  NSURL *baseDirectoryURL = [self resolvedBaseDirectoryURL];
  if (resolvedRelativePath.length == 0 || baseDirectoryURL == nil) {
    return nil;
  }
  return [baseDirectoryURL URLByAppendingPathComponent:resolvedRelativePath];
}

- (BOOL)removeImageAtRelativePath:(NSString *)relativePath error:(NSError **)error {
  NSURL *fileURL = [self fileURLForRelativePath:relativePath];
  if (fileURL == nil) {
    return YES;
  }
  if (![self.fileManager fileExistsAtPath:fileURL.path]) {
    return YES;
  }

  NSError *removeError = nil;
  if (![self.fileManager removeItemAtURL:fileURL error:&removeError]) {
    if (error != NULL) {
      *error = removeError ?: [NSError errorWithDomain:MRRUserRecipePhotoStorageErrorDomain
                                                  code:MRRUserRecipePhotoStorageErrorCodeFileDeleteFailed
                                              userInfo:@{NSLocalizedDescriptionKey : @"Photo file could not be removed."}];
    }
    return NO;
  }
  return YES;
}

- (BOOL)removeImagesForRecipeID:(NSString *)recipeID error:(NSError **)error {
  NSURL *recipeDirectoryURL = [self directoryURLForRecipeID:recipeID];
  if (recipeDirectoryURL == nil || ![self.fileManager fileExistsAtPath:recipeDirectoryURL.path]) {
    return YES;
  }

  NSError *removeError = nil;
  if (![self.fileManager removeItemAtURL:recipeDirectoryURL error:&removeError]) {
    if (error != NULL) {
      *error = removeError ?: [NSError errorWithDomain:MRRUserRecipePhotoStorageErrorDomain
                                                  code:MRRUserRecipePhotoStorageErrorCodeFileDeleteFailed
                                              userInfo:@{NSLocalizedDescriptionKey : @"Recipe photo directory could not be removed."}];
    }
    return NO;
  }
  return YES;
}

@end
