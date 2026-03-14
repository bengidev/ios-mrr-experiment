#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRRAuthErrorMapper : NSObject

+ (NSString *)titleForError:(NSError *)error;
+ (NSString *)messageForError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
