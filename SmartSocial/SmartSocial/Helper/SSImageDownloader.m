//
//  SSImageDownloader.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSImageDownloader.h"

@implementation SSImageDownloader

+ (void)downloadImageWithURL:(NSString *)URLString completion:(nonnull SSSingleImageDownloedBlock)completion
{
    NSParameterAssert(completion);
    
    [[[NSURLSession sharedSession] downloadTaskWithURL:[NSURL URLWithString:URLString] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error || !location) {
            completion(nil, error);
            return ;
        }
        NSData *imageData = [NSData dataWithContentsOfURL:location];
        UIImage *image = [[UIImage alloc] initWithData:imageData];
        completion(image, nil);
    }] resume];
}

+ (void)downloadImagesWithArray:(NSArray<id> *)imageObjectArray completion:(nonnull SSMultipleImageDownloadedBlock)completion
{
    NSParameterAssert(completion);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_group_t downloadGroup = dispatch_group_create();
        NSMutableArray<UIImage *> *downloadedImageObjects = [NSMutableArray new];
        for (id imageObject in imageObjectArray) {
            if ([imageObject isKindOfClass:[NSString class]]) {
                UIImage *placeholder = [UIImage new];
                [downloadedImageObjects addObject:placeholder];
                dispatch_group_enter(downloadGroup);
                [self downloadImageWithURL:imageObject completion:^(UIImage *image, NSError *error) {
                    NSUInteger index = [downloadedImageObjects indexOfObject:placeholder];
                    [downloadedImageObjects replaceObjectAtIndex:index withObject:image];
                    dispatch_group_leave(downloadGroup);
                }];
            }else {
                [downloadedImageObjects addObject:imageObject];
            }
        }
        
        dispatch_group_notify(downloadGroup, dispatch_get_main_queue(), ^{
            __block NSError *downloadError = nil;
            completion(downloadedImageObjects, downloadError);
        });
    });
}

@end
