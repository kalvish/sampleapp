//
//  ViewController.m
//  sampleapp
//
//  Created by ganuka on 7/20/16.
//  Copyright © 2016 vishwan. All rights reserved.
//

#import "ViewController.h"

#import "SIOSocket.h"

@interface ViewController ()

@property SIOSocket *socketSIO;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [SIOSocket socketWithHost: @"http://54.186.253.62:8080" response: ^(SIOSocket *socket)
     {
         self.socketSIO = socket;
         
         [self.socketSIO on: @"created" callback: ^(SIOParameterArray *args)
          {
              NSLog(@"room created");
          }];
         
         [self.socketSIO on: @"joined" callback: ^(SIOParameterArray *args)
          {
              NSLog(@"room joined");
          }];
         
         [self.socketSIO on: @"ready" callback: ^(SIOParameterArray *args)
          {
              NSLog(@"room ready");
          }];
         
         [self.socketSIO emit: @"create or join" args: @[
                                                         @"testroom1"
                                                         ]];
     }];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
