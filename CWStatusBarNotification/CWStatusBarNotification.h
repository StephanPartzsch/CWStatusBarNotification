//
//  CWStatusBarNotification
//  CWNotificationDemo
//
//  Created by Cezary Wojcik on 11/15/13.
//  Copyright (c) 2013 Cezary Wojcik. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ScrollLabel;

typedef void(^CWCompletionBlock)(void);


@interface CWWindowContainer : UIWindow
@end

@interface CWStatusBarNotification : NSObject

typedef NS_ENUM(NSInteger, CWNotificationStyle) {
    CWNotificationStyleStatusBarNotification,
    CWNotificationStyleNavigationBarNotification
};

typedef NS_ENUM(NSInteger, CWNotificationAnimationStyle) {
    CWNotificationAnimationStyleTop,
    CWNotificationAnimationStyleBottom,
    CWNotificationAnimationStyleLeft,
    CWNotificationAnimationStyleRight
};

typedef NS_ENUM(NSInteger, CWNotificationAnimationType) {
    CWNotificationAnimationTypeReplace,
    CWNotificationAnimationTypeOverlay
};


@property (strong, nonatomic) CWWindowContainer *notificationWindow;
@property (strong, nonatomic) UIView *statusBarView;
@property (strong, nonatomic) UIView *contentContainer;
@property (strong, nonatomic) UIView *customContentView;

@property (copy, nonatomic) CWCompletionBlock notificationTappedBlock;

@property (nonatomic) CWNotificationAnimationStyle notificationStyle;
@property (nonatomic) CWNotificationAnimationStyle notificationAnimationInStyle;
@property (nonatomic) CWNotificationAnimationStyle notificationAnimationOutStyle;
@property (nonatomic) CWNotificationAnimationType notificationAnimationType;
@property (nonatomic) BOOL notificationIsShowing;
@property (nonatomic) BOOL notificationIsDismissing;

@property (nonatomic) CGFloat contenBottomOffset;

@property (strong, nonatomic) ScrollLabel *notificationLabel;
@property (strong, nonatomic) UIColor *notificationLabelBackgroundColor;
@property (strong, nonatomic) UIColor *notificationLabelTextColor;
@property (assign, nonatomic) CGFloat notificationLabelHeight;
@property (assign, nonatomic) BOOL multiline;


- (CGRect)getContentFrame;

- (void)displayNotificationWithMessage:(NSString *)message completion:(void (^)(void))completion;
- (void)displayNotificationWithMessage:(NSString *)message forDuration:(CGFloat)duration;
- (void)displayNotificationWithMessage:(NSString *)message forDuration:(CGFloat)duration dismissed:(void (^)(void))dismissed;

- (void)displayNotificationWithCustomContent:(UIView *)customContent completion:(void (^)(void))completion;
- (void)displayNotificationWithCustomContent:(UIView *)customContent forDuration:(CGFloat)duration;
- (void)displayNotificationWithCustomContent:(UIView *)customContent forDuration:(CGFloat)duration dismissed:(void (^)(void))dismissed;

- (void)dismissNotification;
- (void)dismissNotificationWithFinishBlock:(void (^)(void))dismissed;

@end
