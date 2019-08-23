//
//  SSImageDownloader.h
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^SSSingleImageDownloedBlock)(UIImage * _Nullable image, NSError * _Nullable error);
typedef void(^SSMultipleImageDownloadedBlock)(NSArray<UIImage *> *images, NSError *error);

@interface SSImageDownloader : NSObject

+ (void)downloadImageWithURL:(NSString *)URLString completion:(SSSingleImageDownloedBlock)completion;
+ (void)downloadImagesWithArray:(NSArray <id> *)imageObjectArray completion:(SSMultipleImageDownloadedBlock)completion;

@end

NS_ASSUME_NONNULL_END
