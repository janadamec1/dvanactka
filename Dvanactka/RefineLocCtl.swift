//
//  RefineLocCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 12.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit

protocol CRxRefineLocDelegate {
    func locationRefined(_ loc: CLLocation);
}

class RefineLocCtl: UIViewController {
    @IBOutlet weak var m_mapView: MKMapView!

    var m_locInit: CLLocation?
    var m_aPin: MKAnnotation?
    var delegate: CRxRefineLocDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem:.done, target: self, action: #selector(RefineLocCtl.onBtnDone));

        if let loc = m_locInit {
            let regView = MKCoordinateRegionMakeWithDistance(loc.coordinate, 500, 500);
            m_mapView.setRegion(regView, animated: false);
            
            let annotation = MKPointAnnotation();
            annotation.coordinate = loc.coordinate;
            annotation.title = NSLocalizedString("Location", comment: "");
            m_mapView.addAnnotation(annotation);
            
            m_aPin = annotation;
        }
        else {
            // center will be center of Praha 12
            let coord = CLLocationCoordinate2D(latitude: 50.0020275, longitude: 14.4185889);
            let regView = MKCoordinateRegionMakeWithDistance(coord, 1500, 3500);
            m_mapView.setRegion(regView, animated: false);
        }
        
        if CLLocationManager.locationServicesEnabled() && CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            m_mapView.showsUserLocation = true;
        }
        
        let aRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(RefineLocCtl.addAnnotation));
        m_mapView.addGestureRecognizer(aRecognizer);
    }
    
    //---------------------------------------------------------------------------
    func addAnnotation(gestureRecognizer: UIGestureRecognizer) {
        
        if let pin = m_aPin {
            m_mapView.removeAnnotation(pin);
        }
        
        let ptTouch = gestureRecognizer.location(in: m_mapView);
        let coord = m_mapView.convert(ptTouch, toCoordinateFrom: m_mapView);
        let annotation = MKPointAnnotation();
        annotation.coordinate = coord;
        m_mapView.addAnnotation(annotation);
        
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude);
        m_locInit = loc;
        m_aPin = annotation;
        
        delegate?.locationRefined(loc); // update immediately
    }
    
    //---------------------------------------------------------------------------
    /*func onBtnDone() {
        if let loc = m_locInit {
            delegate?.locationRefined(loc);
        }
        //dismiss(animated: true, completion: nil);
    }*/

}
