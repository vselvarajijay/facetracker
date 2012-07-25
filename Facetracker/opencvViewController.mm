//
//  opencvViewController.m
//  Facetracker
//
//  Created by Vijay Selvaraj on 7/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "opencvViewController.h"



@interface opencvViewController ()

@end



@implementation opencvViewController

@synthesize captureSession = _captureSession;
@synthesize imageView = _imageView;
@synthesize uiView = _uiView;

int x_pos = 0, y_pos = 0;
UILabel *myLabel;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    
    [self setupCaptureSession];
    
}

- (void) viewDidAppear:(BOOL)animated {
    myLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 100, 50, 30)];
    myLabel.text = @"text";
    myLabel.layer.cornerRadius =8.0;
    [self.view addSubview:myLabel];
}




-(void)setupCaptureSession
{
    NSError *error = nil;
    
    // Create the session
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetMedium;

    //Find the video device
    AVCaptureDevice * capturedevice = [AVCaptureDevice
                                defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSArray *devices = [AVCaptureDevice devices];
    for (AVCaptureDevice *device in devices) {
        
        NSLog(@"Device name: %@", [device localizedName]);
        
        if ([device hasMediaType:AVMediaTypeVideo]) {
            
            if ([device position] == AVCaptureDevicePositionFront) {
                capturedevice = device;
                break;
            }
        }
    }
    
    //Set the media input
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:capturedevice
                                                                        error:&error];
    
    if(!input)
    {
        NSLog(@"PANIC: no media input");
    }
    //Add video input
    [session addInput:input];
    
    //Set the video output
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:output];
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
    
    
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
        
    [session startRunning];
    [self setSession:session];
    [self startPreview:session];

}




-(void)startPreview:(AVCaptureSession *)session
{
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    
    CGRect bounds = _uiView.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.bounds = bounds;
    previewLayer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    
    [_uiView.layer addSublayer:previewLayer];
    
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"captureOutput: didOutputSampleBufferFromConnection");

    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];    
//    IplImage *image = [self createIplImageFromSampleBuffer:sampleBuffer];  
    
    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    
    

  //  [_imageView setImage:image];
    [self.view setNeedsDisplay];
}




-(UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer 
{
    NSLog(@"imageFromSampleBuffer: called");
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);    
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little| kCGImageAlphaPremultipliedFirst);
    
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    [self faceDetector:image];
    
    CGImageRelease(quartzImage);
    
    return (image);    
}


-(void)faceDetector:(UIImage *)img
{
    CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:nil options:[NSDictionary dictionaryWithObject:CIDetectorAccuracyHigh forKey:CIDetectorAccuracy]];



    NSArray* features = [detector featuresInImage:img.CIImage];

    for(CIFaceFeature* faceFeature in features)
    {
        NSLog(@"Face found.. ");
        CGFloat faceWidth = faceFeature.bounds.size.width;
        
        // create a UIView using the bounds of the face
        UIView* faceView = [[UIView alloc] initWithFrame:faceFeature.bounds];
        
        // add a border around the newly created UIView
        faceView.layer.borderWidth = 1;
        faceView.layer.borderColor = [[UIColor redColor] CGColor];
        
        // add the new view to create a box around the face
        [self.view addSubview:faceView];
        
    }
}



- (IplImage *)createIplImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    IplImage *iplimage = 0;
    if(sampleBuffer) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        // get information of the image in the buffer
        uint8_t *bufferBaseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        size_t bufferWidth = CVPixelBufferGetWidth(imageBuffer);
        size_t bufferHeight = CVPixelBufferGetHeight(imageBuffer);
        
        // create IplImage
        if (bufferBaseAddress) {
            iplimage = cvCreateImage(cvSize(bufferWidth, bufferHeight), IPL_DEPTH_8U, 4);
            iplimage->imageData = (char*)bufferBaseAddress;
        }
        
        // release memory
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }
    else {
        NSLog(@"No sampleBuffer!!");
    }
    return iplimage;
}



-(void)setSession:(AVCaptureSession *)session
{
    NSLog(@"setting session...");
    self.captureSession=session;
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

@end
