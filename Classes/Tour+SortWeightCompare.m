//
//  Tour+SortWeightCompare.m
//  MFA Guide
//
//  Created by Robert Brecher on 7/28/11.
//  Copyright 2011 Genuine Interactive. All rights reserved.
//

#import "Tour+SortWeightCompare.h"

@implementation Tour (SortWeightCompare)

- (NSComparisonResult)sortWeightCompare:(Tour *)otherTour
{
    
    NSNumber * aSortWeight = [self sortWeight];
    if (! aSortWeight) {
        aSortWeight = @99999;
    }
    NSNumber * bSortWeight = [otherTour sortWeight];
    if (! bSortWeight) {
        bSortWeight = @99999;
    }
    
    //    NSLog(@"SortWeight: %@ %@", aSortWeight, bSortWeight);
	
    if ([aSortWeight isEqualToNumber:bSortWeight]) {
        return [[self title] compare:[otherTour title]];
    } else {
        return [aSortWeight compare:bSortWeight];
    }
}

@end
