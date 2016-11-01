//
//  RadniceAktualCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit

class RadniceAktualCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_lbDate: UILabel!
    //@IBOutlet weak var m_lbCategory: UILabel!
    
}

class RadniceAktualCtl: UITableViewController {
    var m_aDataSource: CRxDataSource?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let ds = m_aDataSource {
            self.title = ds.m_sTitle;
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
        
        if let ds = m_aDataSource {

            let cell = tableView.dequeueReusableCell(withIdentifier: "radniceAktualCell", for: indexPath) as! RadniceAktualCell

            let rec: CRxEventRecord = ds.m_arrItems[indexPath.row];
            cell.m_lbTitle.text = rec.m_sTitle;
            cell.m_lbText.text = rec.m_sText ?? "";
            var sDateText = "";
            if let aDate = rec.m_aDate {
                let df = DateFormatter();
                df.dateStyle = .full;
                df.timeStyle = .none;
                sDateText = df.string(from: aDate);
            }
            cell.m_lbDate.text = sDateText
            //cell.m_lbCategory.text = rec.m_sCategory ?? ""
            
            if rec.m_sInfoLink != nil {
                cell.accessoryType = UITableViewCellAccessoryType.detailButton;
            }
            else {
                cell.accessoryType = UITableViewCellAccessoryType.none;
            }

            cell.setNeedsUpdateConstraints();
            cell.updateConstraintsIfNeeded();
            return cell;
        }
        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if let ds = m_aDataSource {
            let rec = ds.m_arrItems[indexPath.row];
            rec.openInfoLink();
        }
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
