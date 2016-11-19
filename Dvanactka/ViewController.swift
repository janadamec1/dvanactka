//
//  ViewController.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit

// dark grey color: 62,62,62
// tint color: 0, 122, 255 (007AFF)

class CRxDSCell : UICollectionViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_imgIcon: UIImageView!
    var m_lbBadge: UILabel?
    
    /*override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            
            let colorTop = UIColor(red: 255.0/255.0, green: 199.0/255.0, blue: 58.0/255.0, alpha: 1.0);
            let colorBot = UIColor(red: 226.0/255.0, green: 73.0/255.0, blue: 0.0/255.0, alpha: 1.0);
            /*
            let colorTop = UIColor(red: 100.0/255.0, green: 120.0/255.0, blue: 180.0/255.0, alpha: 1.0);
            let colorBot = UIColor(red: 36.0/255.0, green: 40.0/255.0, blue: 121.0/255.0, alpha: 1.0);*/
            
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [colorTop.cgColor, colorBot.cgColor] as CFArray, locations: [0, 1])!
            
            let path = UIBezierPath(roundedRect: CGRect(x:0, y:0, width: frame.width, height: frame.height), cornerRadius: frame.width/4.0);
            context.saveGState()
            path.addClip()
            context.drawLinearGradient(gradient, start: CGPoint(x:frame.width / 2, y: 0), end: CGPoint(x: frame.width / 2, y: frame.height), options: CGGradientDrawingOptions())
            context.restoreGState()
        }
    }*/
}

class ViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, CLLocationManagerDelegate, CRxDataSourceRefreshDelegate {
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
        
        let btnInfo = UIButton(type: .infoLight);
        btnInfo.addTarget(self, action: #selector(ViewController.onBtnInfo), for: .touchUpInside);
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: btnInfo);
        
        //m_arrSources = CRxDataSourceManager.sharedInstance.m_dictDataSources.keys.sorted();
        m_arrSources.append(CRxDataSourceManager.dsRadNews);
        m_arrSources.append(CRxDataSourceManager.dsRadAlerts);
        m_arrSources.append(CRxDataSourceManager.dsRadEvents);
        m_arrSources.append(CRxDataSourceManager.dsBiografProgram);
        m_arrSources.append(CRxDataSourceManager.dsWaste);
        m_arrSources.append(CRxDataSourceManager.dsReportFault);
        m_arrSources.append(CRxDataSourceManager.dsCooltour);
        m_arrSources.append(CRxDataSourceManager.dsSosContacts);
        CRxDataSourceManager.sharedInstance.delegate = self;
        
        /*// colors: (now done in storyboard
        navigationController?.navigationBar.barTintColor = UIColor(red: 36.0/255.0, green: 40.0/255.0, blue: 121.0/255.0, alpha: 1.0);
        navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor(red: 180.0/255.0, green: 200.0/255.0, blue: 1.0, alpha: 1.0)]
        navigationController?.navigationBar.tintColor = .white; // for barButtonItems*/
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
        
        if let ds = CRxDataSourceManager.sharedInstance.m_dictDataSources[m_arrSources[indexPath.row]] {
            var sTitle = ds.m_sTitle;
            if let shortTitle = ds.m_sShortTitle {
                sTitle = shortTitle;
            }
            cell.m_lbTitle.text = sTitle;
            cell.m_imgIcon.image = UIImage(named: ds.m_sIcon);
            cell.layer.borderWidth = 1.0;
            cell.layer.borderColor = UIColor(white:0.85, alpha:1.0).cgColor;

            /*cell.m_lbTitle.layer.shadowColor = UIColor.black.cgColor;
            cell.m_lbTitle.layer.shadowOffset = CGSize(width: 1, height: 1);
            cell.m_lbTitle.layer.shadowOpacity = 0.4;
            cell.m_lbTitle.layer.shadowRadius = 1;
            cell.m_lbTitle.layer.masksToBounds = false;
            cell.m_lbTitle.clipsToBounds = false;*/

            /*cell.m_imgIcon.layer.shadowColor = UIColor.black.cgColor;
            cell.m_imgIcon.layer.shadowOffset = CGSize(width: 1, height: 1);
            cell.m_imgIcon.layer.shadowOpacity = 0.4;
            cell.m_imgIcon.layer.shadowRadius = 4;
            cell.m_imgIcon.clipsToBounds = false;*/
            
            if ds.m_eType != .news {
                if let lbBadge = cell.m_lbBadge {
                    lbBadge.isHidden = true;
                }
            }
            else {
                if cell.m_lbBadge == nil {
                    let lbBadge = UILabel(frame: CGRect(x: 0, y: 0, width: 1, height:1));
                    lbBadge.text = "8";
                    lbBadge.sizeToFit()
                    var rcFrame = lbBadge.frame.insetBy(dx: -2, dy: -2);
                    if rcFrame.width < rcFrame.height {
                        rcFrame = CGRect(x: 0, y: 0, width: rcFrame.height, height:rcFrame.height);
                    }
                    rcFrame.origin = CGPoint(x: cell.m_imgIcon.frame.width - rcFrame.width, y: 0);
                    lbBadge.frame = rcFrame;
                    
                    lbBadge.textAlignment = .center;
                    lbBadge.textColor = UIColor.white;
                    lbBadge.layer.masksToBounds = true;
                    lbBadge.layer.cornerRadius = rcFrame.height/2.0;
                    lbBadge.backgroundColor = UIColor.red;
                    lbBadge.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]; //it stays at top right
                    cell.m_lbBadge = lbBadge;
                    cell.m_imgIcon.addSubview(lbBadge)
                }
                if let lbBadge = cell.m_lbBadge {
                    let iUnread = ds.unreadItemsCount();
                    if iUnread == 0 {
                        lbBadge.isHidden = true;
                    }
                    else {
                        lbBadge.text = String(iUnread);
                        lbBadge.sizeToFit()
                        var rcFrame = lbBadge.frame.insetBy(dx: -2, dy: -2);
                        if rcFrame.width < rcFrame.height {
                            rcFrame = CGRect(x: 0, y: 0, width: rcFrame.height, height:rcFrame.height);
                        }
                        rcFrame.origin = CGPoint(x: cell.m_imgIcon.frame.width - rcFrame.width, y: 0);
                        lbBadge.frame = rcFrame;

                        lbBadge.isHidden = false;
                    }
                }
            }
        }

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let nItemsPerRow: CGFloat = 2.0;
        let nViewWidth = min(collectionView.frame.width, collectionView.frame.height);
        let nSpacing = 8*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 24;
        let nCellWidth = min(180, (nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow);
        return CGSize(width: nCellWidth, height: nCellWidth)
 
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt
        section: Int) -> UIEdgeInsets {
        
        let nItemsPerRow: CGFloat = 2.0;
        let nViewWidth = min(collectionView.frame.width, collectionView.frame.height);
        let nSpacing = 8*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 24;
        let nCellWidth = min(180, (nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow);
        
        let leftInset = (nViewWidth - CGFloat(nCellWidth*nItemsPerRow + nSpacing)) / 2; // center
        return UIEdgeInsetsMake(nMinInsets, leftInset, nMinInsets, leftInset)
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        m_sDsSelected = m_arrSources[indexPath.row];
        
        // hide unread badge
        if let cell = collectionView.cellForItem(at: indexPath) as? CRxDSCell,
            let lbBadge = cell.m_lbBadge {
            lbBadge.isHidden = true;
        }

        if m_sDsSelected == CRxDataSourceManager.dsReportFault {
            performSegue(withIdentifier: "segueReportFault", sender: self)
        }
        else {
            performSegue(withIdentifier: "segueEvents", sender: self)
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

    //---------------------------------------------------------------------------
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueEvents" {
            let destVC = segue.destination as! EventsCtl
            destVC.m_aDataSource = CRxDataSourceManager.sharedInstance.m_dictDataSources[m_sDsSelected];
        }
    }
    
    //---------------------------------------------------------------------------
    func dataSourceRefreshEnded(_ error: String?) {
        if error == nil {
            self.collectionView?.reloadData();  // update badges
        }
    }

    //---------------------------------------------------------------------------
    func onBtnInfo() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let appInfoCrl = storyboard.instantiateViewController(withIdentifier: "appInfoCtlNav")
        present(appInfoCrl, animated: true, completion: nil);
    }
}

