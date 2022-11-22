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
import Contacts     // for formatting address

class ReportFaultCtl: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, CLLocationManagerDelegate, UITextViewDelegate, MFMailComposeViewControllerDelegate, CRxRefineLocDelegate {
    @IBOutlet weak var m_lbHint: UILabel!
    @IBOutlet weak var m_lbAbout: UILabel!
    @IBOutlet weak var m_lbPhoto: UILabel!
    @IBOutlet weak var m_btnPhoto: UIButton!
    @IBOutlet weak var m_lbDescription: UILabel!
    @IBOutlet weak var m_edDescription: UITextView!
    @IBOutlet weak var m_lbLocationTitle: UILabel!
    @IBOutlet weak var m_lbLocation: UILabel!
    @IBOutlet weak var m_btnRefineLocation: UIButton!
    
    @IBOutlet weak var m_scrollView: UIScrollView!
    @IBOutlet weak var m_keyboardHeightLayoutConstraint: NSLayoutConstraint!
    
    var m_bImageSelected: Bool = false;
    var m_bImageOmitted: Bool = false;
    var m_locManager = CLLocationManager();
    var m_location: CLLocation?
    var m_bLocationRefined: Bool = false;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Localization
        //self.title = NSLocalizedString("Report Fault", comment: "");
        m_lbHint.text = NSLocalizedString("Report illegal dump, fault, problem", comment: "");
        m_lbAbout.text = NSLocalizedString("This form will help you compose the e-mail for the municipality.", comment: "");
        m_lbPhoto.text = NSLocalizedString("Photo", comment: "") + " (" + NSLocalizedString("recommended", comment: "") + ")";
        m_lbDescription.text = NSLocalizedString("Description", comment: "");
        m_lbLocationTitle.text = NSLocalizedString("Location", comment: "");
        m_btnRefineLocation.setTitle(NSLocalizedString("Refine", comment: ""), for: .normal);
        
        m_edDescription.delegate = self;

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "E-mail"/*NSLocalizedString("Send", comment: "")*/, style: .plain, target: self, action: #selector(ReportFaultCtl.onBtnSend));
        
        m_locManager.delegate = self;
        m_locManager.distanceFilter = 4;
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            m_locManager.startUpdatingLocation();
        }
        // for scrolling the vew when keyboard showing / hiding
        NotificationCenter.default.addObserver(self, selector: #selector(ReportFaultCtl.keyboardNotification(notification:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil);
    }
    
    //---------------------------------------------------------------------------
    deinit {
        NotificationCenter.default.removeObserver(self);
    }
    
    //---------------------------------------------------------------------------
    func showError(message: String, setFocusTo: UITextView? = nil) {
        let alertController = UIAlertController(title: message, message: nil, preferredStyle: .alert);
        let actionOK = UIAlertAction(title: "OK", style: .default) { result in
            if let edit = setFocusTo {
                edit.becomeFirstResponder();
            }
        }
        alertController.addAction(actionOK);
        present(alertController, animated: true, completion: nil);
    }
    
    //---------------------------------------------------------------------------
    @objc func keyboardNotification(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let duration:TimeInterval = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
            let animationCurve:UIView.AnimationOptions = UIView.AnimationOptions(rawValue: animationCurveRaw)
            let iKeyboardSize = endFrame?.size.height ?? 0.0;
            let bHiding = ((endFrame?.origin.y)! >= UIScreen.main.bounds.size.height);
            if bHiding {
                m_keyboardHeightLayoutConstraint?.constant = 0.0;
            } else {
                m_keyboardHeightLayoutConstraint?.constant = iKeyboardSize
            }
            // scroll
            if !bHiding {
                var aSelField: UIView?
                if m_edDescription.isFirstResponder {
                    aSelField = m_edDescription;
                }
                // test if active text input is under keyboard
                if let textField = aSelField {
                    var viewRect = view.bounds
                    viewRect.size.height -= iKeyboardSize;
                    let p = m_scrollView.convert(textField.center, to: self.view);
                    if !viewRect.contains(p) {
                        // scroll the view to have textField.bottom just above the keyboard
                        var scrollPoint = CGPoint(x: 0, y: textField.frame.origin.y+textField.frame.height - iKeyboardSize);
                        if scrollPoint.y < 0.0 {
                            scrollPoint.y = 0.0;
                        }
                        m_scrollView.setContentOffset(scrollPoint, animated: true);
                    }
                }
            }
            UIView.animate(withDuration: duration,
                           delay: TimeInterval(0),
                           options: animationCurve,
                           animations: { self.view.layoutIfNeeded() },
                           completion: nil)
        }
    }
    
    //---------------------------------------------------------------------------
    @objc func onBtnSend() {
        let sDesc = m_edDescription.text;
        if sDesc == nil || sDesc!.isEmpty {
            showError(message: NSLocalizedString("Please fill the description.", comment:""), setFocusTo: m_edDescription);
            return;
        }
        if m_location == nil {
            showError(message: NSLocalizedString("Please specify the location.", comment:""));
            return;
        }
        if !m_bImageSelected && !m_bImageOmitted {
            let alertController = UIAlertController(title: NSLocalizedString("Adding a photo is recommended. Are you sure to omit it?", comment:""), message: nil, preferredStyle: .alert);
            let actionYes = UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default) { result in
                self.m_bImageOmitted = true;
                self.onBtnSend();
            }
            let actionNo = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel);
            alertController.addAction(actionYes);
            alertController.addAction(actionNo);
            present(alertController, animated: true, completion: nil);
            return;
        }
        var sMessageBody = sDesc!;
        if let sAddress = m_lbLocation.text {
            sMessageBody += "\n\n" + sAddress;
        }
        if let loc = m_location {
            // send location as this link: https://mapy.cz/zakladni?x=14.4185889&y=50.0018275&z=17&source=coor&id=14.4185889%2C50.0020275
            let sMapLink = String(format: "https://mapy.cz/zakladni?x=%.8f&y=%.8f&z=17&source=coor&id=%.8f%%2C%.8f", arguments:[loc.coordinate.longitude, loc.coordinate.latitude, loc.coordinate.longitude, loc.coordinate.latitude]);
            sMessageBody += "\n" + sMapLink;
        }
        sMessageBody += "\n\n";
        
        guard let email = CRxAppDefinition.shared.m_sReportFaultEmail
            else { return; }
        
        let mailer = MFMailComposeViewController();
        if mailer == nil { return; }
        mailer.mailComposeDelegate = self;
        
        mailer.setToRecipients([email]);
        if let emailCc = CRxAppDefinition.shared.m_sReportFaultEmailCc {
            mailer.setCcRecipients([emailCc]);
        }
        mailer.setSubject("Hlášení závady");
        mailer.setMessageBody(sMessageBody, isHTML: false);
        
        if m_bImageSelected, let image = m_btnPhoto.image(for: .normal) {
            // down-scale image
            let oldSize = image.size;
            var newSize: CGSize;
            if oldSize.width > oldSize.height {
                newSize = CGSize(width: 1600, height: 1600*oldSize.height/oldSize.width);
            }
            else {
                newSize = CGSize(width: 1600*oldSize.width/oldSize.height, height: 1600);
            }
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
            image.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: newSize.width, height: newSize.height)))
            let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            
            // encode in JPEG and add attachment
            if let imageData = newImage.jpegData(compressionQuality: 0.8){
                mailer.addAttachmentData(imageData, mimeType: "image/jpeg", fileName: "photo.jpg")
            }
        }

        mailer.modalPresentationStyle = .formSheet;
        present(mailer, animated: true, completion: nil);
    }

    //---------------------------------------------------------------------------
    @IBAction func onBtnPhotoTouched(_ sender: Any) {
        let alertController = UIAlertController(title: NSLocalizedString("Select Photo", comment:""),
                                                message: nil, preferredStyle: .actionSheet);
        let actionPhoto = UIAlertAction(title: NSLocalizedString("Take a photo", comment:""), style: .default) { result in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .camera;
                imagePicker.allowsEditing = false
                self.present(imagePicker, animated: true, completion: nil)
            }
        }
        let actionGallery = UIAlertAction(title: NSLocalizedString("From gallery", comment:""), style: .default) { result in
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .photoLibrary;
                imagePicker.allowsEditing = false
                self.present(imagePicker, animated: true, completion: nil)
            }
        }
        let actionCancel = UIAlertAction(title: NSLocalizedString("Cancel", comment:""), style: .cancel) { result in }
        alertController.addAction(actionPhoto);
        alertController.addAction(actionGallery);
        alertController.addAction(actionCancel);
        alertController.popoverPresentationController?.sourceView = m_btnPhoto;
        alertController.popoverPresentationController?.sourceRect = m_btnPhoto.bounds;
        present(alertController, animated: true, completion: nil);
    }

    //---------------------------------------------------------------------------
    // MARK: - UIImagePickerControllerDelegate (taking a photo)
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
               m_btnPhoto.contentHorizontalAlignment = .fill
               m_btnPhoto.contentVerticalAlignment = .fill
               m_btnPhoto.imageView?.contentMode = .scaleAspectFit;
               
               m_btnPhoto.setImage(image, for: .normal);
               m_bImageSelected = true;
           }
        
        picker.dismiss(animated: true, completion: nil);
    }
    
    //---------------------------------------------------------------------------
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if m_bLocationRefined { return; }
        if let loc = locations.last {
            displayLocation(loc);
            decodeAddressFrom(location: loc);
        }
    }
    
    //---------------------------------------------------------------------------
    func decodeAddressFrom(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let arrPlacemarks = placemarks,
                let placemark = arrPlacemarks.first {

                var sAddress = "";
                if let address = placemark.postalAddress {
                    let pf = CNPostalAddressFormatter();
                    sAddress = pf.string(from: address);
                }
                self.displayLocation(location, address: sAddress);
            }
        }
    }
    
    //---------------------------------------------------------------------------
    func displayLocation(_ loc: CLLocation, address: String? = nil) {
        m_location = loc;
        var sLocation = String(format: "GPS: %.8gN, %.8gE", arguments: [loc.coordinate.latitude, loc.coordinate.longitude]);
        if let sAddress = address {
            sLocation += "\n" + sAddress;
        }
        self.m_lbLocation.text = sLocation;
    }
    
    //---------------------------------------------------------------------------
    // MARK: - CRxRefineLocDelegate
    func locationRefined(_ loc: CLLocation)
    {
        m_bLocationRefined = true;
        displayLocation(loc);
        decodeAddressFrom(location: loc);
    }

    //---------------------------------------------------------------------------
    // MARK: - MFMailComposeViewControllerDelegate
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil);
        
        if result == .sent {
            _ = navigationController?.popViewController(animated: true);
        }
    }

    //---------------------------------------------------------------------------
    // MARK: - UITextViewDelegate
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            textView.endEditing(true);
            return false;
        }
        return true
    }
    
    //---------------------------------------------------------------------------
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueRefineLoc" {
            let destVC = segue.destination as! RefineLocCtl
            destVC.m_locInit = m_location;
            destVC.delegate = self;
        }
    }
}

