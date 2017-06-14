//
//  SCCameraVideoViewController.h
//  SoSoRun
//
//  Created by 彭作青 on 2017/4/19.
//  Copyright © 2017年 SouSouRun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCCameraVideoViewController : UIViewController

@property(nonatomic, copy) void (^sendVideoBlock)(NSString *videofilePath, UIImage *image);

@end
