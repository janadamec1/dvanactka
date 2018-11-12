/*
 Copyright 2016-2018 Jan Adamec.
 
 This file is part of "Dvanactka".
 
 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.
 
 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
 */

import UIKit
import MessageUI

class AppInfoCtl: UIViewController, MFMailComposeViewControllerDelegate {

    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_lbWifi: UILabel!
    @IBOutlet weak var m_chkWifi: UISwitch!
    @IBOutlet weak var m_btnContact: UIButton!
    @IBOutlet weak var m_lbCopyright: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("About the App", comment: "");
        m_lbText.text = NSLocalizedString("AppInfo.longtext", comment: "");
        m_lbWifi.text = NSLocalizedString("Download new data only via WiFi", comment: "");

        if let email = CRxAppDefinition.shared.m_sContactEmail {
            m_btnContact.setTitle(email, for: .normal);
        }
        else {
            m_btnContact.isHidden = true;
        }
        
        m_chkWifi.isOn = UserDefaults.standard.bool(forKey: "wifiDataOnly");
    }

    //---------------------------------------------------------------------------
    @IBAction func onChkWifiChanged(_ sender: Any) {
        UserDefaults.standard.set(m_chkWifi.isOn, forKey: "wifiDataOnly");
        UserDefaults.standard.synchronize();
    }
    
    //---------------------------------------------------------------------------
    @IBAction func onBtnDoneTouched(_ sender: Any) {
        dismiss(animated: true, completion: nil);
    }
    
    //---------------------------------------------------------------------------
    @IBAction func onBtnContactTouched(_ sender: Any) {
        if (MFMailComposeViewController.canSendMail())
        {
            guard let email = CRxAppDefinition.shared.m_sContactEmail
                else { return; }

            let mailer = MFMailComposeViewController();
            if mailer == nil { return; }
            mailer.mailComposeDelegate = self;
            
            mailer.setToRecipients([email]);

            var sAppName = "CityApp";
            if let appTitle = CRxAppDefinition.shared.m_sTitle {
                sAppName = appTitle;
            }
            mailer.setSubject("Aplikace " + sAppName + " (iOS)");
            
            mailer.modalPresentationStyle = .formSheet;
            present(mailer, animated: true, completion: nil);
        }
    }
    
    //---------------------------------------------------------------------------
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil);
    }
}
