//
//  ReportFaultCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 12.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit
import MessageUI
import Contacts     // for formatting address
//import AddressBookUI  // for formatting address < iOS 9

class ReportFaultCtl: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, CLLocationManagerDelegate, UITextFieldDelegate, UITextViewDelegate, MFMailComposeViewControllerDelegate, CRxRefineLocDelegate {
    @IBOutlet weak var m_lbHint: UILabel!
    @IBOutlet weak var m_lbSubject: UILabel!
    @IBOutlet weak var m_edSubject: UITextField!
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
    var m_locManager = CLLocationManager();
    var m_location: CLLocation?
    var m_bLocationRefined: Bool = false;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Localization
        //self.title = NSLocalizedString("Report Fault", comment: "");
        m_lbHint.text = NSLocalizedString("Report illegal dump, fault, problem", comment: "");
        m_lbSubject.text = NSLocalizedString("Subject", comment: "") + "*";
        m_lbPhoto.text = NSLocalizedString("Photo", comment: "") + "*";
        m_lbDescription.text = NSLocalizedString("Detailed description", comment: "");
        m_lbLocationTitle.text = NSLocalizedString("Location", comment: "") + "*";
        m_btnRefineLocation.setTitle(NSLocalizedString("Refine", comment: ""), for: .normal);
        
        m_edSubject.delegate = self;
        m_edDescription.delegate = self;

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "E-mail"/*NSLocalizedString("Send", comment: "")*/, style: .plain, target: self, action: #selector(ReportFaultCtl.onBtnSend));
        
        m_locManager.delegate = self;
        m_locManager.distanceFilter = 4;
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            m_locManager.startUpdatingLocation();
        }
        // for scrolling the vew when keyboard showing / hiding
        NotificationCenter.default.addObserver(self, selector: #selector(ReportFaultCtl.keyboardNotification(notification:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil);
    }
    
    //---------------------------------------------------------------------------
    deinit {
        NotificationCenter.default.removeObserver(self);
    }
    
    //---------------------------------------------------------------------------
    func showError(message: String, setFocusTo: UITextField? = nil) {
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
    func keyboardNotification(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let duration:TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIViewAnimationOptions.curveEaseInOut.rawValue
            let animationCurve:UIViewAnimationOptions = UIViewAnimationOptions(rawValue: animationCurveRaw)
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
                if m_edSubject.isFirstResponder {
                    aSelField = m_edSubject;
                }
                else if m_edDescription.isFirstResponder {
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
    func onBtnSend() {
        let sSubject = m_edSubject.text;
        if sSubject == nil || sSubject!.isEmpty {
            showError(message: NSLocalizedString("Please fill the subject field.", comment:""), setFocusTo: m_edSubject);
            return;
        }
        if !m_bImageSelected {
            showError(message: NSLocalizedString("Please select the photo.", comment:""));
            return;
        }
        if m_location == nil {
            showError(message: NSLocalizedString("Please specify the location.", comment:""));
            return;
        }
        var sMessageBody = "Předmět:\n\(sSubject!)";
        if let sDesc = m_edDescription.text {
            sMessageBody += "\n\nPopis:\n" + sDesc;
        }
        if let sAddress = m_lbLocation.text {
            sMessageBody += "\n\n" + sAddress;
        }
        if let loc = m_location {
            // send location as this link: https://mapy.cz/zakladni?x=14.4185889&y=50.0018275&z=17&source=coor&id=14.4185889%2C50.0020275
            let sMapLink = String(format: "https://mapy.cz/zakladni?x=%.8f&y=%.8f&z=17&source=coor&id=%.8f%%2C%.8f", arguments:[loc.coordinate.longitude, loc.coordinate.latitude, loc.coordinate.longitude, loc.coordinate.latitude]);
            sMessageBody += "\n" + sMapLink;
        }
        sMessageBody += "\n\n";
        
        let mailer = MFMailComposeViewController();
        mailer.mailComposeDelegate = self;
        
        mailer.setToRecipients(["jadamec@gmail.com"]);
        mailer.setSubject("P12app hlášení závady: " + sSubject!);
        mailer.setMessageBody(sMessageBody, isHTML: false);
        
        if let image = m_btnPhoto.image(for: .normal),
            let imageData = UIImageJPEGRepresentation(image, 0.8){
            mailer.addAttachmentData(imageData, mimeType: "image/jpeg", fileName: "photo.jpg")
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
        present(alertController, animated: true, completion: nil);
    }

    //---------------------------------------------------------------------------
    // MARK: - UIImagePickerControllerDelegate (taking a photo)
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion: nil)
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            // set mode to scale photo while keeping aspect
            m_btnPhoto.contentHorizontalAlignment = .fill
            m_btnPhoto.contentVerticalAlignment = .fill
            m_btnPhoto.imageView?.contentMode = .scaleAspectFit;
            
            m_btnPhoto.setImage(image, for: .normal);
            m_bImageSelected = true;
        }
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
                
                let pf = CNPostalAddressFormatter();
                let address = CNMutablePostalAddress()
                let addressdictionary = placemark.addressDictionary!;
                address.street = addressdictionary["Street"] as? String ?? ""
                address.city = addressdictionary["City"] as? String ?? ""
                address.postalCode = addressdictionary["ZIP"] as? String ?? ""
                //address.state = addressdictionary["State"] as? String ?? ""
                //address.country = addressdictionary["Country"] as? String ?? ""
                
                let sAddress = pf.string(from: address);
                //let sAddress = ABCreateStringWithAddressDictionary(placemark.addressDictionary!, false).components(separatedBy: "\n").joined(separator: ", ");
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
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true);
        return false;
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
