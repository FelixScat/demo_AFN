//
//  FKViewController.m
//  demo_AFN
//
//  Created by felix on 09/12/2019.
//  Copyright (c) 2019 felix. All rights reserved.
//

#import "FKViewController.h"

#import <AFNetworking/AFNetworking.h>

@interface FKViewController ()

@end

@implementation FKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)sendRequest {
    
//    [[AFHTTPSessionManager manager] GET:@"http://httpbin.org/get" parameters:nil progress:nil success:nil failure:nil];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSURLSessionDataTask *task = [manager GET:@"http://httpbin.org/get" parameters:@{@"arg1":@(100), @"arg2": @{@"foo":@"bar"}} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
    
    AFSecurityPolicy *policy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModePublicKey];
    
    manager.securityPolicy = policy;
//    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
//    NSURLSessionDataTask *task = [manager POST:@"http://httpbin.org/post" parameters:@{@"arg1":@(100), @"arg2": @{@"foo":@"bar"}} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//
//    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//
//    }];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self sendRequest];
}



@end
