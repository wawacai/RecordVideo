//
//  SCCameraVideoViewController.h
//  SoSoRun
//
//  Created by 彭作青 on 2017/4/19.
//  Copyright © 2017年 SouSouRun. All rights reserved.
//

#import "BasedViewController.h"


@interface SCCameraVideoViewController : BasedViewController

@property(nonatomic, copy) void (^sendVideoBlock)(NSString *videofilePath, UIImage *image);

@end
