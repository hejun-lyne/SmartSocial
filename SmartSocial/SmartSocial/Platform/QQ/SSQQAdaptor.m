//
//  SSQQAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSQQAdaptor.h"

#import <TencentOpenAPI/QQApiInterface.h>
#import <TencentOpenAPI/TencentOAuth.h>
#import <TencentOpenAPI/sdkdef.h>

@interface SSQQAdaptor()<TencentLoginDelegate, TencentSessionDelegate, QQApiInterfaceDelegate>
@end

#define QQ_MAX_IMG_SIZE 5 * 1024 * 1024 // 5m
#define QQ_MAX_IMG_PREVIEW_SIZE 1 * 1024 * 1024

@implementation SSQQAdaptor
{
    TencentOAuth *auth;
}

- (instancetype)init
{
    SSPlatformConfiguration *config = SSContext.shared.platformConfiguration;
    auth = [[TencentOAuth alloc] initWithAppId:config.qqAppId andDelegate:self];
    if (auth == nil) {
        return nil;
    }
    self = [super init];
    return self;
}

#define AuthDomain @"QQAuth"
#define ShareDomain @"QQShare"

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (self.sharing) {
        self.sharing = NO;
        self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeCancelled));
    }
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation
{
    return [QQApiInterface handleOpenURL:url delegate:self] || ([TencentOAuth CanHandleOpenURL:url] ? [TencentOAuth HandleOpenURL:url] : NO);
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [QQApiInterface handleOpenURL:url delegate:self] || ([TencentOAuth CanHandleOpenURL:url] ? [TencentOAuth HandleOpenURL:url] : NO);
}


- (void)shareInfo:(id<ISSShareInfo>)info
{
    info.channel == SSShareChannelQQFriend ? [self shareToFriend:info] : [self shareToQZone:info];
}

- (void)shareToFriend:(id<ISSShareInfo>)info
{
    void (^share) (QQApiObject *) = ^(QQApiObject *obj) {
        SendMessageToQQReq *req = [SendMessageToQQReq reqWithContent:obj];
        QQApiSendResultCode code = [QQApiInterface sendReq:req];
        if (code != EQQAPISENDSUCESS) {
            SSAuthErrorCode ec = SSAuthErrorCodeUnknown;
            if (code == EQQAPITIMNOTINSTALLED || code == EQQAPIQQNOTINSTALLED) {
                ec = SSAuthErrorCodeNotInstalled;
            }
            self.shareCompletion(NO, MakeErrorS(ShareDomain, ec));
        } else {
            self.sharing = YES;
        }
    };
    
    // Url
    if (info.url.length > 0) {
        NSURL *previewImageUrl = nil;
        for (id obj in info.shareImages) {
            if (![obj isKindOfClass:NSString.class]) {
                continue;
            }
            previewImageUrl = [NSURL URLWithString:(NSString *)obj];
            break;
        }
        QQApiNewsObject *url = [QQApiNewsObject
                                objectWithURL:[NSURL URLWithString:info.url]
                                title:info.title
                                description:info.content
                                previewImageURL:previewImageUrl];
        share(url);
    }
    // Image
    else if (info.shareImages.count > 0) {
        id first = info.shareImages.firstObject;
        void (^processImage)(UIImage *) = ^(UIImage *imgToShare) {
            NSData *compressedImg = [imgToShare compressWithinBytes:QQ_MAX_IMG_SIZE];
            NSData *compressedPre = [imgToShare compressWithinBytes:QQ_MAX_IMG_PREVIEW_SIZE];
            QQApiImageObject *img = [QQApiImageObject objectWithData:compressedImg previewImageData:compressedPre title:info.title description:info.content];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                share(img);
            });
        };
        
        if ([first isKindOfClass:[UIImage class]]) {
            processImage(first);
        }else { // string
            [SSImageDownloader downloadImageWithURL:first completion:^(UIImage *image, NSError *error) {
                if (error) {
                    self.shareCompletion(NO, error);
                } else if (image == nil) {
                    self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Download image failed"}));
                }
                processImage(image);
            }];
        }
    }
    // Text
    else {
        QQApiTextObject *txt = [QQApiTextObject objectWithText:info.title];
        txt.description = info.content;
        share(txt);
    }
}

- (void)shareToQZone:(id<ISSShareInfo>)info
{
    void (^share) (QQApiObject *) = ^(QQApiObject *obj) {
        SendMessageToQQReq *req = [SendMessageToQQReq reqWithContent:obj];
        QQApiSendResultCode code = [QQApiInterface SendReqToQZone:req];
        if (code != EQQAPISENDSUCESS) {
            SSAuthErrorCode ec = SSAuthErrorCodeUnknown;
            if (code == EQQAPITIMNOTINSTALLED || code == EQQAPIQQNOTINSTALLED) {
                ec = SSAuthErrorCodeNotInstalled;
            }
            self.shareCompletion(NO, MakeErrorS(ShareDomain, ec));
        } else {
            self.sharing = YES;
        }
    };
    
    // Url
    if (info.url.length > 0) {
        NSURL *previewImageUrl = nil;
        for (id obj in info.shareImages) {
            if (![obj isKindOfClass:NSString.class]) {
                continue;
            }
            previewImageUrl = [NSURL URLWithString:(NSString *)obj];
            break;
        }
        QQApiNewsObject *url = [QQApiNewsObject
                                objectWithURL:[NSURL URLWithString:info.url]
                                title:info.title
                                description:info.content
                                previewImageURL:previewImageUrl];
        share(url);
    }
    // Images
    else {
        NSArray *imgs = info.shareImages;
        if (info.shareImages.count == 0) {
            self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Images is empty!"}));
        } else {
            [SSImageDownloader downloadImagesWithArray:imgs completion:^(NSArray<UIImage *> *images, NSError *error) {
                NSMutableArray *compressedImages = [NSMutableArray arrayWithCapacity:images.count];
                for (UIImage *img in images) {
                    NSData *d = [img compressWithinBytes:QQ_MAX_IMG_PREVIEW_SIZE];
                    if (d != nil) {
                        [compressedImages addObject:d];
                    }
                }
                NSString *title = [NSString stringWithFormat:@"%@ %@",info.title ? : @"", info.content ? : @""];
                QQApiImageArrayForQZoneObject *obj = [QQApiImageArrayForQZoneObject
                                                      objectWithimageDataArray:compressedImages
                                                      title:title
                                                      extMap:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    share(obj);
                });
            }];
        }
    }
}

- (void)requestUserInfo
{
    if (!self.credential.isTokenValid) {
        __weak __typeof(self)weakSelf = self;
        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
            if (e) {
                weakSelf.requestUserInfoCompletion(nil, e);
            } else {
                [weakSelf requestUserInfo];
            }
        };
        [self requestAuthWithParameters:nil];
        return;
    }
    
    if (![auth getUserInfo]) {
        self.requestUserInfoCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeUnknown));
    }
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    if ([auth isCachedTokenValid]) {
        [self updateAuthFromCache];
        self.authCompletion(self.credential, nil);
    }else {
        BOOL success = [auth authorize:
                        @[kOPEN_PERMISSION_GET_USER_INFO,
                          kOPEN_PERMISSION_GET_SIMPLE_USER_INFO,
                          kOPEN_PERMISSION_ADD_ALBUM,
                          //kOPEN_PERMISSION_ADD_ONE_BLOG,
                          //kOPEN_PERMISSION_ADD_SHARE,
                          kOPEN_PERMISSION_ADD_TOPIC,
                          kOPEN_PERMISSION_CHECK_PAGE_FANS,
                          kOPEN_PERMISSION_GET_INFO,
                          kOPEN_PERMISSION_GET_OTHER_INFO,
                          kOPEN_PERMISSION_LIST_ALBUM,
                          kOPEN_PERMISSION_UPLOAD_PIC,
                          kOPEN_PERMISSION_GET_VIP_INFO,
                          kOPEN_PERMISSION_GET_VIP_RICH_INFO]];
        if (!success) {
            self.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeUnknown));
        }
    }
}

- (void)updateAuthFromCache
{
    auth.accessToken = [auth getCachedToken];
    auth.expirationDate = [auth getCachedExpirationDate];
    auth.openId = [auth getCachedOpenID];
    [self updateCredential];
}

- (void)updateCredential
{
    SSAuthCredential *credential = [SSAuthCredential new];
    credential.accessToken = [auth accessToken];
    credential.platform = SSPlatformQQ;
    credential.estimatedExpireDate = [auth expirationDate];
    credential.qqOpenId = auth.openId;
    self.credential = credential;
}

- (BOOL)appInstalled
{
    return [QQApiInterface isQQInstalled];
}

#pragma mark - Tencent Delegates

- (void)tencentDidLogin
{
    [self updateCredential];
    self.authCompletion(self.credential, nil);
    self.authing = NO;
}

- (void)tencentDidNotLogin:(BOOL)cancelled
{
    self.authCompletion(nil, MakeErrorS(AuthDomain, cancelled ? SSAuthErrorCodeCancelled : SSAuthErrorCodeUnknown));
    self.authing = NO;
}

- (void)tencentDidNotNetWork
{
    NSLog(@"tencent sdk says no network");
}

- (void)tencentDidLogout
{
    NSLog(@"tencent sdk logout");
}

- (void)tencentDidUpdate:(TencentOAuth *)tencentOAuth
{
    NSLog(@"tencentOAuth updated");
}

- (void)tencentOAuth:(TencentOAuth *)tencentOAuth doCloseViewController:(UIViewController *)viewController
{
    if (viewController.presentingViewController) {
        [viewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }else {
        if (viewController.navigationController && viewController.navigationController.topViewController == viewController) {
            [viewController.navigationController popViewControllerAnimated:YES];
        }
    }
}

- (void)getUserInfoResponse:(APIResponse *)response
{
    NSDictionary *message = response.jsonResponse;
    SSUserInfo *info = [SSUserInfo new];
    info.nickname = message[@"nickname"];
    NSString *gender = message[@"gender"];
    info.gender = SSUserGenderUnknown;
    if (gender.length > 0) {
        info.gender = [gender isEqualToString:@"男"] ? SSUserGenderMale : SSUserGenderFemale;
    }
    info.avatarUrl = message[@"figureurl_qq_2"] ? : message[@"figureurl_qq_1"];
    info.uid = auth.openId;
    
    self.requestUserInfoCompletion(info, nil);
}


- (void)onResp:(QQBaseResp *)resp
{
    switch (resp.type) {
        case ESENDMESSAGETOQQRESPTYPE: {
            SendMessageToQQResp *sendResp = (SendMessageToQQResp *)resp;
            if ([sendResp.result isEqualToString:@"0"]) {
                self.shareCompletion(YES, nil);
            }else {
                self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": sendResp.errorDescription}));
            }
            self.sharing = NO;
            break;
        }
        default: {
            break;
        }
    }
}

- (void)isOnlineResponse:(NSDictionary *)response {}
- (void)onReq:(QQBaseReq *)req {}
- (void)didGetUnionID {}

@end
