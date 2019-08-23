//
//  UIImage+SSCompress.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "UIImage+SSCompress.h"

NSData * SSCompressImageData(NSData *data, NSUInteger maxBytes) {
    if (maxBytes >= data.length) {
        return data;
    }
    UIImage *image = [UIImage imageWithData:data];
    if (!image) {
        return data;
    }
    
    //面积减小 n 倍，相当于长宽减小根号 n。实际发现 sqrt 完之后，图片经常还是偏大，所以再打个八折
    double compressFactor = sqrt((double)maxBytes / (double)data.length) * 0.8;
    
    CGSize size = CGSizeMake(floor(image.size.width * compressFactor), floor(image.size.height * compressFactor));
    
    CGImageRef cgImage = image.CGImage;
    
    UIImage *resized = nil;
    
    if (cgImage) {
        CGContextRef ctx = CGBitmapContextCreate(nil, size.width, size.height, CGImageGetBitsPerComponent(cgImage), CGImageGetBytesPerRow(cgImage), CGImageGetColorSpace(cgImage), CGImageGetBitmapInfo(cgImage));
        
        CGContextSetInterpolationQuality(ctx, kCGInterpolationDefault);
        
        CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), cgImage);
        
        resized = [UIImage imageWithCGImage:CGBitmapContextCreateImage(ctx)];
        CGContextRelease(ctx);
    }else{
        UIGraphicsBeginImageContext(size);
        [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
        resized = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    NSData *resizedData = UIImageJPEGRepresentation(resized, 1.0);
    if (!resized) {
        return data;
    }
    if (resizedData.length <= maxBytes) {
        return resizedData;
    }
    
    return SSCompressImageData(resizedData, maxBytes);
}

@implementation UIImage (SSCompress)

- (NSData *)compressWithinBytes:(NSUInteger)maxBytes
{
    NSData *originalData = UIImageJPEGRepresentation(self, 1.0);
    return SSCompressImageData(originalData, maxBytes);
}

@end
