//
//  CWStatusBarNotification.m
//  CWNotificationDemo
//
//  Created by Cezary Wojcik on 11/15/13.
//  Copyright (c) 2013 Cezary Wojcik. All rights reserved.
//

#import "CWStatusBarNotification.h"
#import "ScrollLabel.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

#define STATUS_BAR_ANIMATION_LENGTH 0.25f
#define FONT_SIZE 12.0f


@implementation CWWindowContainer

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (point.y > 0 && point.y < [UIApplication sharedApplication].statusBarFrame.size.height) {
        return [super hitTest:point withEvent:event];
    }
    
    return nil;
}

@end

# pragma mark - dispatch after with cancellation
// adapted from: https://github.com/Spaceman-Labs/Dispatch-Cancel

typedef void(^CWDelayedBlockHandle)(BOOL cancel);

static CWDelayedBlockHandle perform_block_after_delay(CGFloat seconds, dispatch_block_t block)
{
	if (block == nil) {
		return nil;
	}

	__block dispatch_block_t blockToExecute = [block copy];
	__block CWDelayedBlockHandle delayHandleCopy = nil;

	CWDelayedBlockHandle delayHandle = ^(BOOL cancel){
		if (NO == cancel && nil != blockToExecute) {
			dispatch_async(dispatch_get_main_queue(), blockToExecute);
		}
        
		blockToExecute = nil;
		delayHandleCopy = nil;
	};

	delayHandleCopy = [delayHandle copy];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		if (nil != delayHandleCopy) {
			delayHandleCopy(NO);
		}
	});

	return delayHandleCopy;
};

static void cancel_delayed_block(CWDelayedBlockHandle delayedHandle)
{
	if (delayedHandle == nil) {
		return;
	}

	delayedHandle(YES);
}

# pragma mark - CWStatusBarNotification

@interface CWStatusBarNotification()

@property (strong, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (strong, nonatomic) CWDelayedBlockHandle dismissHandle;

@end

@implementation CWStatusBarNotification

@synthesize contentContainer, customContentView, notificationLabel, notificationLabelBackgroundColor, notificationLabelTextColor, notificationWindow;

@synthesize statusBarView;

@synthesize notificationStyle, notificationIsShowing;

- (CWStatusBarNotification *)init
{
    self = [super init];
    if (self) {
        // set defaults
        self.notificationLabelBackgroundColor = [[UIApplication sharedApplication] delegate].window.tintColor;
        self.notificationLabelTextColor = [UIColor whiteColor];
        self.notificationStyle = CWNotificationStyleStatusBarNotification;
        self.notificationAnimationInStyle = CWNotificationAnimationStyleBottom;
        self.notificationAnimationOutStyle = CWNotificationAnimationStyleBottom;
        self.notificationAnimationType = CWNotificationAnimationTypeReplace;
        self.notificationIsDismissing = NO;

        // create tap recognizer
        self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(notificationTapped:)];
        self.tapGestureRecognizer.numberOfTapsRequired = 1;

        // create default tap block
        __weak typeof(self) weakSelf = self;
        self.notificationTappedBlock = ^(void) {
            if (!weakSelf.notificationIsDismissing) {
                [weakSelf dismissNotificationWithFinishBlock:nil];
            }
        };
    }
    return self;
}

# pragma mark - dimensions

- (CGRect)getNotificationFrame
{
    return CGRectMake(0, [self getStatusBarOffset], [self getStatusBarWidth], [self getNotificationHeight]);
}

- (CGRect)getNotificationTopFrame
{
    return CGRectMake(0, [self getStatusBarOffset] + -1*[self getNotificationHeight], [self getStatusBarWidth], [self getNotificationHeight]);
}

- (CGRect)getNotificationLeftFrame
{
    return CGRectMake(-1*[self getStatusBarWidth], [self getStatusBarOffset], [self getStatusBarWidth], [self getNotificationHeight]);
}

- (CGRect)getNotificationRightFrame
{
    return CGRectMake([self getStatusBarWidth], [self getStatusBarOffset], [self getStatusBarWidth], [self getNotificationHeight]);
}

- (CGRect)getNotificationBottomFrame
{
    return CGRectMake(0, [self getStatusBarOffset] + [self getNotificationHeight], [self getStatusBarWidth], 0);
}

- (CGFloat)getNavigationBarHeight
{
    if (UIDeviceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) ||
        UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return 44.0f;
    }
    return 30.0f;
}

- (CGFloat)getStatusBarHeight
{
	if (self.notificationLabelHeight > 0) {
		return self.notificationLabelHeight;
	}
	CGFloat statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
	if (SYSTEM_VERSION_LESS_THAN(@"8.0") && UIDeviceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
		statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.width;
	}
	return statusBarHeight > 0 ? statusBarHeight : 20;
}

- (CGFloat)getStatusBarWidth
{
	if (SYSTEM_VERSION_LESS_THAN(@"8.0") && UIDeviceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
		return [UIScreen mainScreen].bounds.size.height;
	}
	return [UIScreen mainScreen].bounds.size.width;
}

- (CGFloat)getStatusBarOffset
{
	if ([self getStatusBarHeight] == 40.0f) {
		return -20.0f;
	}
	return 0.0f;
}

- (CGFloat)getNotificationHeight
{
    switch (self.notificationStyle) {
        case CWNotificationStyleStatusBarNotification:
            return [self getStatusBarHeight];
        case CWNotificationStyleNavigationBarNotification:
            return [self getStatusBarHeight] + [self getNavigationBarHeight];
        default:
            return [self getStatusBarHeight];
    }
}

# pragma mark - screen orientation change

- (void)updateStatusBarFrame
{
    self.contentContainer.frame = [self getNotificationFrame];
    self.statusBarView.hidden = YES;
}

# pragma mark - on tap

- (void)notificationTapped:(UITapGestureRecognizer*)recognizer
{
    [self.notificationTappedBlock invoke];
}

# pragma mark - display helpers

- (void)createNotificationWindow
{
	self.notificationWindow = [[CWWindowContainer alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.notificationWindow.backgroundColor = [UIColor clearColor];
	self.notificationWindow.userInteractionEnabled = YES;
	self.notificationWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.notificationWindow.windowLevel = UIWindowLevelStatusBar;
	self.notificationWindow.rootViewController = [UIViewController new];
}

- (void)createContentContainer
{
	self.contentContainer = [UIView new];
	contentContainer.clipsToBounds = YES;
	switch (self.notificationAnimationInStyle) {
		case CWNotificationAnimationStyleTop:
			self.contentContainer.frame = [self getNotificationTopFrame];
			break;
		case CWNotificationAnimationStyleBottom:
			self.contentContainer.frame = [self getNotificationBottomFrame];
			break;
		case CWNotificationAnimationStyleLeft:
			self.contentContainer.frame = [self getNotificationLeftFrame];
			break;
		case CWNotificationAnimationStyleRight:
			self.contentContainer.frame = [self getNotificationRightFrame];
			break;
	}
}

- (void)addContentToContainer
{
	if (notificationLabel)
	{
		// adds ScrollLabel
		[self.contentContainer addSubview:notificationLabel];
	}
	else
	{
		// adds custom content
		[self.contentContainer addSubview:customContentView];
	}
}

- (void)createNotificationLabelWithMessage:(NSString *)message
{
    self.notificationLabel = [ScrollLabel new];
    self.notificationLabel.numberOfLines = self.multiline ? 0 : 1;
    self.notificationLabel.text = message;
    self.notificationLabel.textAlignment = NSTextAlignmentCenter;
    self.notificationLabel.adjustsFontSizeToFitWidth = NO;
    self.notificationLabel.font = [UIFont systemFontOfSize:FONT_SIZE];
    self.notificationLabel.backgroundColor = self.notificationLabelBackgroundColor;
    self.notificationLabel.textColor = self.notificationLabelTextColor;
    self.notificationLabel.clipsToBounds = YES;
	self.notificationLabel.frame = [self getNotificationFrame];
}

- (void)createStatusBarView
{
    self.statusBarView = [[UIView alloc] initWithFrame:[self getNotificationFrame]];
    self.statusBarView.clipsToBounds = YES;
    if (self.notificationAnimationType == CWNotificationAnimationTypeReplace) {
        UIView *statusBarImageView = [[UIScreen mainScreen] snapshotViewAfterScreenUpdates:YES];
        [self.statusBarView addSubview:statusBarImageView];
    }
    [self.notificationWindow.rootViewController.view addSubview:self.statusBarView];
    [self.notificationWindow.rootViewController.view sendSubviewToBack:self.statusBarView];
}

# pragma mark - frame changing

- (void)firstFrameChange
{
    self.contentContainer.frame = [self getNotificationFrame];
    switch (self.notificationAnimationInStyle) {
        case CWNotificationAnimationStyleTop:
            self.statusBarView.frame = [self getNotificationBottomFrame];
            break;
        case CWNotificationAnimationStyleBottom:
            self.statusBarView.frame = [self getNotificationTopFrame];
            break;
        case CWNotificationAnimationStyleLeft:
            self.statusBarView.frame = [self getNotificationRightFrame];
            break;
        case CWNotificationAnimationStyleRight:
            self.statusBarView.frame = [self getNotificationLeftFrame];
            break;
    }
}

- (void)secondFrameChange
{
    switch (self.notificationAnimationOutStyle) {
        case CWNotificationAnimationStyleTop:
            self.statusBarView.frame = [self getNotificationBottomFrame];
            break;
        case CWNotificationAnimationStyleBottom:
            self.statusBarView.frame = [self getNotificationTopFrame];
            self.contentContainer.layer.anchorPoint = CGPointMake(0.5f, 1.0f);
            self.contentContainer.center = CGPointMake(self.contentContainer.center.x, [self getStatusBarOffset] + [self getNotificationHeight]);
            break;
        case CWNotificationAnimationStyleLeft:
            self.statusBarView.frame = [self getNotificationRightFrame];
            break;
        case CWNotificationAnimationStyleRight:
            self.statusBarView.frame = [self getNotificationLeftFrame];
            break;
    }
}

- (void)thirdFrameChange
{
    self.statusBarView.frame = [self getNotificationFrame];
    switch (self.notificationAnimationOutStyle) {
        case CWNotificationAnimationStyleTop:
            self.contentContainer.frame = [self getNotificationTopFrame];
            break;
        case CWNotificationAnimationStyleBottom:
            self.contentContainer.transform = CGAffineTransformMakeScale(1.0f, 0.0f);
            break;
        case CWNotificationAnimationStyleLeft:
            self.contentContainer.frame = [self getNotificationLeftFrame];
            break;
        case CWNotificationAnimationStyleRight:
            self.contentContainer.frame = [self getNotificationRightFrame];
            break;
    }
}

# pragma mark - display notification with message

- (void)displayNotificationWithMessage:(NSString *)message forDuration:(CGFloat)duration
{
	[self displayNotificationWithMessage:message forDuration:duration dismissed:nil];
}

- (void)displayNotificationWithMessage:(NSString *)message forDuration:(CGFloat)duration dismissed:(void (^)(void))dismissed
{
	[self displayNotificationWithMessage:message completion:^{
		self.dismissHandle = perform_block_after_delay(duration, ^{
			[self dismissNotificationWithFinishBlock:dismissed];
		});
	}];
}

- (void)displayNotificationWithMessage:(NSString *)message completion:(void (^)(void))completion
{
	// creates ScrollLabel
	[self createNotificationLabelWithMessage:message];

	// display notification
	[self displayNotificationWithCompletion:completion];
}

# pragma mark - display notification with custom content


- (void)displayNotificationWithCustomContent:(UIView *)customContent forDuration:(CGFloat)duration
{
	[self displayNotificationWithCustomContent:customContent forDuration:duration dismissed:nil];
}

- (void)displayNotificationWithCustomContent:(UIView *)customContent forDuration:(CGFloat)duration dismissed:(void (^)(void))dismissed
{
	[self displayNotificationWithCustomContent:customContent completion:^{
		self.dismissHandle = perform_block_after_delay(duration, ^{
			[self dismissNotificationWithFinishBlock:dismissed];
		});
	}];
}

- (void)displayNotificationWithCustomContent:(UIView *)customContent completion:(void (^)(void))completion
{
	customContentView = customContent;

	// display notification
	[self displayNotificationWithCompletion:completion];
}

# pragma mark - display/dismiss notification

- (void)displayNotificationWithCompletion:(void (^)(void))completion
{
	if (!self.notificationIsShowing) {
		self.notificationIsShowing = YES;

		// create UIWindow
		[self createNotificationWindow];

		// create content container
		[self createContentContainer];

		// add custom content
		[self addContentToContainer];

		// create status bar view
		[self createStatusBarView];

		// add label to window
		[self.notificationWindow.rootViewController.view addSubview:self.contentContainer];
		[self.notificationWindow.rootViewController.view bringSubviewToFront:self.contentContainer];
		[self.notificationWindow setHidden:NO];

		// checking for screen orientation change
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStatusBarFrame) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];

		// checking for status bar change
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateStatusBarFrame) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];

		// animate
		[UIView animateWithDuration:STATUS_BAR_ANIMATION_LENGTH animations:^{
			[self firstFrameChange];
		} completion:^(BOOL finished) {
			double delayInSeconds = (self.notificationLabel) ? [self.notificationLabel scrollTime] : 0;
			perform_block_after_delay(delayInSeconds, ^{
				[completion invoke];
			});
		}];
	}
}

- (void)dismissNotification
{
	[self dismissNotificationWithFinishBlock:nil];
}

- (void)dismissNotificationWithFinishBlock:(void (^)(void))dismissed
{
    if (self.notificationIsShowing) {
        cancel_delayed_block(self.dismissHandle);
        self.notificationIsDismissing = YES;
        [self secondFrameChange];
        [UIView animateWithDuration:STATUS_BAR_ANIMATION_LENGTH animations:^{
            [self thirdFrameChange];
        } completion:^(BOOL finished) {
            [self.contentContainer removeFromSuperview];
            [self.statusBarView removeFromSuperview];
            [self.notificationWindow setHidden:YES];
            self.notificationWindow = nil;
            self.contentContainer = nil;
            self.notificationIsShowing = NO;
            self.notificationIsDismissing = NO;
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
			[dismissed invoke];
        }];
    }
}

@end
