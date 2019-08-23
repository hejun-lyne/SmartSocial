
//
//  SSWebViewController.m
//  SmartSocial
//
//  Created by Li Hejun on 2019/8/23.
//  Copyright © 2019 Hejun. All rights reserved.
//

#import "SSWebViewController.h"

@implementation SSWebViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        _webview = [[WKWebView alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    self.webview.frame = self.view.bounds;
    self.webview.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    
    [self.view addSubview:self.webview];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat topInset = self.navigationController.navigationBar.bounds.size.height + [UIApplication sharedApplication].statusBarFrame.size.height;
    self.webview.frame = CGRectMake(0, topInset, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - topInset);
}

- (void)setOnCancelled:(void (^)(void))onCancelled
{
    _onCancelled = onCancelled;
    [self updateLeftBarItem];
}


- (void)updateLeftBarItem
{
    if (self.onCancelled) {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(didClickCancel)];
        self.navigationItem.leftBarButtonItem = item;
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
}

- (void)didClickCancel
{
    if (self.onCancelled) {
        self.onCancelled();
    }
}


@end
