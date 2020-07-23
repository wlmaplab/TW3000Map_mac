//
//  PostAnnotationView.swift
//  TW3000Map
//
//  Created by rlbot on 2020/7/22.
//  Copyright © 2020 WL. All rights reserved.
//

import Foundation
import MapKit

class PostAnnotationView: MKAnnotationView {
    
    var coordinate : CLLocationCoordinate2D
    var info : PostItem?
    var selectedAction : ((_ coordinate: CLLocationCoordinate2D) -> Void)?
    
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            if let action = selectedAction {
                action(coordinate)
            }
        }
    }
    
}


