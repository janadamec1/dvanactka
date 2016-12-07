//
//  CRxGame.swift
//  Dvanactka
//
//  Created by Jan Adamec on 06.12.16.
//  Copyright © 2016 Jan Adamec. All rights reserved.
//

import UIKit

class CRxGameCategory {
    var m_iProgress: Int = 0;   // visited locations
    var m_iTotal: Int = 1;      // to next level
    var m_iStars: Int = 0;      // stars awarded
    var m_sName: String;
    
    init(name: String) {
        m_sName = name;
    }
    
    func reset() {
        m_iProgress = 0;
        m_iStars = 0;
    }
    
    func incProgress() {
        if m_iProgress < m_iTotal {
            m_iProgress += 1;
        }
    }
    
    func awardStars(secondStarAt: Int) {
        m_iStars = 0;
        if m_iProgress >= m_iTotal {
            m_iStars = 3;
        }
        else if m_iProgress >= secondStarAt {
            m_iStars = 2;
        }
        else if m_iProgress > 0 {
            m_iStars = 1;
        }
    }
}

//---------------------------------------------------------------------------
class CRxGame: NSObject {
    static let checkInDistance = 50.0;
    
    var m_iPoints: Int = 0;
    var m_catForester: CRxGameCategory;
    var m_catCulturist: CRxGameCategory;
    var m_catVisitor: CRxGameCategory;
    var m_catRecyclist: CRxGameCategory;
    var m_arrCategories = [CRxGameCategory]();
    
    static let sharedInstance = CRxGame()  // singleton

    private override init() {
        m_catForester = CRxGameCategory(name: NSLocalizedString("Forester", comment: ""));
        m_arrCategories.append(m_catForester);
        m_catCulturist = CRxGameCategory(name: NSLocalizedString("Culturist", comment: ""));
        m_arrCategories.append(m_catCulturist);
        m_catVisitor = CRxGameCategory(name: NSLocalizedString("Visitor", comment: ""));
        m_arrCategories.append(m_catVisitor);
        m_catRecyclist = CRxGameCategory(name: NSLocalizedString("Recyclist", comment: ""));
        m_arrCategories.append(m_catRecyclist);
        super.init();
    }
    
    //---------------------------------------------------------------------------
    static func isCategoryCheckInAble(_ category: CRxCategory?) -> Bool {
        if let cat = category {
            return cat != .wasteGeneral && cat != .associations && cat != .prvniPomoc && cat != .children;
        }
        return true;
    }
    
    //---------------------------------------------------------------------------
    func getTotalInCategories() {
        
        m_catRecyclist.m_iTotal = 3;    // one in each category
        
        if let aDS = CRxDataSourceManager.sharedInstance.m_dictDataSources[CRxDataSourceManager.dsCooltour] {
            for rec in aDS.m_arrItems {
                if let category = rec.m_eCategory {
                    if category == .pamatka { m_catCulturist.m_iTotal += 1; }
                    else if category == .pamatnyStrom || category == .vyznamnyStrom { m_catForester.m_iTotal += 1; }
                    else if category == .zajimavost { m_catCulturist.m_iTotal += 1; }
                }
            }
        }
    }
    
    //---------------------------------------------------------------------------
    static func dataSource() -> CRxDataSource? {
        return CRxDataSourceManager.sharedInstance.m_dictDataSources[CRxDataSourceManager.dsGame];
    }
    
    //---------------------------------------------------------------------------
    func calcPointsFromDataSources() {
        guard let aDS = CRxGame.dataSource()
            else { return }
        
        m_iPoints = 0;
        m_catForester.reset();
        m_catCulturist.reset();
        m_catVisitor.reset();
        m_catRecyclist.reset();
        var bWasteVokVisited = false;
        var bWasteTextileVisited = false;
        var bWasteElectroVisited = false;
        for rec in aDS.m_arrItems {
            var iReward = 5;
            if let category = rec.m_eCategory {
                if category == .pamatka { m_catCulturist.incProgress(); }
                else if category == .pamatnyStrom || category == .vyznamnyStrom { m_catForester.incProgress(); }
                else if category == .zajimavost { m_catCulturist.incProgress(); }
                else if category == .waste && !bWasteVokVisited { m_catRecyclist.incProgress(); bWasteVokVisited = true; }
                else if category == .wasteTextile && !bWasteTextileVisited { m_catRecyclist.incProgress(); bWasteTextileVisited = true; }
                else if category == .wasteElectro && !bWasteElectroVisited { m_catRecyclist.incProgress(); bWasteElectroVisited = true; }
                else { iReward = 1; }   // 5 pts in game categories, 1 pt in other
            }
            m_iPoints += iReward;
        }
        
        // star awards
        m_catForester.awardStars(secondStarAt: 5);
        m_catCulturist.awardStars(secondStarAt: 3);
        m_catVisitor.awardStars(secondStarAt: 5);
        m_catRecyclist.awardStars(secondStarAt: 2);
    }
    
    //---------------------------------------------------------------------------
    func reinit() {
        getTotalInCategories();
        calcPointsFromDataSources();
    }

    //---------------------------------------------------------------------------
    func checkIn(at record: CRxEventRecord) {
        guard let aDS = CRxGame.dataSource()
            else { return }
        
        let recGame = CRxEventRecord(title: record.m_sTitle);
        recGame.m_eCategory = record.m_eCategory;
        recGame.m_aDate = Date();
        aDS.m_arrItems.append(recGame);
        
        // TODO: calc reward
        CRxDataSourceManager.sharedInstance.save(dataSource: aDS);
    }
    
    //---------------------------------------------------------------------------
    func playerWas(at record: CRxEventRecord) -> Bool {
        guard let aDS = CRxGame.dataSource()
            else { return true; }
        
        for recGame in aDS.m_arrItems {
            if recGame.m_sTitle == record.m_sTitle && recGame.m_eCategory == record.m_eCategory {
                return true;
            }
        }
        return false;
    }
}
