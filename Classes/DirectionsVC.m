//
// DirectionsVC.m
// kronos
//
// Created by Ljuba Miljkovic on 3/15/10.
// Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "DataHelper.h"
#import "DirectionsVC.h"
#import "TouchXML.h"

@implementation DirectionsVC
@synthesize googleLogo;

@synthesize route, directions, routeMap, locationManager, zoomLevel, yCropPixels, centerCoordinate;

- (void) viewDidLoad {
	[super viewDidLoad];

	// setup core location
	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
	self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;

	// find the directions whose show=true
	NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"show == %@", [NSNumber numberWithBool:YES]];
	self.directions = [[self.route.directions allObjects] filteredArrayUsingPredicate:filterPredicate];

	if ([self.route.vehicle isEqual:@"cablecar"]) {

		NSString *routeTitle;

		if ([self.route.title isEqualToString:@"PowllMason Cable"]) routeTitle = @"Powell Mason Cable Car";
		else if ([self.route.title isEqualToString:@"PowellHyde Cable"]) routeTitle = @"Powell Hyde Cable Car";
		else if ([self.route.title isEqualToString:@"Calif. Cable Car"]) routeTitle = @"California Cable Car";
		else routeTitle = self.route.title;
		self.title = routeTitle;
	} else if ([self.route.vehicle isEqual:@"streetcar"]) self.title = [NSString stringWithFormat:@"%@ Street Car", self.route.tag];
	else if ([self.route.vehicle isEqual:@"metro"]) self.title = [NSString stringWithFormat:@"%@ Metro", self.route.tag];
	else if ([self.route.vehicle isEqual:@"bus"]) self.title = [NSString stringWithFormat:@"%@ Bus", self.route.tag];
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"Directions" style:UIBarButtonItemStylePlain target:nil action:nil];
	self.navigationItem.backBarButtonItem = backButton;

	// load the appropriate map for the route
	NSString *routeMapFileName = [NSString stringWithFormat:@"%@_%@.jpg", self.route.agency.shortTitle, self.route.tag];

	self.routeMap.image = [UIImage imageNamed:routeMapFileName];

	// find directions whose show=true
	NSPredicate *showTruePredicate = [NSPredicate predicateWithFormat:@"show == %@", [NSNumber numberWithBool:YES]];
	NSSortDescriptor *sorter = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];                // sort the directions so that when the order matters, they're always in the same order
	[self.directions sortedArrayUsingDescriptors:[NSArray arrayWithObject:sorter]];

	NSArray *shownDirections = [self.directions filteredArrayUsingPredicate:showTruePredicate];

	// load the file that contains the (x,y) coordinate points for the pins on the route map
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"map_overlay_coordinates" ofType:@"xml"];
	NSData *coordinateData = [NSData dataWithContentsOfFile:filePath];

	CXMLDocument *coordinateParser = [[CXMLDocument alloc] initWithData:coordinateData options:0 error:nil];

	NSString *routeXPath = [NSString stringWithFormat:@"//body/agency[@shortTitle='%@']/route[@tag='%@']", self.route.agency.shortTitle, self.route.tag];

	// NSLog(@"RouteXPath: %@", routeXPath); /* DEBUG LOG */

	// the xml element that contains both directions we care about
	CXMLElement *routeNode = [[coordinateParser nodesForXPath:routeXPath error:nil] objectAtIndex:0];

	// get the zoom level and yCropPixel value
	self.zoomLevel = [[[routeNode attributeForName:@"zoom"] stringValue] intValue];
	self.yCropPixels = [[[routeNode attributeForName:@"yCropPixels"] stringValue] intValue];

	// get center coordinate
	NSString *center = [[routeNode attributeForName:@"center"] stringValue];
	NSArray *centerCoordinateStrings = [center componentsSeparatedByString:@","];
	self.centerCoordinate = CLLocationCoordinate2DMake([[centerCoordinateStrings objectAtIndex:0] doubleValue], [[centerCoordinateStrings objectAtIndex:1] doubleValue]);

	// create directionAnnotation for each direction whose show = true
	for (Direction *direction in shownDirections) {

		NSString *directionXPath = [NSString stringWithFormat:@"direction[@tag='%@']", direction.tag];

		CXMLElement *directionElement = [[routeNode nodesForXPath:directionXPath error:nil] objectAtIndex:0];

		// map coordinates for the direction's destination
		int x = [[[directionElement attributeForName:@"x"] stringValue] intValue];
		int y = [[[directionElement attributeForName:@"y"] stringValue] intValue];

		// NSLog(@"%@ (%i,%i)", direction.name, x,y); /* DEBUG LOG */

		NSArray *nibs = [[NSBundle mainBundle] loadNibNamed:@"DirectionAnnotationView" owner:self options:nil];
		DirectionAnnotationView *pin = [nibs objectAtIndex:0];

		pin.mapFrame = self.routeMap.frame;
		[pin setDirection:direction];

		// special cases for loop routes
		NSString *routeTag = direction.route.tag;
		NSString *agencyShortTitle = direction.route.agency.shortTitle;
		int pinIndex = [shownDirections indexOfObject:direction];
		int verticalOffset = 0;

		if ( ([routeTag isEqualToString:@"22"]||
		      [routeTag isEqualToString:@"25"]||[routeTag isEqualToString:@"49"]||
		      [routeTag isEqualToString:@"89"]||[routeTag isEqualToString:@"93"]||
		      [routeTag isEqualToString:@"98"]||[routeTag isEqualToString:@"242"]||
		      [routeTag isEqualToString:@"251"]||[routeTag isEqualToString:@"275"]||
		      [routeTag isEqualToString:@"350"]||[routeTag isEqualToString:@"376"])&&[agencyShortTitle isEqualToString:@"actransit"] ) {
			if (pinIndex == 0) {

				pin.pinView.hidden = YES;
				verticalOffset = -50;
				pin.subtitle.text = @"";

				pin.title.frame = CGRectMake(pin.title.frame.origin.x, pin.title.frame.origin.y + 6, pin.title.frame.size.width, pin.title.frame.size.height);

			} else {
				pin.subtitle.text = @"";

				pin.title.frame = CGRectMake(pin.title.frame.origin.x, pin.title.frame.origin.y + 6, pin.title.frame.size.width, pin.title.frame.size.height);

			}
		}
		[pin setPoint:CGPointMake(x, y + verticalOffset)];

		// NSLog(@"%d",pin.frame.size.width);

		[self.view addSubview:pin];

	}
}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self.locationManager startUpdatingLocation];

	// setup notification to listen to notifications from directionAnnotationsView
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(directionSelected:) name:@"directionTapped" object:nil];
	[notificationCenter addObserver:self selector:@selector(toggleLocationUpdating:) name:UIApplicationWillResignActiveNotification object:nil];
	[notificationCenter addObserver:self selector:@selector(toggleLocationUpdating:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void) viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[self.locationManager stopUpdatingLocation];

	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter removeObserver:self];
}

// turns off location updating
- (void) toggleLocationUpdating:(NSNotification *)note {

	if ([note.name isEqual:UIApplicationWillResignActiveNotification]) {

		NSLog(@"DirectionsVC: Location Updating OFF"); /* DEBUG LOG */
		[self.locationManager stopUpdatingLocation];
	} else if ([note.name isEqual:UIApplicationDidBecomeActiveNotification]) {

		NSLog(@"DirectionsVC: Location Updating ON"); /* DEBUG LOG */
		[self.locationManager startUpdatingLocation];
	}
}

- (BOOL) pointInside:(CGPoint)point withEvent:(UIEvent *)event {
	// UIView will be "transparent" for touch events if we return NO
	return(NO);

}

- (void) locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {

	if ( (newLocation.horizontalAccuracy < 0)||(newLocation.horizontalAccuracy > 300)||([newLocation.timestamp timeIntervalSinceNow] < -120) ) {

		NSLog(@"%@", @"BAD FIX"); /* DEBUG LOG */
		return;
	}
	// debugging on simulator to make the user location be in sf
	// newLocation = [[CLLocation alloc] initWithLatitude:37.788917 longitude:-122.403606];

	// Calculate center as pixel coordinates in world map
	int centerX = [DataHelper xCoordinateFromLongitude:self.centerCoordinate.longitude];
	int centerY = [DataHelper yCoordinateFromLatitude:self.centerCoordinate.latitude];

	// Calculate center as pixel coordinates in image
	// X=320 and Y=600 is the image size we get from Google
	int centerOffsetX = round(320 / 2);
	int centerOffsetY = round(600 / 2);

	// x,y position on original static map of the user location
	int originalUserLocationX = [DataHelper xCoordinateFromLongitude:newLocation.coordinate.longitude];
	int originalUserLocationY = [DataHelper yCoordinateFromLatitude:newLocation.coordinate.latitude];

	int deltaX = (originalUserLocationX - centerX) >> (21 - self.zoomLevel);
	int deltaY = (originalUserLocationY - centerY) >> (21 - self.zoomLevel);
	int userMarkerX = centerOffsetX + deltaX;
	int userMarkerY = centerOffsetY + deltaY;

	// Since we have performed all the calculations wrt to the original 320x600 image,
	// we need to account for the part that was cropped off at the top

	userMarkerY = userMarkerY - self.yCropPixels;

	// Final x,y co-ordinates where you can show the user's current location is (userMarkerX, userMarkerY)

	UIImageView *userMarker = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"TrackingDot.png"]];
	userMarker.center = CGPointMake(userMarkerX, userMarkerY);

	// add the marker to the map only once
	[self.routeMap insertSubview:userMarker atIndex:0];
	[self.routeMap setNeedsDisplay];


	NSLog(@"ADDED USER MARKER"); /* DEBUG LOG */

	[self.locationManager stopUpdatingLocation];

}

// Load the stopsTVC once a direction is selected
- (void) directionSelected:(NSNotification *)note {

	Direction *tappedDirection = note.object;

	StopsTVC *stopsTableViewController = [[StopsTVC alloc] init];
	stopsTableViewController.direction = tappedDirection;

	[self.navigationController pushViewController:stopsTableViewController animated:YES];

}

#pragma mark -
#pragma mark Memory

- (void) viewDidUnload {
	[self setGoogleLogo:nil];
	// Release any retained subviews of the main view.
	self.routeMap = nil;
    
    self.locationManager.delegate = nil;
}


@end
