//
//  RadniceAktualCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import Kanna

// XPath syntax: https://www.w3.org/TR/xpath/#path-abbrev

class RadniceAktualCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    //@IBOutlet weak var m_lbDate: UILabel!
    //@IBOutlet weak var m_lbCategory: UILabel!
    
}

class RadniceAktualCtl: UITableViewController {
    var m_items: [CRxEventRecord] = [CRxEventRecord]()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.rowHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedRowHeight = 50.0;
        
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        //let url = URL(string: "https://www.praha12.cz/")
        //if let doc = HTML(url: url!, encoding: .utf8) {
        
        if let path = Bundle.main.path(forResource: "/test_files/praha12titulka", ofType: "html") {
            let html = try! String(contentsOfFile: path, encoding: .utf8)
            if let doc = HTML(html: html, encoding: .utf8) {
                for node in doc.xpath("//div[@class='titulDoc aktClanky']//li"){
                    if let a_title = node.xpath("strong//a").first, let sTitle = a_title.text {
                        let aNewRecord = CRxEventRecord(title: sTitle.trimmingCharacters(in: .whitespacesAndNewlines))

                        if let sLink = a_title["href"] {
                            aNewRecord.m_sLink = sLink;
                        }
                        
                        if let aDateNode = node.xpath("span").first, let sDate = aDateNode.text {
                            let df = DateFormatter();
                            df.dateFormat = "(dd.MM.yyyy)";
                            if let date = df.date(from: sDate) {
                                aNewRecord.m_aDate = date;// as NSDate?
                            }
                        }
                        
                        if let aTextNode = node.xpath("div[1]").first {
                            aNewRecord.m_sText = aTextNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        if let aCategoriesNode = node.xpath("div[@class='ktg']//a").first {
                            aNewRecord.m_sCategory = aCategoriesNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        //dump(aNewRecord)
                        m_items.append(aNewRecord);
                    }
                }
                
            }
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return m_items.count;
    }

    //override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
   //     return UITableViewAutomaticDimension;
    //}
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "radniceAktualCell", for: indexPath) as! RadniceAktualCell

        let rec: CRxEventRecord = m_items[indexPath.row];
        cell.m_lbTitle.text = rec.m_sTitle;
        cell.m_lbText.text = rec.m_sText ?? "";
        var sDateText = "";
        if let aDate = rec.m_aDate {
            let df = DateFormatter();
            df.dateStyle = .short;
            df.timeStyle = .none;
            sDateText = df.string(from: aDate);
        }
        //cell.m_lbDate.text = sDateText
        //cell.m_lbCategory.text = rec.m_sCategory ?? ""
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        return cell;
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
