/*
 Copyright 2016-2018 Jan Adamec.
 
 This file is part of "Dvanactka".
 
 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.
 
 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
 */

import UIKit
import MapKit

protocol CRxRefineLocDelegate {
    func locationRefined(_ loc: CLLocation);
}

class RefineLocCtl: UIViewController {
    @IBOutlet weak var m_mapView: MKMapView!
    @IBOutlet weak var m_segmMapType: UISegmentedControl!
    @IBOutlet weak var m_lbHint: UILabel!
    
    var m_locInit: CLLocation?
    var m_aPin: MKAnnotation?
    var delegate: CRxRefineLocDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Localization
        m_segmMapType.setTitle(NSLocalizedString("Standard", comment:""), forSegmentAt: 0);
        m_segmMapType.setTitle(NSLocalizedString("Sattelite", comment:""), forSegmentAt: 1);
        m_segmMapType.setTitle(NSLocalizedString("Hybrid", comment:""), forSegmentAt: 2);
        m_lbHint.text = NSLocalizedString("Long press to set the location", comment:"");

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
            var coord = CLLocationCoordinate2D(latitude: 50.0020275, longitude: 14.4185889);
            if let municipalityCenter = CRxAppDefinition.shared.m_aMunicipalityCenter {
                coord = municipalityCenter.coordinate;
            }
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
    @objc func addAnnotation(gestureRecognizer: UIGestureRecognizer) {
        
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
    @IBAction func onSegmMapTypeChanged(_ sender: Any) {
        switch m_segmMapType.selectedSegmentIndex {
        case 0: m_mapView.mapType = .standard;
        case 1: m_mapView.mapType = .satellite;
        case 2: m_mapView.mapType = .hybrid;
        default: print("wrong map type");
        }
    }
    
    //---------------------------------------------------------------------------
    /*func onBtnDone() {
        if let loc = m_locInit {
            delegate?.locationRefined(loc);
        }
        //dismiss(animated: true, completion: nil);
    }*/

}
