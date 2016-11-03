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
    //@IBOutlet weak var m_lbCategory: UILabel!
    
}
class EventCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_lbDate: UILabel!
    //@IBOutlet weak var m_lbCategory: UILabel!
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
    var m_locManager = CLLocationManager();
    var m_coordLast = CLLocationCoordinate2D(latitude:0, longitude: 0);

    override func viewDidLoad() {
        super.viewDidLoad()

        m_locManager.delegate = self;
        m_locManager.distanceFilter = 5;

        if let ds = m_aDataSource {
            self.title = ds.m_sTitle;
            
            if (ds.m_bShowMap) {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Map", comment: ""), style: .plain, target: self, action: #selector(EventsCtl.showMap));
            }
            
            if ds.m_eType != .places {
                self.tableView.rowHeight = UITableViewAutomaticDimension;
                self.tableView.estimatedRowHeight = 90.0;
            }
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let ds = m_aDataSource {
            return ds.m_arrItems.count;
        }
        else {
            return 0;
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let ds = m_aDataSource
            else {return UITableViewCell();}

        let rec: CRxEventRecord = ds.m_arrItems[indexPath.row];

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
            cellNews.accessoryType = (rec.m_sInfoLink != nil ? .detailButton : .none);
            cell = cellNews;
        }
        else if ds.m_eType == .events {
            let cellEvent = tableView.dequeueReusableCell(withIdentifier: "cellEvent", for: indexPath) as! EventCell
            cellEvent.m_lbTitle.text = rec.m_sTitle;
            cellEvent.m_lbText.text = rec.m_sText ?? "";
            var sDateText = "";
            if let aDate = rec.m_aDate {
                let df = DateFormatter();
                df.dateStyle = .full;
                df.timeStyle = .short;
                sDateText = df.string(from: aDate);
            }
            else {
                cellEvent.m_btnAddToCalendar.isHidden = true;
            }
            cellEvent.m_lbDate.text = sDateText
            cellEvent.m_btnWebsite.isHidden = (rec.m_sInfoLink==nil);
            cellEvent.m_btnBuy.isHidden = (rec.m_sBuyLink==nil);
            
            cellEvent.m_btnWebsite.tag = indexPath.row;
            cellEvent.m_btnBuy.tag = indexPath.row;
            cellEvent.m_btnAddToCalendar.tag = indexPath.row;
            cell = cellEvent;
        }
        else if ds.m_eType == .places {
            let cellPlace = tableView.dequeueReusableCell(withIdentifier: "cellPlace", for: indexPath) as! PlaceCell
            cellPlace.m_lbTitle.text = rec.m_sTitle;
            cellPlace.m_lbText.text = rec.m_sText ?? "";
            cell = cellPlace;
            self.tableView.allowsSelection = true;
        }
        else {
            cell = UITableViewCell();
        }
        
        cell.setNeedsUpdateConstraints();
        cell.updateConstraintsIfNeeded();
        return cell;
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let ds = m_aDataSource {
            let rec = ds.m_arrItems[indexPath.row];
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let placeCtl = storyboard.instantiateViewController(withIdentifier: "placeDetailCtl") as! PlaceDetailCtl
            placeCtl.m_aRecord = rec;
            navigationController?.pushViewController(placeCtl, animated: true);
        }
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if let ds = m_aDataSource {
            let rec = ds.m_arrItems[indexPath.row];
            rec.openInfoLink();
        }
    }
    
    @IBAction func onBtnWebsiteTouched(_ sender: Any) {
        if let ds = m_aDataSource,
            let btn = sender as? UIButton {
            let rec = ds.m_arrItems[btn.tag];
            rec.openInfoLink();
        }
    }
    
    @IBAction func onBtnBuyTouched(_ sender: Any) {
        if let ds = m_aDataSource,
            let btn = sender as? UIButton {
            let rec = ds.m_arrItems[btn.tag];
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
                self.present(alertController, animated: true, completion: nil)
            }
        })
    }
    
    func eventEditViewController(_ controller: EKEventEditViewController,
                                 didCompleteWith action: EKEventEditViewAction){
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onBtnCalendarTouched(_ sender: Any) {
        if let ds = m_aDataSource,
            let btn = sender as? UIButton {
            let rec = ds.m_arrItems[btn.tag];
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
            //m_bUserLocationAcquired = YES;
            
            // TODO: reorder items according to distance to user
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
