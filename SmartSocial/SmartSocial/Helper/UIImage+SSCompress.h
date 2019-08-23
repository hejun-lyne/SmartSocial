//
//  UIImage+SSCompress.h
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#if __cplusplus
extern "C" {
#endif
    NSData * SSCompressImageData(NSData *data, NSUInteger maxBytes);
#if __cplusplus
}
#endif

@interface UIImage (SSCompress)

- (NSData *)compressWithinBytes:(NSUInteger)maxBytes;

@end

NS_ASSUME_NONNULL_END
