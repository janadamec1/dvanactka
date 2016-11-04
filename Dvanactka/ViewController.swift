//
//  ViewController.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit

class CRxDSCell : UICollectionViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    
}

class ViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, CLLocationManagerDelegate {
    var m_arrSources = [String]();    // data source ids in order they should appear in the collection
    var m_sDsSelected = "";
    var m_locManager = CLLocationManager();
    var m_coordLast = CLLocationCoordinate2D(latitude:0, longitude: 0);

    override func viewDidLoad() {
        super.viewDidLoad()

        m_locManager.delegate = self;
        m_locManager.distanceFilter = 5;

        if CLLocationManager.locationServicesEnabled() {
            if CLLocationManager.authorizationStatus() == .notDetermined {
                m_locManager.requestWhenInUseAuthorization();
            }
        }
        
        m_arrSources = CRxDataSourceManager.sharedInstance.m_dictDataSources.keys.sorted();
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1;
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return m_arrSources.count;
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellDS", for: indexPath) as! CRxDSCell
        cell.backgroundColor = UIColor.lightGray;
        
        if let ds = CRxDataSourceManager.sharedInstance.m_dictDataSources[m_arrSources[indexPath.row]] {
            cell.m_lbTitle.text = ds.m_sTitle;
        }

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let nItemsPerRow: CGFloat = 2;
        let nViewWidth = min(collectionView.frame.width, collectionView.frame.height);
        let nSpacing = 16*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 20;
        let nCellWidth = min(180, (nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow);
        return CGSize(width: nCellWidth, height: nCellWidth)
 
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt
        section: Int) -> UIEdgeInsets {
        
        let nItemsPerRow: CGFloat = 2.0;
        let nViewWidth = min(collectionView.frame.width, collectionView.frame.height);
        let nSpacing = 16*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 20;
        let nCellWidth = min(180, (nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow);
        
        let leftInset = (nViewWidth - CGFloat(nCellWidth*nItemsPerRow + nSpacing)) / 2; // center
        return UIEdgeInsetsMake(nMinInsets, leftInset, nMinInsets, leftInset)
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        m_sDsSelected = m_arrSources[indexPath.row];
        performSegue(withIdentifier: "segueEvents", sender: self)
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

    //---------------------------------------------------------------------------
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueEvents" {
            let destVC = segue.destination as! EventsCtl
            destVC.m_aDataSource = CRxDataSourceManager.sharedInstance.m_dictDataSources[m_sDsSelected];
        }
    }
}

