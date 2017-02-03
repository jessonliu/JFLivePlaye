//
//  JFVideoFrame.h
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/10.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JFFrame.h"
@interface JFVideoFrame : JFFrame

@property (nonatomic, assign) BOOL isKeyFrame;
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;

@end
