//
//  RadniceAktualCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit

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
    
}
class PlaceCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    
}

class EventsCtl: UITableViewController {
    var m_aDataSource: CRxDataSource?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let ds = m_aDataSource {
            self.title = ds.m_sTitle;
            
            if (ds.m_bShowMap) {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Map", comment: ""), style: .plain, target: self, action: #selector(EventsCtl.showMap));
            }
        }
        
        self.tableView.rowHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedRowHeight = 90.0;
        
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        

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
        
        if ds.m_sId == CRxDataSourceManager.dsRadNews || ds.m_sId == CRxDataSourceManager.dsRadAlerts {
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
            cell = cellNews;
        }
        else if ds.m_sId == CRxDataSourceManager.dsRadEvents || ds.m_sId == CRxDataSourceManager.dsBiografProgram {
            let cellEvent = tableView.dequeueReusableCell(withIdentifier: "cellEvent", for: indexPath) as! EventCell
            cellEvent.m_lbTitle.text = rec.m_sTitle;
            cellEvent.m_lbText.text = rec.m_sText ?? "";
            var sDateText = "";
            if let aDate = rec.m_aDate {
                let df = DateFormatter();
                df.dateStyle = .full;
                df.timeStyle = .none;
                sDateText = df.string(from: aDate);
            }
            cellEvent.m_lbDate.text = sDateText
            cell = cellEvent;
        }
        else if ds.m_sId == CRxDataSourceManager.dsCooltour || ds.m_sId == CRxDataSourceManager.dsCoolTrees {
            let cellPlace = tableView.dequeueReusableCell(withIdentifier: "cellPlace", for: indexPath) as! PlaceCell
            cellPlace.m_lbTitle.text = rec.m_sTitle;
            cellPlace.m_lbText.text = rec.m_sText ?? "";
            cell = cellPlace;
        }
        else {
            cell = UITableViewCell();
        }
        
        cell.accessoryType = (rec.m_sInfoLink != nil ? .detailButton : .none);
        cell.setNeedsUpdateConstraints();
        cell.updateConstraintsIfNeeded();
        return cell;
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if let ds = m_aDataSource {
            let rec = ds.m_arrItems[indexPath.row];
            rec.openInfoLink();
        }
    }
    
    func showMap() {
        let mapCtl = MapCtl();
        mapCtl.m_aDataSource = m_aDataSource;
        navigationController?.pushViewController(mapCtl, animated: true);
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
