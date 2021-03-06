#import "MBXBenchViewController.h"

#import <Mapbox/Mapbox.h>

#include "locations.hpp"

#include <chrono>

@interface MGLMapView (MBXBenchmarkAdditions)

#pragma mark - Debugging

/** Triggers another render pass even when it is not necessary. */
- (void)setNeedsGLDisplay;

/** Returns whether the map view is currently loading or processing any assets required to render the map */
- (BOOL)isFullyLoaded;

@end

@interface MBXBenchViewController () <MGLMapViewDelegate>

@property (nonatomic) MGLMapView *mapView;

@end

@implementation MBXBenchViewController

#pragma mark - Setup

+ (void)initialize
{
    if (self == [MBXBenchViewController class])
    {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            @"MBXUserTrackingMode": @(MGLUserTrackingModeNone),
            @"MBXShowsUserLocation": @NO,
            @"MBXDebug": @NO,
        }];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSURL* url = [[NSURL alloc] initWithString:@"mapbox://styles/mapbox/streets-v8"];
    self.mapView = [[MGLMapView alloc] initWithFrame:self.view.bounds styleURL:url];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    self.mapView.zoomEnabled = NO;
    self.mapView.scrollEnabled = NO;
    self.mapView.rotateEnabled = NO;
    self.mapView.userInteractionEnabled = YES;

    [self startBenchmarkIteration];

    [self.view addSubview:self.mapView];

}

size_t idx = 0;
enum class State { None, WaitingForAssets, WarmingUp, Benchmarking } state = State::None;
int frames = 0;
std::chrono::steady_clock::time_point started;
std::vector<std::pair<std::string, double>> result;

static const int warmupDuration = 20; // frames
static const int benchmarkDuration = 200; // frames

- (void)startBenchmarkIteration
{
    if (mbgl::bench::locations.size() > idx) {
        const auto& location = mbgl::bench::locations[idx];
        [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(location.latitude, location.longitude) zoomLevel:location.zoom animated:NO];
        self.mapView.direction = location.bearing;
        state = State::WaitingForAssets;
        NSLog(@"Benchmarking \"%s\"", location.name.c_str());
        NSLog(@"- Loading assets...");
    } else {
        // Do nothing. The benchmark is completed.
        NSLog(@"Benchmark completed.");
        NSLog(@"Result:");
        size_t colWidth = 0;
        for (const auto& row : result) {
            colWidth = std::max(row.first.size(), colWidth);
        }
        for (const auto& row : result) {
            NSLog(@"| %-*s | %4.1f fps |", int(colWidth), row.first.c_str(), row.second);
        }
        exit(0);
    }
}

- (void)mapViewDidFinishRenderingFrame:(MGLMapView *)mapView fullyRendered:(__unused BOOL)fullyRendered
{
    if (state == State::Benchmarking)
    {
        frames++;
        if (frames >= benchmarkDuration)
        {
            state = State::None;

            // Report FPS
            const auto duration = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - started).count() ;
            const auto fps = double(frames * 1e6) / duration;
            result.emplace_back(mbgl::bench::locations[idx].name, fps);
            NSLog(@"- FPS: %.1f", fps);

            // Start benchmarking the next location.
            idx++;
            [self startBenchmarkIteration];
        } else {
            [mapView setNeedsGLDisplay];
        }
        return;
    }

    else if (state == State::WarmingUp)
    {
        frames++;
        if (frames >= warmupDuration)
        {
            frames = 0;
            state = State::Benchmarking;
            started = std::chrono::steady_clock::now();
            NSLog(@"- Benchmarking for %d frames...", benchmarkDuration);
        }
        [mapView setNeedsGLDisplay];
        return;
    }

    else if (state == State::WaitingForAssets)
    {
        if ([mapView isFullyLoaded])
        {
            // Start the benchmarking timer.
            state = State::WarmingUp;
            [self.mapView emptyMemoryCache];
            NSLog(@"- Warming up for %d frames...", warmupDuration);
            [mapView setNeedsGLDisplay];
        }
        return;
    }
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

@end
