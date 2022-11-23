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
import MapKit
import MessageUI
import UserNotifications

//NOTE: to get the stackview start at the top of scrollview, I had to switch OFF ViewController.adjustScrollViewInsets (even if it should be opposite)
// see http://fuckingscrollviewautolayout.com

class PlaceDetailCtl: UIViewController, MFMailComposeViewControllerDelegate, MKMapViewDelegate, CLLocationManagerDelegate {
    @IBOutlet weak var m_lbTitle: UILabel!
    @IBOutlet weak var m_lbCategory: UILabel!
    @IBOutlet weak var m_lbValidDates: UILabel!
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
    @IBOutlet weak var m_btnBuy: UIButton!
    @IBOutlet weak var m_btnPhoneMobile: UIButton!
    @IBOutlet weak var m_map: MKMapView!
    @IBOutlet weak var m_lbShowNotifications: UILabel!
    @IBOutlet weak var m_chkShowNotifications: UISwitch!
    @IBOutlet weak var m_lbNotificationExplanation: UILabel!
    @IBOutlet weak var m_lbContactNote: UILabel!
    @IBOutlet weak var m_btnNavigate: UIButton!
    @IBOutlet weak var m_btnReportMistake: UIButton!
    @IBOutlet weak var m_lbGame: UILabel!
    @IBOutlet weak var m_lbGameDist: UILabel!
    @IBOutlet weak var m_btnGameCheckIn: UIButton!
    
    var m_locManager = CLLocationManager();
    // input:
    var m_aDataSource: CRxDataSource?
    var m_aRecord: CRxEventRecord?
    
    var m_refreshParentDelegate: CRxDetailRefreshParentDelegate?
    
    enum EGameStatus {
    case disabled, tracking, visited
    }
    var m_eGameStatus: EGameStatus = .disabled;
    var m_bGameWrongTime: Bool = false;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Localizatation
        m_lbAddressTitle.text = NSLocalizedString("Address", comment: "");
        m_lbOpeningHoursTitle.text = NSLocalizedString("Opening Hours", comment: "");
        m_lbShowNotifications.text = NSLocalizedString("Show notifications", comment: "");
        m_lbNotificationExplanation.text = NSLocalizedString("Notification.explanation", comment: "");
        m_btnNavigate.setTitle(NSLocalizedString("Navigate", comment: ""), for: .normal);
        m_btnReportMistake.setTitle(NSLocalizedString("Report mistake", comment: ""), for: .normal);
        m_lbGame.text = NSLocalizedString("Game", comment: "")+":";
        m_btnGameCheckIn.setTitle(NSLocalizedString("I'm here!", comment: ""), for: .normal);
        
        if let rec = m_aRecord {
            m_lbTitle.text = rec.m_sTitle;
            
            var bTextSet = false;
            if rec.hasHtmlText() {
                var sTextColor = "#000000";
                if #available(iOS 13.0, *) {
                    if UITraitCollection.current.userInterfaceStyle == .dark {
                        sTextColor = "#FFFFFF";
                    }
                }
                let sHtmlText = String.init(format: "<style>div, dl {font-family: '%@'; font-size:%fpx; color:%@;}</style>", m_lbText.font.fontName, m_lbText.font.pointSize, sTextColor) + rec.m_sText!;
                if let htmlData = sHtmlText.data(using: String.Encoding.unicode) {
                    do {
                        let attributedText = try NSMutableAttributedString(data: htmlData, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil);
                        m_lbText.attributedText = attributedText;
                        bTextSet = true;
                    } catch let error as NSError {
                        print("Translating HTML text failed: \(error.localizedDescription)");
                    }
                }
            }
            if !bTextSet {
                m_lbText.text = rec.m_sText;
            }
            substituteRecordText();
            
            if let category = rec.m_eCategory {
                var sCat = CRxEventRecord.categoryLocalName(category: category);
                if let filter = rec.m_sFilter, filter != sCat {
                    sCat += " - " + filter;
                }
                m_lbCategory.text = sCat;
                
            }
            else {
                m_lbCategory.isHidden = true;
            }
            
            if let date = rec.m_aDate {
                if let dateTo = rec.m_aDateTo {
                    let aInterval = CRxEventInterval(start: date, end: dateTo, type: "");
                    m_lbValidDates.text = aInterval.toDisplayString();
                }
                else {
                    let df = DateFormatter();
                    df.dateStyle = .long;
                    df.timeStyle = .short;
                    m_lbValidDates.text = df.string(from: date);
                }
            }
            else {
                m_lbValidDates.isHidden = true;
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
                let sType = NSMutableAttributedString(string:"");
                let sHours = NSMutableAttributedString(string:"");
                var bHasVok = false;
                var bHasBio = false;
                let dayToday = Date();
                let aPastAttrs = [NSAttributedString.Key.foregroundColor: UIColor.lightGray];
                let sNewLine = NSAttributedString(string:"\n");

                for it in events {
                    if sHours.length > 0 {
                        sHours.append(sNewLine);
                        sType.append(sNewLine);
                    }
                    var aAttrs: [NSAttributedString.Key: Any]? = nil;
                    if (it.m_dateEnd < dayToday) {
                        aAttrs = aPastAttrs;
                    }
                    
                    sType.append(NSAttributedString(string:it.m_sType + ": ", attributes:aAttrs));
                    sHours.append(NSAttributedString(string:it.toDisplayString(), attributes:aAttrs));
                    
                    if it.m_sType == "obj. odpad" {
                        bHasVok = true;
                    }
                    else if it.m_sType == "bioodpad" || it.m_sType == "větve" {
                        bHasBio = true;
                    }
                }
                m_lbOpeningHoursTitle.text = NSLocalizedString("Timetable", comment: "")
                m_lbOpeningHours.attributedText = sType;
                m_lbOpeningHours2.attributedText = sHours;
                
                if bHasVok || bHasBio {
                    var sNote = "";
                    if bHasVok { sNote = NSLocalizedString("Waste.vok.longdesc", comment: ""); }
                    //if bHasVok && bHasBio { sNote += "\n"; }
                    //if bHasBio { sNote += NSLocalizedString("Waste.bio.longdesc", comment: ""); }
                    m_lbNote.text = sNote;
                    m_lbNote.isHidden = false;
                }
                if let ds = m_aDataSource, ds.m_bLocalNotificationsForEvents {
                    m_lbShowNotifications.isHidden = false;
                    m_chkShowNotifications.isHidden = false;
                    m_lbNotificationExplanation.isHidden = false;
                    m_chkShowNotifications.isOn = rec.m_bMarkFavorite;
                }
            }
            else {
                m_lbOpeningHoursTitle.isHidden = true;
                m_lbOpeningHours.isHidden = true;
                m_lbOpeningHours2.isHidden = true;
            }
            
            if let category = rec.m_eCategory {
                if category == CRxCategory.wasteTextile.rawValue {
                    m_lbNote.text = NSLocalizedString("Waste.textile.longdesc", comment: "");
                    m_lbNote.isHidden = false;
                } else if category == CRxCategory.wasteElectro.rawValue {
                    m_lbNote.text = NSLocalizedString("Waste.electro.longdesc", comment: "");
                    m_lbNote.isHidden = false;
                }
            }

            if let link = rec.m_sInfoLink?.removingPercentEncoding {
                m_btnWebsite.setTitle(link, for: UIControl.State.normal)
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
                m_btnEmail.setTitle(email, for: UIControl.State.normal)
            }
            else {
                m_btnEmail.isHidden = true;
            }
            if let phone = rec.m_sPhoneNumber {
                m_btnPhone.setTitle(phone, for: UIControl.State.normal)
            }
            else {
                m_btnPhone.isHidden = true;
            }
            if let phone = rec.m_sPhoneMobileNumber {
                m_btnPhoneMobile.setTitle(phone, for: UIControl.State.normal)
            }
            else {
                m_btnPhoneMobile.isHidden = true;
            }
            if rec.m_sBuyLink != nil && rec.m_sFilter != nil && rec.m_sFilter! == "Restaurace" {
                m_btnBuy.setTitle(NSLocalizedString("Lunch menu", comment:""), for: .normal);
            }
            else {
                m_btnBuy.isHidden = true;
            }
            
            if let location = rec.m_aLocation {
                let regView = MKCoordinateRegion.init(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500);
                m_map.setRegion(regView, animated:false);
                m_map.addAnnotation(CRxMapItem(record: rec));
                m_map.delegate = self;
                
                if CLLocationManager.locationServicesEnabled() && CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
                    m_map.showsUserLocation = true;
                }
                
                if rec.m_aLocCheckIn != nil {
                    m_map.addAnnotation(CRxMapItem(record: rec, forCheckIn: true));
                }
            }
            else {
                m_map.isHidden = true;
                m_btnNavigate.isHidden = true;
            }
            
            if rec.m_aLocation != nil && CRxGame.isCategoryCheckInAble(rec.m_eCategory)
                && CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
                
                if CRxGame.shared.playerWas(at: rec) {
                    m_eGameStatus = .visited;
                    m_lbGameDist.text = NSLocalizedString("You were already here", comment: "");
                    m_btnGameCheckIn.isHidden = true;
                }
                else {
                    // init tracking
                    if rec.m_arrEvents != nil && rec.currentEvent() == nil {    // checkin at VOK location is also limited to time
                        m_bGameWrongTime = true;
                    }
                    m_eGameStatus = .tracking;
                    m_lbGameDist.text = "N/A";
                    m_btnGameCheckIn.isEnabled = false;
                    
                    m_locManager.delegate = self;
                    m_locManager.distanceFilter = 4;
                    m_locManager.startUpdatingLocation();
                }
            }
            else {
                m_lbGame.isHidden = true;
                m_lbGameDist.isHidden = true;
                m_btnGameCheckIn.isHidden = true;
            }
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onChkNotificationsChanged(_ sender: Any) {
        if let rec = m_aRecord {
            rec.m_bMarkFavorite = m_chkShowNotifications.isOn;
            CRxDataSourceManager.shared.setFavorite(place: rec.m_sTitle, set: rec.m_bMarkFavorite);
            m_refreshParentDelegate?.detailRequestsRefresh(); // change star icon, resort
            
            let aNotificationCenter = UNUserNotificationCenter.current()
            aNotificationCenter.delegate = UIApplication.shared.delegate as! AppDelegate;
            let notTypes: UNAuthorizationOptions = [.alert, .sound, .badge/*, .provisional*/];
            aNotificationCenter.requestAuthorization(options: notTypes) { (granted, error) in
                if !granted { print("Not granted") }
            }
        }
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnWebsiteTouched(_ sender: Any) {
        if let rec = m_aRecord {
            rec.openInfoLink(fromCtl: self);
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnMapTouched(_ sender: Any) {
        if let rec = m_aRecord {
            let aMapItem = CRxMapItem(record: rec, forCheckIn: true);
            aMapItem.mapItem().openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]);
        }
    }
    
    //--------------------------------------------------------------------------
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? CRxMapItem {
            var identifier = "pin"
            if !annotation.m_bForCheckIn {
                if let category = annotation.m_rec.m_eCategory {
                    identifier = category; // for reusing
                }
            }
            
            var view: MKAnnotationView
            if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) {
                dequeuedView.annotation = annotation
                view = dequeuedView
            }
            else if annotation.m_bForCheckIn {
                let pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                pin.pinTintColor = MKPinAnnotationView.purplePinColor();
                view = pin;
                view.calloutOffset = CGPoint(x: -5, y: 5)
            }
            else {
                var aIcon: UIImage?;
                if let category = annotation.m_rec.m_eCategory {
                    aIcon = UIImage(named: CRxEventRecord.categoryIconName(category: category));
                }
                if let icon = aIcon {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier);
                    view.image = icon;
                }
                else {
                    view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier);
                    view.calloutOffset = CGPoint(x: -5, y: 5);
                }
            }
            view.canShowCallout = false
            return view
        }
        return nil
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnEmailTouched(_ sender: Any) {
        guard let rec = m_aRecord,
            let email = rec.m_sEmail
            else {return;}
        
        let mailer = MFMailComposeViewController();
        if mailer == nil { return; }
        mailer.mailComposeDelegate = self;
        
        mailer.setToRecipients(["\(email)"]);
        
        if let catStr = rec.m_eCategory,
            let category = CRxCategory(rawValue: catStr) {
            if category == .wasteTextile || category == .waste || category == .wasteElectro {
                var sMunicipality = "";
                if let city = CRxAppDefinition.shared.m_sMunicipality {
                    sMunicipality = city;
                }
                mailer.setSubject(rec.m_sTitle + ", " + sMunicipality + " - " + CRxEventRecord.categoryLocalName(category: rec.m_eCategory));
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
            UIApplication.shared.open(url);
        }
    }
    
    //--------------------------------------------------------------------------
    @IBAction func onBtnPhoneMobileTouched(_ sender: Any) {
        guard let rec = m_aRecord,
            let phone = rec.m_sPhoneMobileNumber
            else {return;}
        
        let cleanedNumber = phone.replacingOccurrences(of: " ", with: "")
        
        if let url = URL(string: "telprompt://\(cleanedNumber)") {
            UIApplication.shared.open(url);
        }
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnBuyTouched(_ sender: Any) {
        guard let rec = m_aRecord
            else {return;}
        rec.openBuyLink(fromCtl: self);
    }

    //--------------------------------------------------------------------------
    @IBAction func onBtnReportIssueTouched(_ sender: Any) {
        if (MFMailComposeViewController.canSendMail())
        {
            guard let rec = m_aRecord
                else { return; }
            
            guard let email = CRxAppDefinition.shared.recordUpdateEmail()
                else { return; }
            
            let mailer = MFMailComposeViewController();
            if mailer == nil { return; }
            mailer.mailComposeDelegate = self;
            
            mailer.setToRecipients([email]);
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
    @IBAction func onBtnGameCheckIn(_ sender: Any) {
        guard let rec = m_aRecord
            else {return;}
        let reward = CRxGame.shared.checkIn(at: rec);
        m_eGameStatus = .visited;
        m_btnGameCheckIn.isHidden = true;
        if let reward = reward {
            var sReward = "+\(reward.points) XP";
            var sAlertMessage = sReward;
            if reward.newStars > 0 && reward.catName != nil {
                let sStars = String(repeating: "⭐️", count: reward.newStars);
                sReward += ", \(reward.catName!): \(sStars)";
                sAlertMessage += "\n\(reward.catName!): \(sStars)";
            }
            if reward.newLevel > 0 {
                sReward += ", " + NSLocalizedString("Level up!", comment: "");
                sAlertMessage = "\n" + NSLocalizedString("Level up!", comment: "") + "\n"
                    + NSLocalizedString("You are now at level", comment: "") + " \(reward.newLevel)\n"
                    + sAlertMessage;
            }
            m_lbGameDist.text = sReward;

            let alertController = UIAlertController(title: nil,
                                                    message: sAlertMessage, preferredStyle: .alert);
            let actionOK = UIAlertAction(title: "OK", style: .default, handler: { (result : UIAlertAction) -> Void in
                print("OK")})
            alertController.addAction(actionOK);
            self.present(alertController, animated: true, completion: nil);
            // TODO: animation, big applause
        }
    }
    
    //---------------------------------------------------------------------------
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if m_eGameStatus != .tracking { return }
        guard let rec = m_aRecord
            else {return;}

        if let locUser = locations.last,
            let locRec = rec.gameCheckInLocation() {
            let aDistance = locUser.distance(from: locRec);
            var sText = "\(Int(aDistance)) m";
            if aDistance > CRxGame.checkInDistance {
                if m_bGameWrongTime {
                    sText += " - " + NSLocalizedString("too far & wrong time", comment: "");
                }
                else {
                    sText += " - " + NSLocalizedString("you are too far", comment: "");
                }
            }
            else if m_bGameWrongTime {
                sText += " - " + NSLocalizedString("wrong time", comment: "");
            }
            m_lbGameDist.text = sText;
            
            m_btnGameCheckIn.isEnabled = (aDistance <= CRxGame.checkInDistance && !m_bGameWrongTime);
        }
    }

    //--------------------------------------------------------------------------
    func substituteRecordText() {
        guard let rec = m_aRecord, let text = rec.m_sText
            else {return;}
        if text == "FAQ" {
            let aQuestionAttr = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: m_lbText.font.pointSize+1)];
            let sNewText = NSMutableAttributedString(string:"Kde se nechat vyfotit na průkazovou fotografii?", attributes: aQuestionAttr);
            sNewText.append(NSAttributedString(string:"\nVe Fotolabu na Sofijském náměstí.\n\n"));
            
            sNewText.append(NSAttributedString(string:"Obtížné parkování před poliklinikou?", attributes: aQuestionAttr))
            sNewText.append(NSAttributedString(string:"\nVolná místa najdete na parkovišti dostupném z ulice Povodňová, od kterého pak projdete pěšky ulicí Amortova. Při parkování přímo před vchodem do polikliniky musíte navíc použít parkovací hodiny.\n\n"));
            m_lbText.attributedText = sNewText;
        }
    }
}
