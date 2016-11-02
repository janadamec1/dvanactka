//
//  MapCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 02.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit

class CRxMapItem : NSObject, MKAnnotation {
    var m_rec: CRxEventRecord!

    init(record: CRxEventRecord) {
        m_rec = record;
        super.init()
    }
    
    var title: String? {
        return m_rec.m_sTitle;
    }
    var coordinate: CLLocationCoordinate2D {
        return m_rec.m_aLocation!.coordinate;
    }
}

class MapCtl: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var m_mapView: MKMapView!
    
    var m_aDataSource: CRxDataSource?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        let m_locManager = CLLocationManager();
        //m_locManager.delegate = self;
        //m_locManager.distanceFilter = 5;
        
        var coordMin = CLLocationCoordinate2D(latitude:0.0, longitude: 0.0)
        var coordMax = CLLocationCoordinate2D(latitude:0.0, longitude: 0.0)

        if CLLocationManager.locationServicesEnabled() {
            let authStatus = CLLocationManager.authorizationStatus()
            
            if authStatus == .notDetermined {
                m_locManager.requestWhenInUseAuthorization();
            }
            //if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
                
            //}
        }

        m_mapView.delegate = self
        
        var nCount = 0;
        if let ds = m_aDataSource {
            for item in ds.m_arrItems {
                if let loc = item.m_aLocation {
                    let mapItem = CRxMapItem(record: item);
                    m_mapView.addAnnotation(mapItem);
                    
                    let coord = loc.coordinate;
                    if nCount == 0 {
                        coordMin = coord;
                        coordMax = coord;
                    }
                    else {
                        if coord.latitude < coordMin.latitude { coordMin.latitude = coord.latitude; }
                        if coord.longitude < coordMin.longitude { coordMin.longitude = coord.longitude; }
                        if coord.latitude > coordMax.latitude { coordMax.latitude = coord.latitude; }
                        if coord.longitude > coordMax.longitude { coordMax.longitude = coord.longitude; }
                    }
                    nCount += 1
                }
            }
        }
        
        if nCount > 0 {
            var regView: MKCoordinateRegion!;
            if nCount == 1 {
                regView = MKCoordinateRegionMakeWithDistance(coordMin, 1500, 1500); }
            else
            {
                var coordCenter = coordMin;
                coordCenter.latitude = (coordMin.latitude + coordMax.latitude)/2;
                coordCenter.longitude = (coordMin.longitude + coordMax.longitude)/2;
                
                regView = MKCoordinateRegionMake(coordCenter, MKCoordinateSpanMake((coordMax.latitude - coordMin.latitude)*1.5,
                                                                                   (coordMax.longitude - coordMin.longitude)*1.5));
            }
            m_mapView.setRegion(regView, animated: true);
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? CRxMapItem {
            let identifier = "pin"
            var view: MKPinAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                as? MKPinAnnotationView {
                dequeuedView.annotation = annotation
                view = dequeuedView
            } else {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true
                view.calloutOffset = CGPoint(x: -5, y: 5)
                view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure) as UIView
            }
            return view
        }
        return nil
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
