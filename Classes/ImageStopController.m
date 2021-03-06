#import "ImageStopController.h"

#import "TourController.h"
#import "Analytics.h"

@interface ImageStopController (UtilityMethods)
- (CGRect)zoomRectForScale:(float)scale withCenter:(CGPoint)center;
@end

@implementation ImageStopController

@synthesize scrollView, imageView, imageStop;

- (id)initWithImageStop:(ImageStop*)stop
{
	if (self = [super initWithNibName:@"ImageStop" bundle:[NSBundle mainBundle]]) {
		[self setImageStop:stop];
	}

	return self;
}

- (void)dealloc
{
    [scrollView release];
    [imageStop release];
	[super dealloc];
}

#pragma mark -
#pragma mark UIViewController

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (toInterfaceOrientation == UIInterfaceOrientationPortrait) {
		[Analytics trackAction:@"rotate-portrait" forStop:[imageStop getStopId]];
	}
	else {
		[Analytics trackAction:@"rotate-landscape" forStop:[imageStop getStopId]];
	}
}

- (void)viewDidLoad
{
	// Reference the image for this stop
	NSBundle *tourBundle = [((TourController*)[self navigationController]) tourBundle];
	NSString *imageSrc = [imageStop getSourcePath];
	NSString *imagePath = [tourBundle pathForResource:[[imageSrc lastPathComponent] stringByDeletingPathExtension]
											   ofType:[[imageSrc lastPathComponent] pathExtension]
										  inDirectory:[imageSrc stringByDeletingLastPathComponent]];
	
    [self setImageView:[[[TapDetectingImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imagePath]] autorelease]];

	[imageView setDelegate:self];

	[imageView setFrame:scrollView.bounds];
	[imageView setContentMode: (UIViewContentModeScaleAspectFit)];
	[imageView setAutoresizingMask: (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight)];
		
	[scrollView setContentSize:[imageView frame].size];
	[scrollView	setContentMode: UIViewContentModeScaleAspectFit];
	[scrollView setClipsToBounds: YES];
		 
	[scrollView setMinimumZoomScale: 1.0f];
	[scrollView setMaximumZoomScale: [imageView image].size.width/[imageView frame].size.width];
	[scrollView addSubview:imageView];
    
    [imageView release];

    [super viewDidLoad];
}

#pragma mark -
#pragma mark UIScrollViewDelegate 

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return imageView;
}

#pragma mark -
#pragma mark TapDetectingImageViewDelegate

- (void)tapDetectingImageView:(TapDetectingImageView *)view gotSingleTapAtPoint:(CGPoint)tapPoint
{
    // Toggle zoom in or out
	[self tapDetectingImageView:view gotDoubleTapAtPoint:tapPoint]; // just call double tap
}

- (void)tapDetectingImageView:(TapDetectingImageView *)view gotDoubleTapAtPoint:(CGPoint)tapPoint
{
	// Toggle zoom in or out
	if ([scrollView zoomScale] == [scrollView minimumZoomScale])
	{
		// Zoom all the way in
		[scrollView zoomToRect:[self zoomRectForScale:[scrollView maximumZoomScale] withCenter:tapPoint] animated:YES];
		
		[Analytics trackAction:@"zoom-in" forStop:[imageStop getStopId]];
	}
	else if ([scrollView zoomScale] == [scrollView maximumZoomScale])
	{
		// Zoom all the way out
		[scrollView zoomToRect:[self zoomRectForScale:[scrollView minimumZoomScale] withCenter:tapPoint] animated:YES];
		
		[Analytics trackAction:@"zoom-out" forStop:[imageStop getStopId]];
	}
	else if (([scrollView zoomScale] - [scrollView minimumZoomScale]) < ([scrollView maximumZoomScale] - [scrollView zoomScale]))
	{
		// Zoom out if closer to min zoom
		[scrollView zoomToRect:[self zoomRectForScale:[scrollView minimumZoomScale] withCenter:tapPoint] animated:YES];
		
		[Analytics trackAction:@"zoom-out" forStop:[imageStop getStopId]];
	}
	else
	{
		// Zoom in if closer to max zoom
		[scrollView zoomToRect:[self zoomRectForScale:[scrollView maximumZoomScale] withCenter:tapPoint] animated:YES];
		
		[Analytics trackAction:@"zoom-out" forStop:[imageStop getStopId]];
	}
}

- (void)tapDetectingImageView:(TapDetectingImageView *)view gotTwoFingerTapAtPoint:(CGPoint)tapPoint {
	// Nothing for now
}

#pragma mark -
#pragma mark Utility methods
	
- (CGRect)zoomRectForScale:(float)scale withCenter:(CGPoint)center {
			
	CGRect zoomRect;
			
	// The zoom rect is in the content view's coordinates. 
	//    At a zoom scale of 1.0, it would be the size of the imageScrollView's bounds.
	//    As the zoom scale decreases, so more content is visible, the size of the rect grows.
	zoomRect.size.height = [scrollView frame].size.height / scale;
	zoomRect.size.width  = [scrollView frame].size.width  / scale;
			
	// Choose an origin so as to get the right center.
	zoomRect.origin.x    = center.x - (zoomRect.size.width  / 2.0);
	zoomRect.origin.y    = center.y - (zoomRect.size.height / 2.0);
			
	return zoomRect;
}

@end
