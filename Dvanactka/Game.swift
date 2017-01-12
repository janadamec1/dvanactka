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
    var m_i3rdStarAt: Int;      // 3rd star at (all items in this category)
    var m_sName: String;
    var m_sHintMessage: String;
    
    init(name: String, secondStarAt star2: Int, thirdAt star3: Int, hint: String) {
        m_sName = name;
        m_i2ndStarAt = star2;
        m_i3rdStarAt = star3;
        m_sHintMessage = hint;
    }
    
    func reset() {
        m_iProgress = 0;
    }
    
    func stars() -> Int {
        if m_iProgress >= m_i3rdStarAt {
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
            return m_i3rdStarAt;
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
        m_catForester = CRxGameCategory(name: NSLocalizedString("Forester", comment: ""), secondStarAt: 5, thirdAt: 15,
                                        hint: NSLocalizedString("Visit trees.", comment: ""));
        m_arrCategories.append(m_catForester);
        m_catCulturist = CRxGameCategory(name: NSLocalizedString("Culturist", comment: ""), secondStarAt: 3, thirdAt: 5,
                                         hint: NSLocalizedString("Visit cultural landmarks.", comment: ""));
        m_arrCategories.append(m_catCulturist);
        m_catVisitor = CRxGameCategory(name: NSLocalizedString("Visitor", comment: ""), secondStarAt: 5, thirdAt: 11,
                                       hint: NSLocalizedString("Visit interesting places.", comment: ""));
        m_arrCategories.append(m_catVisitor);
        m_catRecyclist = CRxGameCategory(name: NSLocalizedString("Recyclist", comment: ""), secondStarAt: 2, thirdAt: 3,
                                         hint: NSLocalizedString("Visit different dumpster types.", comment: ""));
        m_arrCategories.append(m_catRecyclist);
        super.init();
    }
    
    //---------------------------------------------------------------------------
    static func isCategoryCheckInAble(_ category: CRxCategory?) -> Bool {
        if let cat = category {
            return cat != .wasteGeneral && cat != .associations && cat != .prvniPomoc && cat != .children && cat != .nehoda && cat != .uzavirka;
        }
        return false;
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
        calcPointsFromDataSources();
    }
    
    //---------------------------------------------------------------------------
    func addPoints(for record: CRxEventRecord) -> (points: Int, newStars: Int, catName: String?) {
        var iReward = 40;
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
                iReward = 150;
            }
            else if category == .wasteTextile && !m_bWasteTextileVisited {
                iNewStars = m_catRecyclist.incProgress(); m_bWasteTextileVisited = true;
                sCatName = m_catRecyclist.m_sName;
                iReward = 80;
            }
            else if category == .wasteElectro && !m_bWasteElectroVisited {
                iNewStars = m_catRecyclist.incProgress(); m_bWasteElectroVisited = true;
                sCatName = m_catRecyclist.m_sName;
                iReward = 80;
            }
            else { iReward = 10; }   // 40 pts in game categories, 10 pt in other
        }
        if iNewStars > 0 {
            iReward *= 2;
        }
        return (iReward, iNewStars, sCatName);
    }
    
    //---------------------------------------------------------------------------
    func checkIn(at record: CRxEventRecord) -> (points: Int, newLevel: Int, newStars: Int, catName: String?)? {
        guard let aDS = CRxGame.dataSource()
            else { return nil; }
        
        let recGame = CRxEventRecord(title: record.m_sTitle);
        recGame.m_eCategory = record.m_eCategory;
        recGame.m_aDate = Date();
        aDS.m_arrItems.append(recGame);
        CRxDataSourceManager.sharedInstance.save(dataSource: aDS);
        
        // return reward
        let iOldLevel = playerLevel().level;
        
        let reward = addPoints(for: record);
        m_iPoints += reward.points;
        
        var iNewLevel = playerLevel().level;
        if iNewLevel <= iOldLevel {
            iNewLevel = 0;
        }
        
        return (reward.points, iNewLevel, reward.newStars, reward.catName);
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
    
    //---------------------------------------------------------------------------
    func playerLevel() -> (level: Int, points: Int, pointsPrevLevel: Int, pointsNextLevel: Int) {
        var iLevel = 1;
        var iLevelSize = 60;
        var iToNextLevel = iLevelSize;
        
        while iToNextLevel <= m_iPoints {
            iLevel += 1;
            iLevelSize += 20;
            iToNextLevel += iLevelSize;
        }
        return (iLevel, m_iPoints, iToNextLevel-iLevelSize, iToNextLevel);
    }
}
