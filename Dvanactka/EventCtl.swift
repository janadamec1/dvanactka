//
//  RadniceAktualCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit
import EventKit
import EventKitUI

class NewsCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_lbDate: UILabel!
    @IBOutlet weak var m_btnWebsite: UIButton!
}
class EventCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_lbDate: UILabel!
    @IBOutlet weak var m_btnWebsite: UIButton!
    @IBOutlet weak var m_btnBuy: UIButton!
    @IBOutlet weak var m_btnAddToCalendar: UIButton!
    
}
class PlaceCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    
}

class EventsCtl: UITableViewController, CLLocationManagerDelegate, EKEventEditViewDelegate {
    var m_aDataSource: CRxDataSource?
    var m_orderedItems = [String : [CRxEventRecord]]()  // category localName -> array of records
    var m_orderedCategories = [String]()                // sorted category local names
    var m_locManager = CLLocationManager();
    var m_coordLast = CLLocationCoordinate2D(latitude:0, longitude: 0);
    var m_bUserLocationAcquired = false;

    override func viewDidLoad() {
        super.viewDidLoad()

        m_locManager.delegate = self;
        m_locManager.distanceFilter = 5;

        if let ds = m_aDataSource {
            self.title = ds.m_sTitle;
            
            if (ds.m_bShowMap) {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Map", comment: ""), style: .plain, target: self, action: #selector(EventsCtl.showMap));
            }
            
            if ds.m_eType == .places {
                self.tableView.allowsSelection = true;
                if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
                    m_locManager.startUpdatingLocation();
                }
            }
            self.tableView.rowHeight = UITableViewAutomaticDimension;
            self.tableView.estimatedRowHeight = 90.0;
        }
        setRecordsDistance();
        sortRecords();
    }
    
    func sortRecords() {
        guard let ds = m_aDataSource else {
            return
        }
        m_orderedItems.removeAll();
        m_orderedCategories.removeAll();
        
        let df = DateFormatter();
        df.dateStyle = .full;
        df.timeStyle = .none;
        let today = Date();
        
        // first add objects to groups
        for rec in ds.m_arrItems {
            var sCatName = "";
            switch ds.m_eType {
            case .news: sCatName = "";    // one category for news
            case .places: sCatName = CRxEventRecord.categoryLocalName(category: rec.m_eCategory);
            case .events:   // use date as category
                guard let date = rec.m_aDate else {
                    continue    // remove recoords without date
                }
                if date < today {   // do not show old events
                    continue;
                }
                sCatName = df.string(from: date);
            }
            if m_orderedItems[sCatName] == nil {
                m_orderedItems[sCatName] = [rec];   // new category
                m_orderedCategories.append(sCatName);
            }
            else {
                m_orderedItems[sCatName]?.append(rec);  // into existing
            }
        }
        if ds.m_eType == .places || ds.m_eType == .events {
            // now sort each group by distance and name (Swift 3 does not support inplace ordering)
            var sortedItems = [String : [CRxEventRecord]]();
            for groupIt in m_orderedItems {
                if ds.m_eType == .places {
                    sortedItems[groupIt.key] = groupIt.value.sorted(by: {$0.m_distFromUser < $1.m_distFromUser });
                    //sortedItems[groupIt.key] = groupIt.value.sorted(by: {$0.m_distFromUser < $1.m_distFromUser || ($0.m_distFromUser == $1.m_distFromUser && $0.m_sTitle < $1.m_sTitle) });
                }
                else if (ds.m_eType == .events) {
                    sortedItems[groupIt.key] = groupIt.value.sorted(by: {$0.m_aDate! < $1.m_aDate! });
                }
            }
            m_orderedItems = sortedItems;
        }
    }
    
    func setRecordsDistance() {
        guard let ds = m_aDataSource else {
            return
        }
        if !m_bUserLocationAcquired {
            return
        }
        let locUser = CLLocation(latitude: m_coordLast.latitude, longitude: m_coordLast.longitude);
        for rec in ds.m_arrItems {
            if let loc = rec.m_aLocation {
                rec.m_distFromUser = loc.distance(from: locUser);
            }
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return m_orderedCategories.count;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let items = m_orderedItems[m_orderedCategories[section]] {
            return items.count;
        }
        else {
            return 0;
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (m_orderedCategories.count < 2) {
            return nil
        }
        return m_orderedCategories[section];
    }
    
    func record(at indexPath:IndexPath) -> CRxEventRecord? {
        if let items = m_orderedItems[m_orderedCategories[indexPath.section]] {
            return items[indexPath.row];
        }
        else {
            return nil;
        }
    }
    
    func btnTag(from indexPath:IndexPath) -> Int {
        return indexPath.section*10000 + indexPath.row;
    }
    func btnIndexPath(from tag:Int) -> IndexPath {
        return IndexPath(row: tag % 10000, section: tag / 10000);
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let rec = record(at: indexPath),
            let ds = m_aDataSource
            else {return UITableViewCell();}

        var cell: UITableViewCell!;
        
        if ds.m_eType == .news {
            let cellNews = tableView.dequeueReusableCell(withIdentifier: "cellNews", for: indexPath) as! NewsCell
            cellNews.m_lbTitle.text = rec.m_sTitle;
            cellNews.m_lbText.text = rec.m_sText ?? "";
            var sDateText = "";
            if let aDate = rec.m_aDate {
                let df = DateFormatter();
                df.dateStyle = .full;
                df.timeStyle = .none;
                sDateText = df.string(from: aDate);
            }
            cellNews.m_lbDate.text = sDateText
            cellNews.m_btnWebsite.isHidden = (rec.m_sInfoLink==nil);
            let iBtnTag = btnTag(from: indexPath);
            cellNews.m_btnWebsite.tag = iBtnTag;
            cell = cellNews;
        }
        else if ds.m_eType == .events {
            let cellEvent = tableView.dequeueReusableCell(withIdentifier: "cellEvent", for: indexPath) as! EventCell
            cellEvent.m_lbTitle.text = rec.m_sTitle;
            cellEvent.m_lbText.text = rec.m_sText ?? "";
            var sDateText = "";
            if let aDate = rec.m_aDate {
                let df = DateFormatter();
                df.dateStyle = .none;
                df.timeStyle = .short;
                sDateText = df.string(from: aDate);
                if let aDateTo = rec.m_aDateTo {
                    sDateText += "\n- " + df.string(from: aDateTo);
                }
            }
            else {
                cellEvent.m_btnAddToCalendar.isHidden = true;
            }
            cellEvent.m_lbDate.text = sDateText
            cellEvent.m_btnWebsite.isHidden = (rec.m_sInfoLink==nil);
            cellEvent.m_btnBuy.isHidden = (rec.m_sBuyLink==nil);
            
            let iBtnTag = btnTag(from: indexPath);
            cellEvent.m_btnWebsite.tag = iBtnTag;
            cellEvent.m_btnBuy.tag = iBtnTag;
            cellEvent.m_btnAddToCalendar.tag = iBtnTag;
            cell = cellEvent;
        }
        else if ds.m_eType == .places {
            let cellPlace = tableView.dequeueReusableCell(withIdentifier: "cellPlace", for: indexPath) as! PlaceCell
            cellPlace.m_lbTitle.text = rec.m_sTitle;
            var sDistance = "";
            if m_bUserLocationAcquired && rec.m_aLocation != nil {
                if rec.m_distFromUser > 1000 {
                    let km = round(rec.m_distFromUser/10.0)/100.0;
                    sDistance = "\(km) km";
                }
                else {
                    sDistance = "\(Int(rec.m_distFromUser)) m";
                }
            }
            if let text = rec.m_sText {
                if !sDistance.isEmpty {
                    sDistance += " | ";
                }
                sDistance += text;
            }
            if sDistance.isEmpty {
                sDistance = "  "    // must not be empty, causes strange effects
            }
            cellPlace.m_lbText.text = sDistance;
            cell = cellPlace;
        }
        else {
            cell = UITableViewCell();
        }
        
        if ds.m_eType != .places {
            cell.setNeedsUpdateConstraints();
            cell.updateConstraintsIfNeeded();
        }
        return cell;
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let rec = record(at: indexPath) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let placeCtl = storyboard.instantiateViewController(withIdentifier: "placeDetailCtl") as! PlaceDetailCtl
            placeCtl.m_aRecord = rec;
            navigationController?.pushViewController(placeCtl, animated: true);
        }
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if let rec = record(at: indexPath) {
            rec.openInfoLink();
        }
    }
    
    @IBAction func onBtnWebsiteTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            rec.openInfoLink();
        }
    }

    @IBAction func onBtnWebsiteNewsTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            rec.openInfoLink();
        }
    }
    
    @IBAction func onBtnBuyTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            rec.openBuyLink();
        }
    }
    
    func addEventToCalendar(_ title: String, description: String?, location: String?, startDate: Date, endDate: Date) {
        let eventStore = EKEventStore()
        
        eventStore.requestAccess(to: .event, completion: { (granted, error) in
            if (granted) && (error == nil) {
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.notes = description
                event.location = location?.replacingOccurrences(of: "\n", with: ", ")
                event.startDate = startDate
                event.endDate = endDate
                event.notes = description
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                let eventController = EKEventEditViewController()
                eventController.eventStore = eventStore
                eventController.editViewDelegate = self
                eventController.event = event
                
                self.present(eventController, animated: true, completion: nil);
            } else {
                let alertController = UIAlertController(title: NSLocalizedString("Access Denied", comment:""),
                                              message: NSLocalizedString("Permission is needed to access the calendar. Go to Settings > Privacy > Calendars to allow access for this app.", comment:""), preferredStyle: .alert);
                let actionOK = UIAlertAction(title: "OK", style: .default, handler: { (result : UIAlertAction) -> Void in
                    print("OK")})
                alertController.addAction(actionOK);
                self.present(alertController, animated: true, completion: nil);
            }
        })
    }
    
    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        self.dismiss(animated: true, completion: nil);
    }
    
    @IBAction func onBtnCalendarTouched(_ sender: Any) {
        if let btn = sender as? UIButton,
            let rec = record(at: btnIndexPath(from: btn.tag)) {
            if let startDate = rec.m_aDate {
                var endDate = rec.m_aDateTo
                if endDate == nil {
                    endDate = startDate.addingTimeInterval(60*60)   // 1 hour
                }
                addEventToCalendar(rec.m_sTitle, description:nil, location:rec.m_sAddress, startDate: startDate, endDate: endDate!);
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let lastLocation = locations.last {
            m_coordLast = lastLocation.coordinate;
            m_bUserLocationAcquired = true;
            
            setRecordsDistance();
            sortRecords();
            self.tableView.reloadData();
        }
    }

    func showMap() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mapCtl = storyboard.instantiateViewController(withIdentifier: "mapCtl") as! MapCtl
        mapCtl.m_aDataSource = m_aDataSource;
        mapCtl.m_coordLast = m_coordLast;
        navigationController?.pushViewController(mapCtl, animated: true);
    }
    
    // MARK: - Navigation
    /*
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }*/
}
