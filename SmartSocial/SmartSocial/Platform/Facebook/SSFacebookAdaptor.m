//
//  SSFacebookAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/22.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSFacebookAdaptor.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginManager.h>
#import <FBSDKLoginKit/FBSDKLoginManagerLoginResult.h>
#import <FBSDKShareKit/FBSDKShareKit.h>

@interface SSFacebookAdaptor()<FBSDKSharingDelegate>
@end
@implementation SSFacebookAdaptor
{
    FBSDKLoginManager *login;
    FBSDKShareDialog *dialog;
}

- (instancetype)init
{
    SSPlatformConfiguration *config = SSContext.shared.platformConfiguration;
    if (config.application == nil) {
        return nil;
    }
    [[FBSDKApplicationDelegate sharedInstance] application:config.application didFinishLaunchingWithOptions:config.launchOptions];
    
    self = [super init];
    return self;
}

#define AuthDomain @"FacebookAuth"
#define ShareDomain @"FacebookShare"

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    if (!self.sharing) {
        return;
    }
    self.sharing = NO;
    if (dialog == nil) {
        return;
    }
    if (dialog.fromViewController.presentedViewController) {
        NSString *vcClass = NSStringFromClass(dialog.fromViewController.presentedViewController.class);
        if ([vcClass hasPrefix:@"FBSDK"]) {
            // 当前 dialog present 了一个 FB 的 webvc，不算失败。
            return ;
        }
    }
    
    self.shareCompletion(NO, MakeError(AuthDomain, SSAuthErrorCodeCancelled, @{@"reason": @"openURL not called, but app become active again, means that user did not come straightly back to the app."}));
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation
{
    return [[FBSDKApplicationDelegate sharedInstance] application:application openURL:url sourceApplication:sourceApp annotation:annotation];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [[FBSDKApplicationDelegate sharedInstance] application:app openURL:url options:options];
}

- (void)shareInfo:(id<ISSShareInfo>)info
{
    self.sharing = NO;
    // Images
    if (info.shareImages.count > 0 && self.appInstalled) {
        [SSImageDownloader downloadImagesWithArray:info.shareImages completion:^(NSArray<UIImage *> *images, NSError *error) {
            FBSDKSharePhotoContent *photoContent = [FBSDKSharePhotoContent new];
            NSMutableArray *fbImages = [NSMutableArray arrayWithCapacity:images.count];
            for (UIImage *img in images) {
                [fbImages addObject:[FBSDKSharePhoto photoWithImage:img userGenerated:YES]];
            }
            photoContent.photos = fbImages;
            if (info.url.length > 0) {
                photoContent.contentURL = [NSURL URLWithString:info.url];
            }
            // show dialog
            dispatch_async(dispatch_get_main_queue(), ^{
                self.sharing = YES;
                FBSDKShareDialog *dialog = [[FBSDKShareDialog alloc] init];
                dialog.fromViewController = self.topViewController;
                dialog.mode = FBSDKShareDialogModeNative;
                dialog.shareContent = photoContent;
                dialog.delegate = self;
                [dialog show];
                self->dialog = dialog;
            });
        }];
    }
    // Url
    else if (info.url.length > 0) {
        FBSDKShareLinkContent *linkContent = [FBSDKShareLinkContent new];
        linkContent.contentURL = [NSURL URLWithString: info.url];
        linkContent.quote = info.content;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sharing = YES;
            FBSDKShareDialog *dialog = [FBSDKShareDialog showFromViewController:self.topViewController withContent:linkContent delegate:self];
            self->dialog = dialog;
        });
    }
    // Other
    else {
        self.shareCompletion(NO, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Invalid share info!"}));
    }
}

- (void)requestUserInfo
{
    NSParameterAssert(self.credential != nil);
    
    NSString *publicProfilePermission = @"public_profile";
    if (![[[FBSDKAccessToken currentAccessToken] permissions] containsObject:publicProfilePermission]) {
        // Request auth firstly
        __weak __typeof(self)weakSelf = self;
        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
            if (c != nil) {
                [weakSelf requestUserInfo];
            } else {
                weakSelf.requestUserInfoCompletion(nil, e);
            }
        };
        [self requestAuthWithParameters:nil];
        return;
    }
    
    [FBSDKProfile loadCurrentProfileWithCompletion:^(FBSDKProfile *profile, NSError *error) {
        if (error) {
            NSString *reason = [NSString stringWithFormat:@"Error: %@", error];
            self.requestUserInfoCompletion(nil, MakeError(AuthDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
            return;
        }
        SSUserInfo *info = [SSUserInfo new];
        info.nickname = profile.name;
        info.avatarUrl =  [[profile imageURLForPictureMode:FBSDKProfilePictureModeNormal size:CGSizeMake(256, 256)] absoluteString];
        
        info.uid = profile.userID;
        info.gender = SSUserGenderUnknown;
        self.requestUserInfoCompletion(info, nil);
    }];
}
- (void)requestAuthWithParameters:(NSDictionary *)params
{
    NSString *publicProfilePermission = @"public_profile";
    SSAuthCredential *credential = (SSAuthCredential *)self.credential;
    if ([credential isTokenValid] && [credential.fbGrantedPermissions containsObject:publicProfilePermission]) {
        self.authCompletion(credential, nil);
        [self refreshAccessToken:credential];
        return;
    }
    
    // facebooksdk default not active facebook app 了https://www.jianshu.com/p/c3b4c7027fa4
    if (login == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            self->login = [FBSDKLoginManager new];
        });
        login.defaultAudience = FBSDKDefaultAudienceEveryone;
    }
    [login logInWithPermissions:@[publicProfilePermission] fromViewController:self.topViewController handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (error || result.isCancelled) {
            NSString *reason = [NSString stringWithFormat:@"Error: %@", error];
            self.authCompletion(nil, MakeError(AuthDomain, result.isCancelled ? SSAuthErrorCodeCancelled : SSAuthErrorCodeUnknown, @{@"reason": reason}));
            return;
        }
        
        SSAuthCredential *credential = [self credentialFromToken:result.token grantedPermissions:[result.grantedPermissions allObjects] declinedPermissions:[result.declinedPermissions allObjects]];
        self.credential = credential;
        self.authCompletion(credential, nil);
    }];
}

- (void)refreshAccessToken:(SSAuthCredential *)credential
{
    FBSDKAccessToken *fbtoken = [[FBSDKAccessToken alloc]
                                 initWithTokenString:credential.accessToken
                                 permissions:credential.fbGrantedPermissions
                                 declinedPermissions:credential.fbDeclinedPermissions
                                 expiredPermissions:@[]
                                 appID:credential.fbAppId
                                 userID:credential.fbUserId
                                 expirationDate:credential.estimatedExpireDate
                                 refreshDate:credential.fbTokenRefreshDate
                                 dataAccessExpirationDate:nil];
    [FBSDKAccessToken setCurrentAccessToken:fbtoken];
    [FBSDKAccessToken refreshCurrentAccessToken:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
        if (error) {
            return;
        }
        FBSDKAccessToken *token = [FBSDKAccessToken currentAccessToken];
        
        SSAuthCredential *updatedCredential = [self credentialFromToken:token grantedPermissions:credential.fbGrantedPermissions declinedPermissions:credential.fbDeclinedPermissions];
        self.credential = updatedCredential;
    }];
}

- (SSAuthCredential *)credentialFromToken:(FBSDKAccessToken *)token grantedPermissions:(NSArray *)grantedPermissions declinedPermissions:(NSArray *)declinedPermissions
{
    SSAuthCredential *credential = [SSAuthCredential new];
    credential.platform = SSPlatformFacebook;
    credential.accessToken = token.tokenString;
    credential.estimatedExpireDate = token.expirationDate;
    credential.fbGrantedPermissions = grantedPermissions;
    credential.fbDeclinedPermissions = declinedPermissions;
    credential.fbAppId = token.appID;
    credential.fbUserId = token.userID;
    credential.fbTokenRefreshDate = token.refreshDate ?: [NSDate date];
    return credential;
}

- (void)removeCredential
{
    [super removeCredential];
    
    [login logOut];
}

- (BOOL)appInstalled
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"fbauth2://"]];
}

#pragma mark - FBSDKSharingDelegate

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results
{
    self.shareCompletion(YES, nil);
    self.sharing = NO;
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error
{
    if ([error.userInfo[FBSDKErrorArgumentNameKey] isEqualToString:@"shareContent"]) {
        NSString *errorDesc = error.userInfo[FBSDKErrorDeveloperMessageKey];
        if ([errorDesc containsString:@"Feed share dialogs support FBSDKShareLinkContent"]) {
            // App not installed
            self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeNotInstalled));
            self.sharing = NO;
            return;
        }
    }
    
    self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Facebook internal error."}));
    self.sharing = NO;
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer
{
    self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeCancelled));
    self.sharing = NO;
}


@end
