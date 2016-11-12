//
//  RefineLocCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 12.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit

class RefineLocCtl: UIViewController {
    @IBOutlet weak var m_mapView: MKMapView!

    var m_locInit: CLLocation?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem:.done, target: self, action: #selector(RefineLocCtl.onBtnDone));

        if let loc = m_locInit {
            let regView = MKCoordinateRegionMakeWithDistance(loc.coordinate, 500, 500);
            m_mapView.setRegion(regView, animated: false);
            
            let annotation = MKPointAnnotation();
            annotation.coordinate = loc.coordinate;
            annotation.title = NSLocalizedString("Location", comment: "");
            m_mapView.addAnnotation(annotation);
        }
        else {
            // center will be center of Praha 12
            let coord = CLLocationCoordinate2D(latitude: 50.0020275, longitude: 14.4185889);
            let regView = MKCoordinateRegionMakeWithDistance(coord, 1500, 3500);
            m_mapView.setRegion(regView, animated: false);
        }
    }
    
    func onBtnDone() {
        dismiss(animated: true, completion: nil);
        // TODO: send location
    }

}
