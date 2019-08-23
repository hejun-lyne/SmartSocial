//
//  SSWhatsAppAdaptor.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSWhatsAppAdaptor.h"

static NSString * const kWhatsAppURLSceheme = @"whatsapp://";

@interface SSWhatsAppAdaptor()<UIDocumentInteractionControllerDelegate>

@end
@implementation SSWhatsAppAdaptor
{
    UIDocumentInteractionController *documentController;
}

#define AuthDomain @"WhatsAppAuth"
#define ShareDomain @"WhatsAppShare"
#define UserInfoDomain @"WhatsAppUserInfo"

- (void)shareInfo:(id<ISSShareInfo>)info
{
    if (!self.appInstalled) {
        self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeNotInstalled));
        return;
    }
    
    id imageObject = info.shareImages.firstObject;
    if (imageObject) {
        if ([imageObject isKindOfClass:[NSString class]]) {
            [SSImageDownloader downloadImageWithURL:imageObject completion:^(UIImage *image, NSError *error) {
                [self shareImage:image];
            }];
        } else {
            [self shareImage:imageObject];
        }
        return ;
    }
    
    if (info.content || info.url) {
        NSString *encodedContent = [info.content?:info.url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        
        NSString *shareURL = [NSString stringWithFormat:@"whatsapp://send?text=%@", encodedContent];
        BOOL sent = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:shareURL]];
        NSString *reason = [NSString stringWithFormat:@"Open url failed: %@", shareURL];
        self.shareCompletion(sent, sent ? nil : MakeError(ShareDomain, SSAuthErrorCodeUnknown, @{@"reason": reason}));
    }
}

- (void)shareImage:(UIImage *)image
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ss_whatsappimgshare.img"];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        if (![UIImageJPEGRepresentation(image, 1.0) writeToFile:filePath atomically:YES]) {
            NSDictionary *info = @{@"reason": @"Image write to disk failed!"};
            self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeUnknown, info));
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self->documentController != nil) {
                [self->documentController dismissMenuAnimated:YES];
            }
            
            UIDocumentInteractionController *docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];
            docController.delegate = self;
            docController.UTI = @"public.image";
            [docController presentOpenInMenuFromRect:CGRectZero inView:self.topViewController.view animated:YES];
            self->documentController = docController;
        });
    });
}

- (void)requestUserInfo
{
    self.requestUserInfoCompletion(nil, MakeErrorS(UserInfoDomain, SSAuthErrorCodeNotSupportted));
}

- (void)requestAuthWithParameters:(NSDictionary *)params
{
    self.authCompletion(nil, MakeErrorS(AuthDomain, SSAuthErrorCodeNotSupportted));
}

- (BOOL)appInstalled
{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:kWhatsAppURLSceheme]];
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
    if (controller != documentController) {
        return;
    }
    
    documentController = nil;
    self.shareCompletion(NO, MakeErrorS(ShareDomain, SSAuthErrorCodeCancelled));
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application
{
    if (controller != documentController) {
        return ;
    }
    if ([application containsString:@"whatsapp"]) {
        self.shareCompletion(YES, nil);
    } else {
        NSString *reason = [NSString stringWithFormat:@"Share to not app: %@", application];
        self.shareCompletion(NO, MakeError(ShareDomain, SSAuthErrorCodeCancelled, @{@"reason": reason}));
    }
}

@end
