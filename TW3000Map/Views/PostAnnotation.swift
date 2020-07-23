//
//  PostAnnotation.swift
//  TW3000Map
//
//  Created by rlbot on 2020/7/22.
//  Copyright © 2020 WL. All rights reserved.
//

import Foundation
import MapKit

class PostAnnotation: NSObject, MKAnnotation {
    var coordinate : CLLocationCoordinate2D
    var image : NSImage?
    var info : PostItem?
    
    override init() {
        self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    convenience init(coordinate: CLLocationCoordinate2D) {
        self.init()
        self.coordinate = coordinate
    }
}

