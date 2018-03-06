//
//  ViewController.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit
import StoreKit

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
        
        CRxDataSourceManager.shared.delegate = self;
        
        // Google Analytics
        if let tracker = GAI.sharedInstance().defaultTracker {
            tracker.set(kGAIScreenName, value: "Home");
            if let builder = GAIDictionaryBuilder.createScreenView() {
                tracker.send(builder.build() as [NSObject : AnyObject])
            }
        }
    }

    //---------------------------------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated);

        // ask for rating
        if #available( iOS 10.3,*){
            if isAllowedToOpenStoreReview() {
                SKStoreReviewController.requestReview()
            }
        }
    }
    
    //---------------------------------------------------------------------------
    func isAllowedToOpenStoreReview() -> Bool {
        let today = Date();
        let launchTime = UserDefaults.standard.double(forKey: "LastLaunchDefaultsKey");
        if launchTime == 0.0 {
            UserDefaults.standard.set(today.timeIntervalSince1970, forKey: "LastLaunchDefaultsKey");
            return false;
        }
        let lastShown = Date(timeIntervalSince1970: launchTime);
        if today.timeIntervalSince(lastShown) > 60*60*24*10 {  // 10 days since last review attempt
            UserDefaults.standard.set(today.timeIntervalSince1970, forKey: "LastLaunchDefaultsKey");
            return true;
        }
        return false;
    }
    
    //---------------------------------------------------------------------------
    static func dsHasBadge(_ ds: CRxDataSource?) -> Bool {
        return ds != nil && ds!.m_eType == .news;
    }

    //---------------------------------------------------------------------------
    // MARK: UICollectionViewDataSource
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "headerCol", for: indexPath);
        return headerView;
    }
    
    //---------------------------------------------------------------------------
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1;
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return AppDefinition.shared.m_arrDataSourceOrder.count;
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellDS", for: indexPath) as! CRxDSCell
        
        if let ds = CRxDataSourceManager.shared.m_dictDataSources[AppDefinition.shared.m_arrDataSourceOrder[indexPath.row]] {
            var sTitle = ds.m_sTitle;
            if let shortTitle = ds.m_sShortTitle {
                sTitle = shortTitle;
            }
            cell.m_lbTitle.text = sTitle;
            cell.m_imgIcon.image = UIImage(named: ds.m_sIcon);
            cell.layer.borderWidth = 1.0;
            cell.layer.borderColor = UIColor(white:0, alpha:0.15).cgColor;

            let iCl = ds.m_iBackgroundColor;
            cell.backgroundColor = UIColor(red: CGFloat(iCl&0xFF0000)/CGFloat(0xFF0000),
                                           green: CGFloat(iCl&0xFF00)/CGFloat(0xFF00),
                                           blue: CGFloat(iCl&0xFF)/CGFloat(0xFF), alpha: 1.0);

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
            
            if !ViewController.dsHasBadge(ds) || ds.m_bIsBeingRefreshed {
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
    
    //---------------------------------------------------------------------------
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let nViewWidth = min(collectionView.bounds.width, collectionView.bounds.height);
        let nItemsPerRow: CGFloat = floor(max(3.0, nViewWidth / 150.0));       // at least 3 cols, max size of cell is 150 (for iPad)
        let nSpacing = 6*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 10;
        let nCellWidth = floor(min(180, (nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow));
        return CGSize(width: nCellWidth, height: nCellWidth);
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt
        section: Int) -> UIEdgeInsets {
        
        // calculate cell size based on portait
        let nViewWidth = min(collectionView.bounds.width, collectionView.bounds.height);
        let nItemsPerRow: CGFloat = floor(max(3.0, nViewWidth / 150.0));       // at least 3 cols, max size of cell is 150 (for iPad)
        let nSpacing = 6*(nItemsPerRow-1);
        let nMinInsets: CGFloat = 10;
        let nCellWidth = floor(min(180, (nViewWidth-nSpacing-2*nMinInsets) / nItemsPerRow));
        //let leftInset = (nViewWidth - CGFloat(nCellWidth*nItemsPerRow + nSpacing)) / 2; // center
        
        // return insets based on current orientation
        let nRealViewWidth = collectionView.bounds.width;
        let nRealItemsPerRow = floor((nRealViewWidth-2*nMinInsets) / nCellWidth);
        let nRealSpacing = 6*(nRealItemsPerRow-1);
        let leftInset = floor((nRealViewWidth - CGFloat(nCellWidth*nRealItemsPerRow + nRealSpacing)) / 2); // center
        
        return UIEdgeInsetsMake(nMinInsets, leftInset-1, nMinInsets, leftInset-1);
    }
    
    //---------------------------------------------------------------------------
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator);
        self.collectionView?.collectionViewLayout.invalidateLayout();
    }
    
    //---------------------------------------------------------------------------
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        m_sDsSelected = AppDefinition.shared.m_arrDataSourceOrder[indexPath.row];
        
        // hide unread badge
        if let cell = collectionView.cellForItem(at: indexPath) as? CRxDSCell,
            let lbBadge = cell.m_lbBadge {
            lbBadge.isHidden = true;
        }

        if m_sDsSelected == CRxDataSourceManager.dsReportFault {
            performSegue(withIdentifier: "segueReportFault", sender: self)
        }
        else if m_sDsSelected == CRxDataSourceManager.dsGame {
            performSegue(withIdentifier: "segueGame", sender: self)
        }
        else {
            performSegue(withIdentifier: "segueEvents", sender: self)
        }
    }
    
    //---------------------------------------------------------------------------
    // check bkg color on press
    override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        if let cell = cell, let cl = cell.backgroundColor {
            var r: CGFloat = 0;
            var g: CGFloat = 0;
            var b: CGFloat = 0;
            var a: CGFloat = 0;
            cl.getRed(&r, green: &g, blue: &b, alpha: &a);
            cell.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: 0.7);
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        if let cell = cell, let cl = cell.backgroundColor {
            var r: CGFloat = 0;
            var g: CGFloat = 0;
            var b: CGFloat = 0;
            var a: CGFloat = 0;
            cl.getRed(&r, green: &g, blue: &b, alpha: &a);
            cell.backgroundColor = UIColor(red: r, green: g, blue: b, alpha: 1.0);
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
        let aDS = CRxDataSourceManager.shared.m_dictDataSources[m_sDsSelected];
        if segue.identifier == "segueEvents" {
            let destVC = segue.destination as! EventsCtl
            destVC.m_aDataSource = aDS;
            destVC.m_bAskForFilter = (aDS != nil && aDS!.m_bFilterAsParentView);
        }
    }
    
    //---------------------------------------------------------------------------
    func dataSourceRefreshEnded(dsId: String, error: String?) {
        if error == nil {
            let aDS = CRxDataSourceManager.shared.m_dictDataSources[dsId];
            if ViewController.dsHasBadge(aDS) {
                self.collectionView?.reloadData();  // update badges
            }
            CRxGame.shared.reinit();
        }
    }

    //---------------------------------------------------------------------------
    @objc func onBtnInfo() {
        /*
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let appInfoCrl = storyboard.instantiateViewController(withIdentifier: "appInfoCtlNav")
        present(appInfoCrl, animated: true, completion: nil);
        */
        performSegue(withIdentifier: "segueAbout", sender: self);
    }
}

