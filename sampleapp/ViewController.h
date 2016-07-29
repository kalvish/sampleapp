//
//  ViewController.h
//  sampleapp
//
//  Created by ganuka on 7/20/16.
//  Copyright © 2016 vishwan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *roomText;
@property (weak, nonatomic) IBOutlet UIImageView *imageReceived;


- (IBAction)onclickstart:(id)sender;

- (IBAction)onSendMessageToPeer:(id)sender;

@end

