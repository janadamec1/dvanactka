//
//  PlaceDetailCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 03.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MessageUI

class PlaceDetailCtl: UIViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbCategory: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_lbAddressTitle: UILabel!
    @IBOutlet weak var m_lbAddress: UILabel!
    @IBOutlet weak var m_lbOpeningHoursTitle: UILabel!
    @IBOutlet weak var m_lbOpeningHours: UILabel!
    @IBOutlet weak var m_btnWebsite: UIButton!
    @IBOutlet weak var m_btnMap: UIButton!
    
    
    var m_aRecord: CRxEventRecord?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if let rec = m_aRecord {
            m_lbTitle.text = rec.m_sTitle;
            m_lbText.text = rec.m_sText;
            
            if let category = rec.m_eCategory {
                m_lbCategory.text = CRxEventRecord.categoryLocalName(category: category);
            }
            else {
                m_lbCategory.isHidden = true;
            }
            
            if let address = rec.m_sAddress {
                m_lbAddress.text = address;
            }
            else {
                m_lbAddressTitle.isHidden = true;
                m_lbAddress.isHidden = true;
            }
            
            if let hours = rec.m_arrOpeningHours {
                let df = DateFormatter();
                var sHours = ""
                for hourIt in hours {
                    let sWeekDay = df.shortWeekdaySymbols[hourIt.key-1]; //???
                    let hi = hourIt.value;
                    sHours += sWeekDay + ": \(hi.m_hourStart/100):\(hi.m_hourStart%100) - \(hi.m_hourEnd/100):\(hi.m_hourEnd%100)\n"
                }
                m_lbOpeningHours.text = sHours;
            }
            else {
                m_lbOpeningHoursTitle.isHidden = true;
                m_lbOpeningHours.isHidden = true;
            }
            
            m_btnWebsite.isHidden = (rec.m_sInfoLink == nil);
            m_btnMap.isHidden = (rec.m_aLocation == nil);
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func onBtnWebsiteTouched(_ sender: Any) {
        if let rec = m_aRecord {
            rec.openInfoLink();
        }
    }
    
    @IBAction func onBtnMapTouched(_ sender: Any) {
        if let rec = m_aRecord {
            let aMapItem = CRxMapItem(record: rec);
            aMapItem.mapItem().openInMaps(launchOptions: nil);
        }
    }
    
    @IBAction func onBtnReportIssueTouched(_ sender: Any) {
        if (MFMailComposeViewController.canSendMail())
        {
            guard let rec = m_aRecord
                else {return;}
            
            let mailer = MFMailComposeViewController();
            mailer.mailComposeDelegate = self;
            
            mailer.setToRecipients(["info@roomarranger.com"]);
            mailer.setSubject("\(rec.m_sTitle) - problem (iOS)");
            mailer.setMessageBody(NSLocalizedString("(Please describe problem here)", comment:"") , isHTML: false);
            mailer.modalPresentationStyle = .formSheet;
            present(mailer, animated: true, completion: nil);
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil);
    }
}
