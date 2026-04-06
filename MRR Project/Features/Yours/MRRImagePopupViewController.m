#import "MRRImagePopupViewController.h"

static CGFloat const MRRImagePopupMinZoomScale = 1.0;
static CGFloat const MRRImagePopupMaxZoomScale = 4.0;
static CGFloat const MRRImagePopupDoubleTapZoomScale = 2.0;

@interface MRRImagePopupViewController () <UIScrollViewDelegate>

@property(nonatomic, retain) UIImage *image;
@property(nonatomic, retain) UIView *dimmingView;
@property(nonatomic, retain) UIScrollView *scrollView;
@property(nonatomic, retain) UIImageView *imageView;
@property(nonatomic, retain) UIButton *closeButton;

- (void)setupDimmingView;
- (void)setupScrollView;
- (void)setupImageView;
- (void)setupCloseButton;
- (void)setupGestureRecognizers;
- (void)handleCloseButtonTapped:(id)sender;
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer;
- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer;
- (void)centerImageView;

@end

@implementation MRRImagePopupViewController

- (instancetype)initWithImage:(UIImage *)image {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _image = [image retain];
  }
  return self;
}

- (void)dealloc {
  [_image release];
  [_closeButton release];
  [_imageView release];
  [_scrollView release];
  [_dimmingView release];
  [super dealloc];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.modalPresentationStyle = UIModalPresentationOverFullScreen;
  self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  self.view.backgroundColor = [UIColor clearColor];

  [self setupDimmingView];
  [self setupScrollView];
  [self setupImageView];
  [self setupCloseButton];
  [self setupGestureRecognizers];

  [self centerImageView];
}

- (void)setupDimmingView {
  UIView *dimmingView = [[[UIView alloc] init] autorelease];
  dimmingView.translatesAutoresizingMaskIntoConstraints = NO;
  dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
  dimmingView.userInteractionEnabled = YES;
  [self.view addSubview:dimmingView];
  self.dimmingView = dimmingView;

  UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [dimmingView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [dimmingView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [dimmingView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [dimmingView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
  ]];
}

- (void)setupScrollView {
  UIScrollView *scrollView = [[[UIScrollView alloc] init] autorelease];
  scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  scrollView.minimumZoomScale = MRRImagePopupMinZoomScale;
  scrollView.maximumZoomScale = MRRImagePopupMaxZoomScale;
  scrollView.showsVerticalScrollIndicator = NO;
  scrollView.showsHorizontalScrollIndicator = NO;
  scrollView.bouncesZoom = YES;
  scrollView.delegate = self;
  [self.view addSubview:scrollView];
  self.scrollView = scrollView;

  UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
    [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [scrollView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor]
  ]];
}

- (void)setupImageView {
  UIImageView *imageView = [[[UIImageView alloc] init] autorelease];
  imageView.translatesAutoresizingMaskIntoConstraints = NO;
  imageView.contentMode = UIViewContentModeScaleAspectFit;
  imageView.image = self.image;
  imageView.userInteractionEnabled = YES;
  [self.scrollView addSubview:imageView];
  self.imageView = imageView;

  [NSLayoutConstraint activateConstraints:@[
    [imageView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
    [imageView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
    [imageView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
    [imageView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
    [imageView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
    [imageView.heightAnchor constraintEqualToAnchor:self.scrollView.heightAnchor]
  ]];
}

- (void)setupCloseButton {
  UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  closeButton.translatesAutoresizingMaskIntoConstraints = NO;
  [closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
  closeButton.tintColor = [UIColor whiteColor];
  closeButton.accessibilityLabel = @"Close image viewer";
  closeButton.accessibilityHint = @"Tap to close the full-screen image viewer";
  [closeButton addTarget:self action:@selector(handleCloseButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
  [self.view addSubview:closeButton];
  self.closeButton = closeButton;

  UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [closeButton.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:16.0],
    [closeButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16.0],
    [closeButton.widthAnchor constraintEqualToConstant:40.0],
    [closeButton.heightAnchor constraintEqualToConstant:40.0]
  ]];
}

- (void)setupGestureRecognizers {
  UITapGestureRecognizer *doubleTapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                        action:@selector(handleDoubleTap:)] autorelease];
  doubleTapRecognizer.numberOfTapsRequired = 2;
  [self.scrollView addGestureRecognizer:doubleTapRecognizer];

  UITapGestureRecognizer *singleTapRecognizer = [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(handleSingleTap:)] autorelease];
  singleTapRecognizer.numberOfTapsRequired = 1;
  [singleTapRecognizer requireGestureRecognizerToFail:doubleTapRecognizer];
  [self.dimmingView addGestureRecognizer:singleTapRecognizer];
}

- (void)handleCloseButtonTapped:(id)sender {
#pragma unused(sender)
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
  if (self.scrollView.zoomScale > self.scrollView.minimumZoomScale) {
    [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
  } else {
    CGPoint location = [recognizer locationInView:self.imageView];
    CGSize zoomSize = CGSizeMake(self.view.bounds.size.width / MRRImagePopupDoubleTapZoomScale,
                                  self.view.bounds.size.height / MRRImagePopupDoubleTapZoomScale);
    CGRect zoomRect = CGRectMake(location.x - zoomSize.width / 2.0, location.y - zoomSize.height / 2.0,
                                  zoomSize.width, zoomSize.height);
    [self.scrollView zoomToRect:zoomRect animated:YES];
  }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
#pragma unused(recognizer)
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)centerImageView {
  CGRect frame = self.imageView.frame;
  CGSize boundsSize = self.scrollView.bounds.size;

  CGFloat horizontalPadding = boundsSize.width > frame.size.width ? (boundsSize.width - frame.size.width) / 2.0 : 0.0;
  CGFloat verticalPadding = boundsSize.height > frame.size.height ? (boundsSize.height - frame.size.height) / 2.0 : 0.0;

  self.scrollView.contentInset = UIEdgeInsetsMake(verticalPadding, horizontalPadding, verticalPadding, horizontalPadding);
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
#pragma unused(scrollView)
  return self.imageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
#pragma unused(scrollView)
  [self centerImageView];
}

@end
