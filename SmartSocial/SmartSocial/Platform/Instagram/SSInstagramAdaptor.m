//
//  SSInstagramAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSInstagramAdaptor.h"

#import <WebKit/WKNavigationDelegate.h>
#import <WebKit/WKNavigationAction.h>

@interface SSInstagramAdaptor()<WKNavigationDelegate, UIDocumentInteractionControllerDelegate>
@end
@implementation SSInstagramAdaptor
{
    UIViewController *authController;
    UIDocumentInteractionController *documentController;
}

#define AuthDomain @"InstagramAuth"
#define ShareDomain @"InstagramShare"

- (void)shareInfo:(id<ISSShareInfo>)info
{
    if (!self.appInstalled) {
        self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeNotInstalled));
        return;
    }
    if (info.shareImages.count <= 0) {
        self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Instagram share must contain image."}));
        return;
    }
    
    // Only one picture
    id imageObject = info.shareImages.firstObject;
    if ([imageObject isKindOfClass:[NSString class]]) {
        [SSImageDownloader downloadImageWithURL:imageObject completion:^(UIImage *image, NSError *error) {
            [self shareImage:image];
        }];
    } else {
        [self shareImage:imageObject];
    }
}

- (void)shareImage:(UIImage *)image
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ss_insshare.img"];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        BOOL writeSuccess = [UIImageJPEGRepresentation(image, 1.0) writeToFile:filePath atomically:YES];
        if (!writeSuccess) {
            self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": @"Image write to file failed!"}));
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->documentController != nil) {
                [self->documentController dismissMenuAnimated:YES];
            }
            
            UIDocumentInteractionController *docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];
            docController.delegate = self;
            docController.UTI = @"com.instagram.exclusivegram";
            [docController presentOpenInMenuFromRect:CGRectZero inView:self.topViewController.view animated:YES];
            
            self->documentController = docController;
        });
    });
}

- (void)requestUserInfo
{
    if (self.credential == nil) {
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
    
    NSString *reqUrl = [NSString stringWithFormat:@"https://api.instagram.com/v1/users/self/?access_token=%@", self.credential.accessToken];
    [[[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:reqUrl]] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != nil) {
            self.requestUserInfoCompletion(nil, error);
            return;
        }
        NSError *serializationError;
        NSDictionary *resDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&serializationError];
        if (serializationError != nil) {
            self.requestUserInfoCompletion(nil, serializationError);
            return;
        }
        
        NSDictionary *dataDict = resDict[@"data"];
        SSUserInfo *info = [SSUserInfo new];
        info.nickname = dataDict[@"username"];
        info.gender = SSUserGenderUnknown;
        info.uid = [NSString stringWithFormat:@"%li", [dataDict[@"id"] integerValue]];
        info.signature = dataDict[@"bio"];
        info.avatarUrl = dataDict[@"profile_picture"];
        
        self.requestUserInfoCompletion(info, nil);
    }] resume];
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    if ([self.credential isTokenValid]) {
        self.authCompletion(self.credential, nil);
        return;
    }
    
    SSWebViewController *webVc = [SSWebViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:webVc];
    
    NSString *encodedRedirectUrl = [self.configuration.instagramRedirectUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    NSString *authUrl = [NSString stringWithFormat:@"https://api.instagram.com/oauth/authorize/?client_id=%@&redirect_uri=%@&response_type=token",self.configuration.instagramClientId, encodedRedirectUrl];
    
    webVc.webview.navigationDelegate = self;
    [webVc.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:authUrl]]];
    webVc.title = @"Instagram";
    __weak UIViewController *weaknav = nav;
    __weak __typeof(self)weakSelf = self;
    webVc.onCancelled = ^{
        [weaknav.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeCancelled));
        strongSelf->authController = nil;
    };
    
    authController = nav;
    [self.topViewController presentViewController:nav animated:YES completion:nil];
}

- (void)onAccessCode:(NSString *)codeResultString
{
    NSDictionary *resDict = URLQueryParameters(codeResultString);
    NSString *accessToken = resDict[@"access_token"];
    
    if (authController != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->authController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
            self->authController = nil;
        });
    }
    
    if (accessToken == nil) {
        self.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeCancelled));
        return;
    }
    
    SSAuthCredential *credential = [SSAuthCredential new];
    credential.accessToken = accessToken;
    credential.platform = SSPlatformInstagram;
    //no expr date....
    
    self.credential = credential;
    self.authCompletion(credential, nil);
}

- (BOOL)appInstalled
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"instagram://"]];
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
    if (controller != documentController) {
        return ;
    }
    documentController = nil;
    self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeCancelled));
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application
{
    if (controller != documentController) {
        return ;
    }
    if ([application containsString:@"instagram"]) {
        self.shareCompletion(YES, nil);
    } else {
        NSString *reason = [NSString stringWithFormat:@"Share to not app: %@", application];
        self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeCancelled, @{@"reason": reason}));
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if ([navigationAction.request.URL.absoluteString hasPrefix:self.configuration.instagramRedirectUrl]) {
        NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:navigationAction.request.URL resolvingAgainstBaseURL:YES];
        [self onAccessCode:urlComponents.fragment?:urlComponents.query];

        decisionHandler(WKNavigationActionPolicyCancel);
        return ;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

@end
