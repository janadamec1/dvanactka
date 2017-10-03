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
    var m_bForCheckIn: Bool = false;    // this marker is used as checkin location in case the object is off the road

    init(record: CRxEventRecord, forCheckIn: Bool = false) {
        m_rec = record;     // addRefs the object, keeps it even when it is deleted in DS during refresh
        m_bForCheckIn = forCheckIn;
        super.init()
    }
    
    var title: String? {
        return m_rec.m_sTitle;
    }
    
    var subtitle: String? {
        if let filter = m_rec.m_sFilter {
            return filter;
        }
        return CRxEventRecord.categoryLocalName(category: m_rec.m_eCategory);
    }
    
    var coordinate: CLLocationCoordinate2D {
        if m_bForCheckIn && m_rec.m_aLocCheckIn != nil {
            return m_rec.m_aLocCheckIn!.coordinate;
        }
        return m_rec.m_aLocation!.coordinate;
    }
    
    func mapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate:self.coordinate, addressDictionary:nil);
        let aMapItem = MKMapItem(placemark: placemark);
        aMapItem.name = self.title;
        return aMapItem;
    }

}

//--------------------------------------------------------------------------
class MapCtl: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var m_mapView: MKMapView!
    @IBOutlet weak var m_segmMapType: UISegmentedControl!
    
    var m_aDataSource: CRxDataSource?
    var m_sParentFilter: String?                        // show only items with this filter (for ds with filterAsParentView)
    var m_coordLast = CLLocationCoordinate2D(latitude: 0, longitude: 0)

    override func viewDidLoad() {
        super.viewDidLoad()

        // Localization
        m_segmMapType.setTitle(NSLocalizedString("Standard", comment:""), forSegmentAt: 0);
        m_segmMapType.setTitle(NSLocalizedString("Sattelite", comment:""), forSegmentAt: 1);
        m_segmMapType.setTitle(NSLocalizedString("Hybrid", comment:""), forSegmentAt: 2);
        
        //var bUserLocationKnown = false;
        var coordMin = CLLocationCoordinate2D(latitude:0.0, longitude: 0.0)
        var coordMax = CLLocationCoordinate2D(latitude:0.0, longitude: 0.0)
        var nCount = 0;

        if CLLocationManager.locationServicesEnabled() {
            let authStatus = CLLocationManager.authorizationStatus()
            if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
                
                m_mapView.showsUserLocation = true;
                if (m_coordLast.longitude != 0 || m_coordLast.latitude != 0)
                {
                    coordMin = m_coordLast;
                    coordMax = m_coordLast;
                    //bUserLocationKnown = true;
                    //nCount = 1;
                }
                
                // add button to scroll to user location
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "location"), style: .plain, target: self, action: #selector(MapCtl.onBtnLocation));
            }
        }

        m_mapView.delegate = self
        
        if let ds = m_aDataSource {
            for rec in ds.m_arrItems {
                
                // filter
                if ds.m_bFilterAsParentView {
                    if rec.m_sFilter == nil {
                        continue;   // records without filter are shown in the parent tableView
                    }
                    if let sFilter = rec.m_sFilter,
                        let sParentFilter = m_sParentFilter {
                        if sFilter != sParentFilter {
                            continue;
                        }
                    }
                }

                if let loc = rec.m_aLocation {
                    let mapItem = CRxMapItem(record: rec);
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

    //--------------------------------------------------------------------------
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? CRxMapItem {
            var identifier = "pin"
            if let category = annotation.m_rec.m_eCategory {
                identifier = category; // for reusing
            }
            
            var view: MKAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                dequeuedView.annotation = annotation
                view = dequeuedView
            }
            else {
                var aIcon: UIImage?;
                if let category = annotation.m_rec.m_eCategory {
                    aIcon = UIImage(named: CRxEventRecord.categoryIconName(category: category));
                }
                if let icon = aIcon {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier);
                    view.image = icon;
                }
                else {
                    view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier);
                    view.calloutOffset = CGPoint(x: -5, y: 5);
                }
                view.canShowCallout = true
                view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure) as UIView
            }
            return view
        }
        return nil
    }
    
    //--------------------------------------------------------------------------
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let annot = view.annotation,
            let aMapItem = annot as? CRxMapItem {
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let placeCtl = storyboard.instantiateViewController(withIdentifier: "placeDetailCtl") as! PlaceDetailCtl
            placeCtl.m_aRecord = aMapItem.m_rec;
            navigationController?.pushViewController(placeCtl, animated: true);
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onSegmMapTypeChanged(_ sender: Any) {
        switch m_segmMapType.selectedSegmentIndex {
        case 0: m_mapView.mapType = .standard;
        case 1: m_mapView.mapType = .satellite;
        case 2: m_mapView.mapType = .hybrid;
        default: print("wrong map type");
        }
    }
    
    //--------------------------------------------------------------------------
    @objc func onBtnLocation() {
        if let userLoc = m_mapView.userLocation.location {
            m_coordLast = userLoc.coordinate;
        }
        let regView = MKCoordinateRegionMakeWithDistance(m_coordLast, 1000, 1000);
        m_mapView.setRegion(regView, animated: true);
    }
}
