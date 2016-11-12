//
//  ReportFaultCtl.swift
//  Dvanactka
//
//  Created by Jan Adamec on 12.11.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import MapKit
import Contacts     // for formatting address
//import AddressBookUI  // for formatting address < iOS 9

class ReportFaultCtl: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, CLLocationManagerDelegate, UITextFieldDelegate, UITextViewDelegate {
    @IBOutlet weak var m_edSubject: UITextField!
    @IBOutlet weak var m_btnPhoto: UIButton!
    @IBOutlet weak var m_lbDescription: UILabel!
    @IBOutlet weak var m_edDescription: UITextView!
    @IBOutlet weak var m_lbLocationTitle: UILabel!
    @IBOutlet weak var m_lbLocation: UILabel!
    @IBOutlet weak var m_btnRefineLocation: UIButton!
    
    var m_bImageSelected: Bool = false;
    var m_locManager = CLLocationManager();
    var m_location: CLLocation?
    var m_bLocationRefined: Bool = false;

    override func viewDidLoad() {
        super.viewDidLoad()
        // Localization
        self.title = NSLocalizedString("Report Fault", comment: "");
        m_edSubject.placeholder = NSLocalizedString("Subject", comment: "");
        m_lbDescription.text = NSLocalizedString("Detailed description", comment: "");
        m_lbLocationTitle.text = NSLocalizedString("Location", comment: "");
        m_btnRefineLocation.setTitle(NSLocalizedString("Refine", comment: ""), for: .normal);
        
        m_edSubject.delegate = self;
        m_edDescription.delegate = self;

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Send", comment: ""), style: .plain, target: self, action: #selector(ReportFaultCtl.onBtnSend));
        
        m_locManager.delegate = self;
        m_locManager.distanceFilter = 4;
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            m_locManager.startUpdatingLocation();
        }
    }

    //---------------------------------------------------------------------------
    func onBtnSend() {
        
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
        let actionGallery = UIAlertAction(title: NSLocalizedString("From photo library", comment:""), style: .default) { result in
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
    @IBAction func onBtnRefineLocationTouched(_ sender: Any) {
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
        }
    }
}
