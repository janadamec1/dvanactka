//
//  ViewController.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, CLLocationManagerDelegate {
    var m_sDsSelected: String = ""
    var m_locManager = CLLocationManager();
    var m_coordLast = CLLocationCoordinate2D(latitude:0, longitude: 0);

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        m_locManager.delegate = self;
        m_locManager.distanceFilter = 5;

        if CLLocationManager.locationServicesEnabled() {
            let authStatus = CLLocationManager.authorizationStatus()
            
            if authStatus == .notDetermined {
                m_locManager.requestWhenInUseAuthorization();
            }
        }

    }

    //---------------------------------------------------------------------------
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedWhenInUse) {
            manager.startUpdatingLocation();
        }
    }
    
    //---------------------------------------------------------------------------
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocation = locations.last {
            m_coordLast = lastLocation.coordinate;
            //m_bUserLocationAcquired = YES;
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBAction func onRadNewsTouched(_ sender: Any) {
        m_sDsSelected = CRxDataSourceManager.dsRadNews;
        performSegue(withIdentifier: "segueEvents", sender: sender)
    }

    @IBAction func onRadAlertsTouched(_ sender: Any) {
        m_sDsSelected = CRxDataSourceManager.dsRadAlerts;
        performSegue(withIdentifier: "segueEvents", sender: sender)
    }

    @IBAction func onBiografTouched(_ sender: Any) {
        m_sDsSelected = CRxDataSourceManager.dsBiografProgram;
        performSegue(withIdentifier: "segueEvents", sender: sender)
    }

    @IBAction func onRadEventsTouched(_ sender: Any) {
        m_sDsSelected = CRxDataSourceManager.dsRadEvents;
        performSegue(withIdentifier: "segueEvents", sender: sender)
    }
    
    @IBAction func onCoolTreesTouched(_ sender: Any) {
        m_sDsSelected = CRxDataSourceManager.dsCoolTrees;
        performSegue(withIdentifier: "segueEvents", sender: sender)
    }
    
    @IBAction func onCooltourTouched(_ sender: Any) {
        m_sDsSelected = CRxDataSourceManager.dsCooltour;
        performSegue(withIdentifier: "segueEvents", sender: sender)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueEvents" {
            let destVC = segue.destination as! EventsCtl
            destVC.m_aDataSource = CRxDataSourceManager.sharedInstance.m_dictDataSources[m_sDsSelected];
        }
    }
}

