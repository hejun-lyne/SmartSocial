//
//  SSGoogleAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSGoogleAdaptor.h"

#import <GoogleSignIn/GoogleSignIn.h>

@interface SSGoogleAdaptor()<GIDSignInDelegate, GIDSignInUIDelegate>
@end
@implementation SSGoogleAdaptor
{
    GIDSignIn *signIn;
    BOOL silently;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        signIn = [GIDSignIn sharedInstance];
        signIn.clientID = self.configuration.gooClientId;
        signIn.delegate = self;
        signIn.uiDelegate = self;
        signIn.shouldFetchBasicProfile = YES;
    }
    return self;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApp annotation:(id)annotation
{
    return [signIn handleURL:url sourceApplication:sourceApp annotation:annotation];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    return [signIn handleURL:url
           sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                  annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
}

#define AuthDomain @"GoogleAuth"

- (void)shareInfo:(id<ISSShareInfo>)info
{
    SSNotSupportMethod
}

- (void)requestUserInfo
{
    void (^callback)(GIDGoogleUser *) = ^(GIDGoogleUser *user) {
        SSUserInfo *userInfo = [SSUserInfo new];
        userInfo.nickname = user.profile.name;
        userInfo.avatarUrl = [[user.profile imageURLWithDimension:256] absoluteString];
        userInfo.uid = user.userID;
        userInfo.gender = SSUserGenderUnknown;
        self.requestUserInfoCompletion(userInfo, nil);
    };
    
    if (signIn.currentUser != nil) {
        callback(signIn.currentUser);
    }else {
        __weak __typeof(self)weakSelf = self;
        self.authCompletion = ^(id<ISSAuthCredential> _Nullable c, NSError * _Nullable e) {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            if (c != nil) {
                callback(strongSelf->signIn.currentUser);
            } else if (e != nil) {
                strongSelf.requestUserInfoCompletion(nil, e);
            } else {
                strongSelf.requestUserInfoCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeUnknown));
            }
        };
        [self requestAuthWithParameters:nil];
    }
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    if ([signIn hasAuthInKeychain]) {
        silently = YES;
        [signIn signInSilently];
    } else {
        [signIn signIn];
    }
}

- (void)removeCredential
{
    [signIn signOut];
    [super removeCredential];
}

#pragma mark - GIDSignInDelegate

- (void)signIn:(GIDSignIn *)signIn didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error
{
    if (error != nil) {
        if (silently && error.code == kGIDSignInErrorCodeHasNoAuthInKeychain) {
            // keychain 里面有 auth 导致调了 signInSliently，但是如果还是报了没 keychain，转为普通 signIn
            silently = NO;
            [signIn signIn];
        } else {
            self.authCompletion(nil, error);
        }
        return;
    }
    
    SSAuthCredential *credential = [SSAuthCredential new];
    credential.platform = SSPlatformGoogle;
    credential.estimatedExpireDate = user.authentication.accessTokenExpirationDate;
    credential.accessToken = user.authentication.accessToken;
    
    self.credential = credential;
    self.authCompletion(credential, nil);
}

- (void)signIn:(GIDSignIn *)signIn didDisconnectWithUser:(GIDGoogleUser *)user withError:(NSError *)error {}

#pragma mark - GIDSignInUIDelegate

- (void)signInWillDispatch:(GIDSignIn *)signIn error:(NSError *)error {}

- (void)signIn:(GIDSignIn *)signIn presentViewController:(UIViewController *)viewController
{
    [self.topViewController presentViewController:viewController animated:YES completion:nil];
}

- (void)signIn:(GIDSignIn *)signIn dismissViewController:(UIViewController *)viewController
{
    [viewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
