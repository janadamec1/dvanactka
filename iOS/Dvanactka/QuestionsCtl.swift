//
//  QuestionsCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 03/02/2020.
//  Copyright © 2020 Jan Adamec. All rights reserved.
//

import UIKit

class QuestionsCell: UITableViewCell {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
}

class QuestionsCtl: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var m_tableView: UITableView!
    @IBOutlet weak var m_viewFooter: UIView!
    @IBOutlet weak var m_segmLevel: UISegmentedControl!
    
    // input:
    var m_aDataSource: CRxDataSource?
    var m_aRecord: CRxEventRecord?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let rec = m_aRecord {
            self.title = rec.m_sTitle;
        }

        m_tableView.rowHeight = UITableView.automaticDimension;
        m_tableView.estimatedRowHeight = 90.0;

        m_tableView.reloadData();
    }

    //--------------------------------------------------------------------------
    // MARK: - Table view data source
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }

    //--------------------------------------------------------------------------
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let rec = m_aRecord, let qa = rec.m_arrQa {
            return qa.count;
        }
        return 0;
    }
    
    //--------------------------------------------------------------------------
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellQuestion", for: indexPath) as! QuestionsCell;
        if let rec = m_aRecord, let qa = rec.m_arrQa {
            cell.m_lbTitle.text = qa[indexPath.row].m_sQuestion;
            
            let sAnswer = qa[indexPath.row].m_sAnswer;
            
            var bTextSet = false;
            if sAnswer.hasPrefix("<dd") {
                var sTextColor = "#000000";
                if #available(iOS 13.0, *) {
                    if UITraitCollection.current.userInterfaceStyle == .dark {
                        sTextColor = "#FFFFFF";
                    }
                }
                let sHtmlText = String.init(format: "<style>div, dl, dd {font-family: '%@'; font-size:%fpx; color:%@;}</style>", cell.m_lbText.font.fontName, cell.m_lbText.font.pointSize, sTextColor) + sAnswer;
                if let htmlData = sHtmlText.data(using: String.Encoding.unicode) {
                    do {
                        let attributedText = try NSMutableAttributedString(data: htmlData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil);
                        cell.m_lbText.attributedText = attributedText;
                        bTextSet = true;
                    } catch let error as NSError {
                        print("Translating HTML text failed: \(error.localizedDescription)");
                    }
                }
            }
            if !bTextSet {
                cell.m_lbText.text = sAnswer;
            }
        }
        return cell;
    }
}

