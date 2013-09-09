//
//  UBLRView.m
//  7blur
//
//  Created by JUSTIN M FISCHER on 9/02/13.
//  Copyright (c) 2013 Justin M Fischer. All rights reserved.
//

#import "BLRView.h"
#import "UIImage+ImageEffects.h"
#import "UIImage+Resize.h"
#import "Utilities.h"

#define scaleDownFactor 4

@interface BLRView ()
@end

@implementation BLRView

- (id) initWithCoder:(NSCoder *) aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
    }
    
    return self;
}

+ (BLRView *) load:(UIView *) view {
    BLRView *blur = [[[NSBundle mainBundle] loadNibNamed:@"BLRView" owner:nil options:nil] objectAtIndex:0];
    
    blur.parent = view;
    blur.location = CGPointMake(0, 64);
    
    blur.frame = CGRectMake(blur.location.x, -(blur.frame.size.height + blur.location.y), blur.frame.size.width, blur.frame.size.height);
    
    return blur;
}

+ (BLRView *) loadWithLocation:(CGPoint) point parent:(UIView *) view {
    BLRView *blur = [[[NSBundle mainBundle] loadNibNamed:@"BLRView" owner:nil options:nil] objectAtIndex:0];
    
    blur.parent = view;
    blur.location = point;
    
    blur.frame = CGRectMake(0, 0, blur.frame.size.width, blur.frame.size.height);
    
    return blur;
}

- (void) awakeFromNib {
    self.gripBarView.layer.cornerRadius = 6;
}

- (void) unload {
    if(self.timer != nil) {
        
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    
    [self removeFromSuperview];
}

- (void) blurBackground {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(CGRectGetWidth(self.parent.frame), CGRectGetHeight(self.parent.frame)), NO, 1);
    
    Stopwatch *stopwatch1 = [[Stopwatch alloc] initWithName:@"snapshot"];
    Stopwatch *stopwatch2 = [[Stopwatch alloc] initWithName:@"crop"];
    Stopwatch *stopwatch3 = [[Stopwatch alloc] initWithName:@"re-size"];
    Stopwatch *stopwatch4 = [[Stopwatch alloc] initWithName:@"blur"];
    
    [stopwatch1 start];
    //Snapshot finished in 0.051982 seconds.
    [self.parent drawViewHierarchyInRect:CGRectMake(0, 0, CGRectGetWidth(self.parent.frame), CGRectGetHeight(self.parent.frame)) afterScreenUpdates:NO];
    [stopwatch1 stop];

    __block UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
        [stopwatch2 start];
        //Crop finished in 0.000037 seconds.
        snapshot = [snapshot croppedImage:CGRectMake(self.location.x, self.location.y, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame))];
        [stopwatch2 stop];
        
        [stopwatch3 start];
        //Re-size finished in 0.000717 seconds.
        snapshot = [snapshot resizedImage:CGSizeMake(CGRectGetWidth(self.frame) / scaleDownFactor, CGRectGetHeight(self.frame) / scaleDownFactor) interpolationQuality:kCGInterpolationLow];
        [stopwatch3 stop];
        
        [stopwatch4 start];
        //Blur finished in 0.001360 seconds.
        snapshot = [snapshot applyBlurWithRadius:self.colorComponents.radius tintColor:self.colorComponents.tintColor saturationDeltaFactor:self.colorComponents.saturationDeltaFactor maskImage:self.colorComponents.maskImage];
        [stopwatch4 stop];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.backgroundImageView.image = snapshot;
            
            [stopwatch1 statistics];
            [stopwatch2 statistics];
            [stopwatch3 statistics];
            [stopwatch4 statistics];
        });
    });
}

- (void) blurWithColor:(BLRColorComponents *) components {
    if(self.blurType == KBlurUndefined) {
        
        self.blurType = KStaticBlur;
        self.colorComponents = components;
    }
    
    [self blurBackground];
}

- (void) blurWithColor:(BLRColorComponents *) components updateInterval:(float) interval {
    self.blurType = KLiveBlur;
    self.colorComponents = components;
    
    self.timer = CreateDispatchTimer(interval * NSEC_PER_SEC, 1ull * NSEC_PER_SEC, dispatch_get_main_queue(), ^{[self blurWithColor:components];});
}

dispatch_source_t CreateDispatchTimer(uint64_t interval, uint64_t leeway, dispatch_queue_t queue, dispatch_block_t block) {
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), interval, leeway);
        dispatch_source_set_event_handler(timer, block);
        
        dispatch_resume(timer);
    }
    
    return timer;
}

- (void) slideDown {
    [UIView animateWithDuration:0.25f animations:^{
        
        self.frame = CGRectMake(self.location.x, self.location.y, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame));
        self.alpha = 1;
        
    } completion:^(BOOL finished) {
        if(self.blurType == KStaticBlur) {
            [self blurWithColor:self.colorComponents];
        }
    }];
}

- (void) slideUp {
    if(self.timer != nil) {
        
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    
    [UIView animateWithDuration:0.15f animations:^{
        
        self.frame = CGRectMake(self.location.x, -(self.frame.size.height + self.location.y), self.frame.size.width, self.frame.size.height);
        self.alpha = 0;
        
    } completion:^(BOOL finished) {
        
    }];
}

@end

@interface BLRColorComponents()
@end

@implementation BLRColorComponents

+ (BLRColorComponents *) lightEffect {
    BLRColorComponents *components = [[BLRColorComponents alloc] init];
    
    components.radius = 6;
    components.tintColor = [UIColor colorWithWhite:.8f alpha:.2f];
    components.saturationDeltaFactor = 1.8f;
    components.maskImage = nil;
    
    return components;
}

+ (BLRColorComponents *) darkEffect {
    BLRColorComponents *components = [[BLRColorComponents alloc] init];
    
    components.radius = 6;
    components.tintColor = [UIColor colorWithRed:.1f green:.1 blue:.1f alpha:.8f];
    components.saturationDeltaFactor = 1.8f;
    components.maskImage = nil;
    
    return components;
}

@end
