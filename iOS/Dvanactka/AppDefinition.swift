//
//  AppDefinition.swift
//  Dvanactka
//
//  Created by Jan Adamec on 05.03.18.
//  Copyright © 2018 Jan Adamec. All rights reserved.
//

import UIKit

class CRxAppDefinition: NSObject {
    // properties from json
    var m_sTitle: String?;
    var m_sWebsite: String?;
    var m_sCopyright: String?;
    var m_sContactEmail: String?;
    var m_sRecordUpdateEmail: String?;
    var m_sReportFaultEmail: String?;
    var m_sReportFaultEmailCc: String?;
    var m_sOutgoingLinkParameter: String?;
    var m_sServerDataBaseUrl: String?;
    
    // members
    var m_arrDataSourceOrder = [String]();      // dataSource IDs in order in which they were in the json
    private var m_sCurrentLocale: String;       // for loading localized strings from app definition json
    
    static let shared = CRxAppDefinition();  // singleton

    //--------------------------------------------------------------------------
    // "private" prevents others from using the default '()' initializer for this class (so being singleton)
    private override init() {
        m_sCurrentLocale = "en";

        // detect the localization I'm in
        let sLang = NSLocale.preferredLanguages[0];
        if !sLang.isEmpty {
            if let index = sLang.index(of: "-") {
                m_sCurrentLocale = String(sLang[..<index]);
            }
            else {
                m_sCurrentLocale = sLang;
            }
        }

        super.init();
    }

    //--------------------------------------------------------------------------
    func loadFromJson(file: URL) {
        var jsonData: Data?
        do {
            let jsonString = try String(contentsOf: file, encoding: .utf8);
            jsonData = jsonString.data(using: String.Encoding.utf8);
        } catch let error as NSError {
            print("JSON opening failed: \(error.localizedDescription)");
            return;
        }
        if let data = jsonData {
            loadFromJSON(data: data);
        }
    }
    
    //--------------------------------------------------------------------------
    func loadFromJSON(data: Data) {
        // decode JSON
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as? [String : AnyObject] {
                if let val = loadLocalizedString(key: "title", from: json) { m_sTitle = val; }
                if let val = loadLocalizedString(key: "website", from: json) { m_sWebsite = val; }
                if let val = loadLocalizedString(key: "copyright", from: json) { m_sCopyright = val; }
                if let val = loadLocalizedString(key: "contactEmail", from: json) { m_sContactEmail = val; }
                if let val = loadLocalizedString(key: "recordUpdateEmail", from: json) { m_sRecordUpdateEmail = val; }
                if let val = loadLocalizedString(key: "reportFaultEmail", from: json) { m_sReportFaultEmail = val; }
                if let val = loadLocalizedString(key: "reportFaultEmailCc", from: json) { m_sReportFaultEmailCc = val; }
                if let val = loadLocalizedString(key: "outgoingLinkParameter", from: json) { m_sOutgoingLinkParameter = val; }
                if let val = loadLocalizedString(key: "serverDataBaseUrl", from: json) { m_sServerDataBaseUrl = val; }
                
                // load dataSources
                if let jsonItems = json["dataSources"] as? [[String : AnyObject]] {
                    for item in jsonItems {
                        if let aNewDS = CRxDataSource(fromAppDefJson: item) {
                            CRxDataSourceManager.shared.m_dictDataSources[aNewDS.m_sId] = aNewDS;
                            m_arrDataSourceOrder.append(aNewDS.m_sId);
                        }
                    }
                }
            }
        } catch let error as NSError {
            print("JSON parsing failed: \(error.localizedDescription)"); return;
        }
    }
    
    //--------------------------------------------------------------------------
    // load string with possible localizatio into current locale (in json: "key@locale":value)
    func loadLocalizedString(key: String, from json: [String : AnyObject]) -> String? {
        if let sVal = json[key + "@" + m_sCurrentLocale] as? String { return sVal; }    // load localized
        if let sVal = json[key] as? String { return sVal; }     // load english
        return nil;
    }
    
    //--------------------------------------------------------------------------
    // convert color as CSS hex string into integer
    static func loadColor(key: String, from json: [String : AnyObject]) -> Int? {
        if let sVal = json[key] as? String {
            var sColorHex = sVal;
            if sColorHex.hasPrefix("#") {
                sColorHex.remove(at: sColorHex.startIndex);
            }
            if sColorHex.count == 6 {
                if let cl = Int(sColorHex, radix: 16) {
                    return ((cl & 0xFF0000) >> 16) + (cl & 0xFF00) + ((cl & 0xFF) << 16);
                }
            }
        }
        return nil;
    }

    //--------------------------------------------------------------------------
    func recordUpdateEmail() -> String? {
        if m_sRecordUpdateEmail != nil {
            return m_sRecordUpdateEmail;
        }
        else {
            return m_sContactEmail;
        }
    }
}
