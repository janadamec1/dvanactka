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
    var m_i2ndStarAt: Int;      // 2nd star awarded at this progress
    var m_iTotal: Int = 1;      // 3rd star at (all items in this category)
    var m_sName: String;
    
    init(name: String, secondStarAt star2: Int) {
        m_sName = name;
        m_i2ndStarAt = star2;
    }
    
    func reset() {
        m_iProgress = 0;
    }
    
    func stars() -> Int {
        if m_iProgress >= m_iTotal {
            return 3;
        }
        else if m_iProgress >= m_i2ndStarAt {
            return 2;
        }
        else if m_iProgress > 0 {
            return 1;
        }
        return 0;
    }
    
    func incProgress() -> Int {
        let iOldStars = stars();
        m_iProgress += 1;
        let iNewStars = stars();
        
        // returns number of stars in case the number increased
        if iNewStars > iOldStars {
            return iNewStars;
        }
        else {
            return 0;
        }
    }
    
    func nextStarPoints() -> Int {
        if m_iProgress >= m_i2ndStarAt {
            return m_iTotal;
        }
        else if m_iProgress >= 1 {
            return m_i2ndStarAt;
        }
        else {
            return 1;
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
    
    var m_bWasteVokVisited = false;
    var m_bWasteTextileVisited = false;
    var m_bWasteElectroVisited = false;
    
    static let sharedInstance = CRxGame()  // singleton

    private override init() {
        m_catForester = CRxGameCategory(name: NSLocalizedString("Forester", comment: ""), secondStarAt: 5);
        m_arrCategories.append(m_catForester);
        m_catCulturist = CRxGameCategory(name: NSLocalizedString("Culturist", comment: ""), secondStarAt: 3);
        m_arrCategories.append(m_catCulturist);
        m_catVisitor = CRxGameCategory(name: NSLocalizedString("Visitor", comment: ""), secondStarAt: 5);
        m_arrCategories.append(m_catVisitor);
        m_catRecyclist = CRxGameCategory(name: NSLocalizedString("Recyclist", comment: ""), secondStarAt: 2);
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
                    else if category == .zajimavost { m_catVisitor.m_iTotal += 1; }
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
        m_bWasteVokVisited = false;
        m_bWasteTextileVisited = false;
        m_bWasteElectroVisited = false;
        for rec in aDS.m_arrItems {
            let reward = addPoints(for: rec);
            m_iPoints += reward.points;
        }
    }

    //---------------------------------------------------------------------------
    func reinit() {
        getTotalInCategories();
        calcPointsFromDataSources();
    }
    
    //---------------------------------------------------------------------------
    func addPoints(for record: CRxEventRecord) -> (points: Int, newStars: Int, catName: String?) {
        var iReward = 5;
        var iNewStars = 0;
        var sCatName: String?;
        if let category = record.m_eCategory {
            if category == .pamatka {
                iNewStars = m_catCulturist.incProgress();
                sCatName = m_catCulturist.m_sName;
            }
            else if category == .pamatnyStrom || category == .vyznamnyStrom {
                iNewStars = m_catForester.incProgress();
                sCatName = m_catForester.m_sName;
            }
            else if category == .zajimavost {
                iNewStars = m_catVisitor.incProgress();
                sCatName = m_catVisitor.m_sName;
            }
            else if category == .waste && !m_bWasteVokVisited {
                iNewStars = m_catRecyclist.incProgress(); m_bWasteVokVisited = true;
                sCatName = m_catRecyclist.m_sName;
            }
            else if category == .wasteTextile && !m_bWasteTextileVisited {
                iNewStars = m_catRecyclist.incProgress(); m_bWasteTextileVisited = true;
                sCatName = m_catRecyclist.m_sName;
            }
            else if category == .wasteElectro && !m_bWasteElectroVisited {
                iNewStars = m_catRecyclist.incProgress(); m_bWasteElectroVisited = true;
                sCatName = m_catRecyclist.m_sName;
            }
            else { iReward = 1; }   // 5 pts in game categories, 1 pt in other
        }
        if iNewStars > 0 {
            iReward *= 5;
        }
        return (iReward, iNewStars, sCatName);
    }
    
    //---------------------------------------------------------------------------
    func checkIn(at record: CRxEventRecord) -> (points: Int, newStars: Int, catName: String?)? {
        guard let aDS = CRxGame.dataSource()
            else { return nil; }
        
        let recGame = CRxEventRecord(title: record.m_sTitle);
        recGame.m_eCategory = record.m_eCategory;
        recGame.m_aDate = Date();
        aDS.m_arrItems.append(recGame);
        CRxDataSourceManager.sharedInstance.save(dataSource: aDS);
        
        // return reward
        let reward = addPoints(for: record);
        m_iPoints += reward.points;
        return reward;
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
