//
//  SSWebViewController.h
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import <WebKit/WKWebView.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSWebViewController : UIViewController
@property (nonatomic, strong) WKWebView *webview;
@property (nonatomic, copy) void(^onCancelled)(void);

@end

NS_ASSUME_NONNULL_END
