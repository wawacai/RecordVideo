//
//  SCCameraVideoViewController.h
//  SoSoRun
//
//  Created by 彭作青 on 2017/4/19.
//  Copyright © 2017年 SouSouRun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCCameraVideoViewController : UIViewController

/**
 videofilePath：压缩后的视频在沙盒中的路径
 image：视频第一帧的图像
*/
@property(nonatomic, copy) void (^sendVideoBlock)(NSString *videofilePath, UIImage *image);

@end
