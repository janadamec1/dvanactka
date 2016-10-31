//
//  EventRecord.swift
//  Dvanactka
//
//  Created by Jan Adamec on 30.10.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit
import Kanna

class CRxEventRecord: NSObject {
    var m_sTitle: String = ""
    var m_sLink: String?
    var m_sCategory: String?
    var m_sText: String?
    var m_aDate: Date?
    
    init(title sTitle: String) {
        m_sTitle = sTitle
    }
    
    func openLink() {
        if var link = m_sLink {
            /*if (link.substring(to: 5) == "https") {
                link = "http"
            }
            UIApplication.sharedApplication.openURL(NSURL(string: link));*/
        }
    }
}

//--------------------------------------------------------------------------
class CRxDataSource : NSObject {
    var m_sId: String = ""
    var m_sTitle: String = ""           // human readable
    var m_nRefreshFreqHours: Int = 24   // refresh after 12 hours
    var m_dateLastRefreshed: Date?
    var m_arrItems: [CRxEventRecord] = [CRxEventRecord]()   // the data

    init(id: String, title: String, refreshFreqHours: Int = 24) {
        m_sId = id;
        m_sTitle = title;
        m_nRefreshFreqHours = refreshFreqHours;
    }
}

//--------------------------------------------------------------------------
class CRxDataSourceManager : NSObject {
    var m_dictDataSources = [String: CRxDataSource]()   // distionary on data sources, id -> source
    
    static let sharedInstance = CRxDataSourceManager()  // singleton
    private override init() {}     // "private" prevents others from using the default '()' initializer for this class (so being singleton)
    
    static let dsRadNews = "dsRadNews";
    static let dsRadAlerts = "dsRadAlerts";
    
    func defineDatasources() {
        m_dictDataSources[CRxDataSourceManager.dsRadNews] = CRxDataSource(id: CRxDataSourceManager.dsRadNews, title: NSLocalizedString("News", comment: ""));
        m_dictDataSources[CRxDataSourceManager.dsRadAlerts] = CRxDataSource(id: CRxDataSourceManager.dsRadAlerts, title: NSLocalizedString("Alerts", comment: ""));
    }
    
    func loadData() {
        //
    }
    
    func refreshAllDataSources(force: Bool = false) {
        
    }
    
    func refreshDataSource(id: String, force: Bool = false) {
    
    }
    
    func refreshRadniceDataSources() {
        
        // XPath syntax: https://www.w3.org/TR/xpath/#path-abbrev

        //let url = URL(string: "https://www.praha12.cz/")
        //if let doc = HTML(url: url!, encoding: .utf8) {
        
        if let path = Bundle.main.path(forResource: "/test_files/praha12titulka", ofType: "html") {
            let html = try! String(contentsOfFile: path, encoding: .utf8)
            if let doc = HTML(html: html, encoding: .utf8) {
                
                let aNewsDS = m_dictDataSources[CRxDataSourceManager.dsRadNews]
                
                for node in doc.xpath("//div[@class='titulDoc aktClanky']//li") {
                    if let a_title = node.xpath("strong//a").first, let sTitle = a_title.text {
                        let aNewRecord = CRxEventRecord(title: sTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        if let sLink = a_title["href"] {
                            aNewRecord.m_sLink = sLink;
                        }
                        
                        if let aDateNode = node.xpath("span").first, let sDate = aDateNode.text {
                            let df = DateFormatter();
                            df.dateFormat = "(dd.MM.yyyy)";
                            if let date = df.date(from: sDate) {
                                aNewRecord.m_aDate = date;// as NSDate?
                            }
                        }
                        
                        if let aTextNode = node.xpath("div[1]").first {
                            aNewRecord.m_sText = aTextNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        if let aCategoriesNode = node.xpath("div[@class='ktg']//a").first {
                            aNewRecord.m_sCategory = aCategoriesNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        //dump(aNewRecord)
                        aNewsDS?.m_arrItems.append(aNewRecord);
                    }
                }

                let aAlertsDS = m_dictDataSources[CRxDataSourceManager.dsRadAlerts]
                
                for node in doc.xpath("//div[@class='titulDoc upoClanky']//li") {
                    if let a_title = node.xpath("strong//a").first, let sTitle = a_title.text {
                        let aNewRecord = CRxEventRecord(title: sTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                        
                        if let sLink = a_title["href"] {
                            aNewRecord.m_sLink = sLink;
                        }
                        
                        if let aDateNode = node.xpath("span").first, let sDate = aDateNode.text {
                            let df = DateFormatter();
                            df.dateFormat = "(dd.MM.yyyy)";
                            if let date = df.date(from: sDate) {
                                aNewRecord.m_aDate = date;// as NSDate?
                            }
                        }
                        
                        if let aTextNode = node.xpath("div[1]").first {
                            aNewRecord.m_sText = aTextNode.text?.trimmingCharacters(in: .whitespacesAndNewlines);
                        }
                        //dump(aNewRecord)
                        aAlertsDS?.m_arrItems.append(aNewRecord);
                    }
                }
            }
        }
    }
}
