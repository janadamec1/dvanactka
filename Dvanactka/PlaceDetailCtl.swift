//
//  PlaceDetailCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 03.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit
import MessageUI
import UserNotifications

//NOTE: to get the stackview start at the top of scrollview, I had to switch OFF ViewController.adjustScrollViewInsets (even if it should be opposite)
// see http://fuckingscrollviewautolayout.com

class PlaceDetailCtl: UIViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbCategory: UILabel!
    @IBOutlet weak var m_lbText: UILabel!
    @IBOutlet weak var m_lbAddressTitle: UILabel!
    @IBOutlet weak var m_lbAddress: UILabel!
    @IBOutlet weak var m_lbOpeningHoursTitle: UILabel!
    @IBOutlet weak var m_lbOpeningHours: UILabel!
    @IBOutlet weak var m_lbOpeningHours2: UILabel!
    @IBOutlet weak var m_lbNote: UILabel!
    @IBOutlet weak var m_btnWebsite: UIButton!
    @IBOutlet weak var m_btnEmail: UIButton!
    @IBOutlet weak var m_btnPhone: UIButton!
    @IBOutlet weak var m_btnMap: UIButton!
    @IBOutlet weak var m_map: MKMapView!
    @IBOutlet weak var m_lbShowNotifications: UILabel!
    @IBOutlet weak var m_chkShowNotifications: UISwitch!
    @IBOutlet weak var m_lbNotificationExplanation: UILabel!
    @IBOutlet weak var m_lbContactNote: UILabel!
    @IBOutlet weak var m_btnNavigate: UIButton!
    @IBOutlet weak var m_btnReportMistake: UIButton!
    
    
    var m_aRecord: CRxEventRecord?
    var m_refreshParentDelegate: CRxDetailRefershParentDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Localizatation
        m_lbAddressTitle.text = NSLocalizedString("Address", comment: "");
        m_lbOpeningHoursTitle.text = NSLocalizedString("Opening Hours", comment: "");
        m_lbShowNotifications.text = NSLocalizedString("Show notifications", comment: "");
        m_lbNotificationExplanation.text = NSLocalizedString("Notification.explanation", comment: "");
        m_btnNavigate.setTitle(NSLocalizedString("Navigate", comment: ""), for: .normal);
        m_btnReportMistake.setTitle(NSLocalizedString("Report mistake", comment: ""), for: .normal);
        
        if let rec = m_aRecord {
            m_lbTitle.text = rec.m_sTitle;
            m_lbText.text = rec.m_sText;
            substituteRecordText();
            
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
            m_lbNote.isHidden = true;
            m_lbShowNotifications.isHidden = true;
            m_chkShowNotifications.isHidden = true;
            m_lbNotificationExplanation.isHidden = true;

            if let hours = rec.m_arrOpeningHours {
                let df = DateFormatter();
                var sDays = "";
                var sHours = "";
                var iLastDay = 0;
                for it in hours {
                    let sWeekDay = df.shortWeekdaySymbols[it.m_weekday % 7];
                    let sRange = " " + it.toIntervalDisplayString();
                    if iLastDay == it.m_weekday {
                        sHours += sRange    // another interval within same day
                    }
                    else {
                        if !sHours.isEmpty {
                            sHours += "\n"
                            sDays += "\n"
                        }
                        sDays += "\(sWeekDay): ";
                        sHours += sRange;
                        iLastDay = it.m_weekday
                    }
                }
                m_lbOpeningHours.text = sDays;
                m_lbOpeningHours2.text = sHours;
            }
            else if let events = rec.m_arrEvents {
                var sType = "";
                var sHours = "";
                var bHasVok = false;
                var bHasBio = false;
                for it in events {
                    if !sHours.isEmpty {
                        sHours += "\n"
                        sType += "\n"
                    }
                    sType += it.m_sType + ": ";
                    sHours += it.toDisplayString();
                    
                    if it.m_sType == "obj. odpad" {
                        bHasVok = true;
                    }
                    else if it.m_sType == "bioodpad" || it.m_sType == "větve" {
                        bHasBio = true;
                    }
                    
                }
                m_lbOpeningHoursTitle.text = NSLocalizedString("Timetable", comment: "")
                m_lbOpeningHours.text = sType;
                m_lbOpeningHours2.text = sHours;
                
                if bHasVok || bHasBio {
                    var sNote = "";
                    if bHasVok { sNote = NSLocalizedString("Waste.vok.longdesc", comment: ""); }
                    //if bHasVok && bHasBio { sNote += "\n"; }
                    //if bHasBio { sNote += NSLocalizedString("Waste.bio.longdesc", comment: ""); }
                    m_lbNote.text = sNote;
                    m_lbNote.isHidden = false;
                }
                m_lbShowNotifications.isHidden = false;
                m_chkShowNotifications.isHidden = false;
                m_lbNotificationExplanation.isHidden = false;
                m_chkShowNotifications.isOn = rec.m_bMarkFavorite;
            }
            else {
                m_lbOpeningHoursTitle.isHidden = true;
                m_lbOpeningHours.isHidden = true;
                m_lbOpeningHours2.isHidden = true;
            }
            
            if let category = rec.m_eCategory {
                if category == .wasteTextile {
                    m_lbNote.text = NSLocalizedString("Waste.textile.longdesc", comment: "");
                    m_lbNote.isHidden = false;
                } else if category == .wasteElectro {
                    m_lbNote.text = NSLocalizedString("Waste.electro.longdesc", comment: "");
                    m_lbNote.isHidden = false;
                }
            }

            if let link = rec.m_sInfoLink?.removingPercentEncoding {
                m_btnWebsite.setTitle(link, for: UIControlState.normal)
            }
            else {
                m_btnWebsite.isHidden = true;
            }
            if let contactNote = rec.m_sContactNote {
                m_lbContactNote.text = contactNote;
            }
            else {
                m_lbContactNote.isHidden = true;
            }
            if let email = rec.m_sEmail {
                m_btnEmail.setTitle(email, for: UIControlState.normal)
            }
            else {
                m_btnEmail.isHidden = true;
            }
            if let phone = rec.m_sPhoneNumber {
                m_btnPhone.setTitle(phone, for: UIControlState.normal)
            }
            else {
                m_btnPhone.isHidden = true;
            }
            
            if let location = rec.m_aLocation {
                let regView = MKCoordinateRegionMakeWithDistance(location.coordinate, 500, 500);
                m_map.setRegion(regView, animated:true);
                m_map.addAnnotation(CRxMapItem(record: rec));
            }
            else {
                m_map.isHidden = true;
                m_btnMap.isHidden = true;
            }
        }
    }

    //--------------------------------------------------------------------------
    @IBAction func onChkNotificationsChanged(_ sender: Any) {
        if let rec = m_aRecord {
            rec.m_bMarkFavorite = m_chkShowNotifications.isOn;
            CRxDataSourceManager.sharedInstance.setFavorite(place: rec.m_sTitle, set: rec.m_bMarkFavorite);
            m_refreshParentDelegate?.detailRequestsRefresh(); // change star icon, resort
            
            let notTypes: UIUserNotificationType = ([.alert, .sound, .badge])
            let notSettings = UIUserNotificationSettings(types:notTypes, categories:nil);
            UIApplication.shared.registerUserNotificationSettings(notSettings);
        }
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnWebsiteTouched(_ sender: Any) {
        if let rec = m_aRecord {
            rec.openInfoLink();
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnMapTouched(_ sender: Any) {
        if let rec = m_aRecord {
            let aMapItem = CRxMapItem(record: rec);
            aMapItem.mapItem().openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]);
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnEmailTouched(_ sender: Any) {
        guard let rec = m_aRecord,
            let email = rec.m_sEmail
            else {return;}
        
        let mailer = MFMailComposeViewController();
        mailer.mailComposeDelegate = self;
        
        mailer.setToRecipients(["\(email)"]);
        
        if let category = rec.m_eCategory {
            if category == .wasteTextile || category == .waste || category == .wasteElectro {
                mailer.setSubject(rec.m_sTitle + ", Praha 12 - " + CRxEventRecord.categoryLocalName(category: category));
                mailer.setMessageBody(NSLocalizedString("(Please describe problem here)", comment:"") , isHTML: false);
            }
        }
        
        mailer.modalPresentationStyle = .formSheet;
        present(mailer, animated: true, completion: nil);
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnPhoneTouched(_ sender: Any) {
        guard let rec = m_aRecord,
            let phone = rec.m_sPhoneNumber
            else {return;}
        
        let cleanedNumber = phone.replacingOccurrences(of: " ", with: "")
        
        if let url = URL(string: "telprompt://\(cleanedNumber)") {
            UIApplication.shared.openURL(url);
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnReportIssueTouched(_ sender: Any) {
        if (MFMailComposeViewController.canSendMail())
        {
            guard let rec = m_aRecord
                else {return;}
            
            let mailer = MFMailComposeViewController();
            mailer.mailComposeDelegate = self;
            
            mailer.setToRecipients(["info@roomarranger.com"]);
            mailer.setSubject(rec.m_sTitle + " - " + CRxEventRecord.categoryLocalName(category: rec.m_eCategory) + " - problem (iOS)");
            mailer.setMessageBody(NSLocalizedString("(Please describe problem here)", comment:"") , isHTML: false);
            mailer.modalPresentationStyle = .formSheet;
            present(mailer, animated: true, completion: nil);
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil);
    }
    
    //--------------------------------------------------------------------------
    func substituteRecordText() {
        guard let rec = m_aRecord, let text = rec.m_sText
            else {return;}
        if text == "FAQ" {
            let aQuestionAttr = [NSFontAttributeName: UIFont.boldSystemFont(ofSize: m_lbText.font.pointSize+1)];
            let sNewText = NSMutableAttributedString(string:"Kde se nechat vyfotit na průkazovou fotografii?", attributes: aQuestionAttr);
            sNewText.append(NSAttributedString(string:"\nVe Fotolabu na Sofijském náměstí.\n\n"));
            
            sNewText.append(NSAttributedString(string:"Obtížné parkování před poliklinikou?", attributes: aQuestionAttr))
            sNewText.append(NSAttributedString(string:"\nVolná místa najdete na parkovišti dostupném z ulice Povodňová, od kterého pak projdete pěšky ulicí Amortova. Při parkování přímo před vchodem do polikliniky musíte navíc použít parkovací hodiny.\n\n"));
            m_lbText.attributedText = sNewText;
        }
    }
}
