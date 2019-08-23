//
//  SSVKAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSVKAdaptor.h"

#import <VK-ios-sdk/VKSdk.h>

@interface SSVKAdaptor()<VKSdkDelegate, VKSdkUIDelegate>
@end
@implementation SSVKAdaptor
{
    VKSdk *sdk;
    NSArray *permissions;
}

- (instancetype)init
{
    SSPlatformConfiguration *config = SSContext.shared.platformConfiguration;
    VKSdk *sdk = [VKSdk initializeWithAppId:config.vkId];
    if (sdk == nil) {
        return nil;
    }
    if (self = [super init]) {
        permissions = @[VK_PER_WALL, VK_PER_PHOTOS];
        [sdk registerDelegate:self];
        [sdk setUiDelegate:self];
        self->sdk = sdk;
    }
    return self;
}

#define AuthDomain @"VKAuth"
#define ShareDomain @"VKShare"

- (void)shareInfo:(id<ISSShareInfo>)info
{
    if (![self.credential isTokenValid]) {
        __weak __typeof(self)weakSelf = self;
        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
            if (c != nil) {
                [weakSelf shareInfo:info];
            } else if (e != nil) {
                weakSelf.requestUserInfoCompletion(nil, e);
            } else {
                weakSelf.requestUserInfoCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeUnknown));
            }
        };
        [self requestAuthWithParameters:nil];
        return;
    }
    
    void (^share)(NSArray <UIImage *> *) = ^(NSArray <UIImage *> *images) {
        VKShareLink *sharelink = info.url.length > 0 ? [[VKShareLink alloc] initWithTitle:nil link:[NSURL URLWithString:info.url]] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            VKShareDialogController *dialog = [VKShareDialogController new];
            dialog.text = info.content;
            dialog.shareLink = sharelink;
            dialog.requestedScope = self->permissions;
            if (images.count > 0) {
                VKImageParameters *sharedParam = [VKImageParameters jpegImageWithQuality:1.0];
                NSMutableArray *uploads = [NSMutableArray arrayWithCapacity:images.count];
                for (UIImage *img in images) {
                    VKUploadImage *up = [VKUploadImage uploadImageWithImage:img andParams:sharedParam];
                    if (up != nil) {
                        [uploads addObject:up];
                    }
                }
                dialog.uploadImages = uploads;
            }
            dialog.dismissAutomatically = YES;
            dialog.completionHandler = ^(VKShareDialogController *dialog, VKShareDialogControllerResult result) {
                if (result == VKShareDialogControllerResultCancelled) {
                    self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeCancelled));
                } else {
                    self.shareCompletion(YES, nil);
                }
            };
            [self.topViewController presentViewController:dialog animated:YES completion:nil];
        });
    };
    
    if (info.shareImages.count > 0) {
        [SSImageDownloader downloadImagesWithArray:info.shareImages completion:^(NSArray<UIImage *> *images, NSError *error) {
            share(images);
        }];
    } else {
        share(nil);
    }
}

- (void)requestUserInfo
{
    if (![self.credential isTokenValid]) {
        __weak __typeof(self)weakSelf = self;
        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
            if (c != nil) {
                [weakSelf requestUserInfo];
            } else if (e != nil) {
                weakSelf.requestUserInfoCompletion(nil, e);
            } else {
                weakSelf.requestUserInfoCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeUnknown));
            }
        };
        [self requestAuthWithParameters:nil];
        return;
    }
    
    [[[VKApi users] get:@{
                          @"user_ids": @[self.credential.vkUserId],
                          @"fields": @[@"id",@"first_name",@"nickname",@"screen_name",@"sex",@"photo_max_orig",@"status"]
                          }]
     executeWithResultBlock:^(VKResponse *response) {
         if ([response.json isKindOfClass:[NSArray class]]) {
             NSDictionary *infoDict = [((NSArray *)response.json) firstObject];
             if ([infoDict isKindOfClass:[NSDictionary class]]) {
                 SSUserInfo *info = [SSUserInfo new];
                 info.uid = [NSString stringWithFormat:@"%li", [infoDict[@"id"] integerValue]];
                 NSString *nickname = infoDict[@"nickname"];
                 if (nickname.length <= 0) {
                     NSMutableString *realname = @"".mutableCopy;
                     [realname appendString:infoDict[@"first_name"]?:@""];
                     [realname appendString:@" "];
                     [realname appendString:infoDict[@"last_name"]?:@""];
                     if (realname.length > 1) {
                         nickname = realname.copy;
                     }else {
                         nickname = infoDict[@"screen_name"];
                     }
                 }
                 info.nickname = nickname;
                 info.gender = SSUserGenderUnknown;
                 if (infoDict[@"sex"]) {
                     NSInteger sexValue = [infoDict[@"sex"] integerValue];
                     info.gender = sexValue == 2 ? SSUserGenderMale : SSUserGenderFemale;
                 }
                 info.signature = infoDict[@"status"];
                 info.avatarUrl = infoDict[@"photo_max_orig"];
                 
                 self.requestUserInfoCompletion(info, nil);
                 return;
             }
         }
         NSString *reason = [NSString stringWithFormat:@"Error getting user info: %@", response.responseString];
         self.requestUserInfoCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
    } errorBlock:^(NSError *error) {
        self.requestUserInfoCompletion(nil, error);
    }];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    [VKSdk wakeUpSession:permissions completeBlock:^(VKAuthorizationState state, NSError *error) {
        if (error != nil) {
            self.authCompletion(nil, error);
            return;
        }
        switch (state) {
            case VKAuthorizationAuthorized: {
                [self onAuthFinish];
                break;
            }
                
            case VKAuthorizationInitialized: {
                [VKSdk authorize:self->permissions withOptions:VKAuthorizationOptionsUnlimitedToken |VKAuthorizationOptionsDisableSafariController];
                break;
            }
            default: {
                NSString *reason = [NSString stringWithFormat:@"VKSDK state: %ld", state];
                self.authCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            }
        }
    }];
}

- (void)onAuthFinish
{
    SSAuthCredential *credential = [SSAuthCredential new];
    credential.accessToken = [VKSdk accessToken].accessToken;
    credential.vkUserId = [VKSdk accessToken].userId;
    credential.platform = SSPlatformVK;
    self.credential = credential;
    self.authCompletion(credential, nil);
}

- (BOOL)appInstalled
{
    return [VKSdk vkAppMayExists];
}

#pragma mark - VKSdk Delegates

- (void)vkSdkAccessAuthorizationFinishedWithResult:(VKAuthorizationResult *)result
{
    if (result.token != nil) {
        [self onAuthFinish];
        return;
    } else {
        self.authCompletion(nil, result.error);
    }
}

- (void)vkSdkUserAuthorizationFailed
{
    self.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeUnknown));
}

- (void)vkSdkAccessTokenUpdated:(VKAccessToken *)newToken oldToken:(VKAccessToken *)oldToken
{
    self.credential.accessToken = newToken.accessToken;
}

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError
{
    NSLog(@"%@", [captchaError json]);
}

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller
{
    [self.topViewController presentViewController:controller animated:YES completion:nil];
}

@end
