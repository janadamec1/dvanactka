//
//  AppInfoCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 08.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MessageUI

class AppInfoCtl: UIViewController, MFMailComposeViewControllerDelegate {

    @IBOutlet weak var m_lbText: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("About the App", comment: "");
        m_lbText.text = NSLocalizedString("AppInfo.longtext", comment: "");
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onBtnDoneTouched(_ sender: Any) {
        dismiss(animated: true, completion: nil);
    }
    
    @IBAction func onBtnContactTouched(_ sender: Any) {
        if (MFMailComposeViewController.canSendMail())
        {
            let mailer = MFMailComposeViewController();
            mailer.mailComposeDelegate = self;
            
            mailer.setToRecipients(["info@roomarranger.com"]);
            mailer.setSubject("P12app (iOS)");
            mailer.modalPresentationStyle = .formSheet;
            present(mailer, animated: true, completion: nil);
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil);
    }
}
