/*
 Copyright 2016-2022 Jan Adamec.
 
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
    @IBOutlet weak var m_stackDebugUseTestFiles: UIStackView!
    @IBOutlet weak var m_chkDebugUseTestFiles: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // set navigation bar color, as in ViewController::viewDidLoad
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance();
            appearance.configureWithOpaqueBackground();
            appearance.backgroundColor = UIColor(red: 23.0/255.0, green: 37.0/255.0, blue: 96.0/255.0, alpha: 1.0);
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white];

            navigationController?.navigationBar.standardAppearance = appearance;
            navigationController?.navigationBar.scrollEdgeAppearance = appearance;
        }

        title = NSLocalizedString("About the App", comment: "");
        m_lbText.text = NSLocalizedString("AppInfo.longtext", comment: "");
        m_lbWifi.text = NSLocalizedString("Download new data only via WiFi", comment: "");

        if let email = CRxAppDefinition.shared.m_sContactEmail {
            m_btnContact.setTitle(email, for: .normal);
        }
        else {
            m_btnContact.isHidden = true;
        }
        if let copyright = CRxAppDefinition.shared.m_sCopyright {
            m_lbCopyright.text = copyright;
        }
        else {
            m_lbCopyright.isHidden = true;
        }

        m_chkWifi.isOn = UserDefaults.standard.bool(forKey: "wifiDataOnly");
        
        #if DEBUG
        m_chkDebugUseTestFiles.isOn = g_bUseTestFiles;
        #else
        m_stackDebugUseTestFiles.isHidden = true;
        #endif
    }

    //---------------------------------------------------------------------------
    @IBAction func onChkWifiChanged(_ sender: Any) {
        UserDefaults.standard.set(m_chkWifi.isOn, forKey: "wifiDataOnly");
        UserDefaults.standard.synchronize();
    }
    
    //---------------------------------------------------------------------------
    @IBAction func onChkUseTestFilesChanged(_ sender: Any) {
        if g_bUseTestFiles != m_chkDebugUseTestFiles.isOn {
            g_bUseTestFiles = m_chkDebugUseTestFiles.isOn;
            CRxDataSourceManager.shared.refreshAllDataSources(force: true, removeOldData:true);
        }
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
