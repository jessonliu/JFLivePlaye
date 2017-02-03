//
//  JFAudioFrame.h
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/10.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JFFrame.h"

@interface JFAudioFrame : JFFrame

// flv打包中aac的header
@property (nonatomic, strong) NSData *audioInfo;

@end
