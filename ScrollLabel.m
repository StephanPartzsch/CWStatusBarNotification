#import "ScrollLabel.h"


static float PADDING = 10.0f;
static float SCROLL_SPEED = 40.0f;
static float SCROLL_DELAY = 1.0f;


@implementation ScrollLabel
{
	UIImageView *textImage;
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		textImage = [[UIImageView alloc] init];
		[self addSubview:textImage];
	}
	return self;
}

- (CGFloat)fullWidth
{
	return [self.text sizeWithAttributes:@{NSFontAttributeName: self.font}].width;
}

- (CGFloat)scrollOffset
{
	if (self.numberOfLines != 1) return 0;

	CGRect insetRect = CGRectInset(self.bounds, PADDING, 0);
	return MAX(0, [self fullWidth] - insetRect.size.width);
}

- (CGFloat)scrollTime
{
	return ([self scrollOffset] > 0) ? [self scrollOffset] / SCROLL_SPEED + SCROLL_DELAY : 0;
}

- (void)drawTextInRect:(CGRect)rect
{
	if ([self scrollOffset] > 0) {
		rect.size.width = [self fullWidth] + PADDING * 2;
		UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
		[super drawTextInRect:rect];
		textImage.image = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		[textImage sizeToFit];
		[UIView animateWithDuration:[self scrollTime] - SCROLL_DELAY
							  delay:SCROLL_DELAY
							options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
						 animations:^{
							 textImage.transform = CGAffineTransformMakeTranslation(-[self scrollOffset], 0);
						 } completion:^(BOOL finished) {
				}];
	} else {
		textImage.image = nil;
		[super drawTextInRect:CGRectInset(rect, PADDING, 0)];
	}
}

@end