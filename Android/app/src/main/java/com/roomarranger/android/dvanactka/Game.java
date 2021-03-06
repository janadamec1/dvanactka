package com.roomarranger.android.dvanactka;

import android.content.Context;
import android.content.res.Resources;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.InputStream;
import java.net.URL;
import java.util.ArrayList;
import java.util.Date;
import java.util.Locale;
import java.util.UUID;

/*
 Copyright 2016-2018 Jan Adamec.

 This file is part of "Dvanactka".

 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.

 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
*/

class CRxGameCategory {
    int m_iProgress = 0;   // visited locations
    private int m_i2ndStarAt;      // 2nd star awarded at this progress
    private int m_i3rdStarAt;      // 3rd star at (all items in this category)
    String m_sName;
    String m_sHintMessage;

    CRxGameCategory(String name, int star2, int star3, String hint) {
        m_sName = name;
        m_i2ndStarAt = star2;
        m_i3rdStarAt = star3;
        m_sHintMessage = hint;
    }

    void reset() {
        m_iProgress = 0;
    }

    int stars() {
        if (m_iProgress >= m_i3rdStarAt) {
            return 3;
        }
        else if (m_iProgress >= m_i2ndStarAt) {
            return 2;
        }
        else if (m_iProgress > 0) {
            return 1;
        }
        return 0;
    }

    int incProgress() {
        int iOldStars = stars();
        m_iProgress += 1;
        int iNewStars = stars();

        // returns number of stars in case the number increased
        if (iNewStars > iOldStars) {
            return iNewStars;
        }
        else {
            return 0;
        }
    }

    int nextStarPoints() {
        if (m_iProgress >= m_i2ndStarAt) {
            return m_i3rdStarAt;
        }
        else if (m_iProgress >= 1) {
            return m_i2ndStarAt;
        }
        else {
            return 1;
        }
    }
}

//---------------------------------------------------------------------------
class CRxGame {
    static double checkInDistance = 50.0;

    int m_iPoints = 0;
    private CRxGameCategory m_catForester, m_catCulturist, m_catVisitor, m_catRecyclist;
    ArrayList<CRxGameCategory> m_arrCategories = new ArrayList<>();

    private boolean m_bWasteVokVisited = false;
    private boolean m_bWasteTextileVisited = false;
    private boolean m_bWasteElectroVisited = false;

    static CRxGame shared = new CRxGame();  // singleton

    private CRxGame() {
        super();
    }
    void init(Context ctx) {
        Resources res = ctx.getResources();
        m_catForester = new CRxGameCategory(res.getString(R.string.g_forester), 5, 15, res.getString(R.string.g_forester_hint));
        m_arrCategories.add(m_catForester);
        m_catCulturist = new CRxGameCategory(res.getString(R.string.g_culturist), 3, 5, res.getString(R.string.g_culturist_hint));
        m_arrCategories.add(m_catCulturist);
        m_catVisitor = new CRxGameCategory(res.getString(R.string.g_visitor), 5, 11, res.getString(R.string.g_visitor_hint));
        m_arrCategories.add(m_catVisitor);
        m_catRecyclist = new CRxGameCategory(res.getString(R.string.g_recyclist), 2, 3, res.getString(R.string.g_recyclist_hint));
        m_arrCategories.add(m_catRecyclist);
    }

    //---------------------------------------------------------------------------
    static boolean isCategoryCheckInAble(String cat) {
        if (cat!=null) {
            return !cat.equals(CRxCategory.wasteGeneral) && !cat.equals(CRxCategory.wasteSeparated)
                    && !cat.equals(CRxCategory.associations) && !cat.equals(CRxCategory.prvniPomoc)
                    && !cat.equals(CRxCategory.children) && !cat.equals(CRxCategory.nehoda) && !cat.equals(CRxCategory.uzavirka)
                    && !cat.equals(CRxCategory.wc);
        }
        return false;
    }

    //---------------------------------------------------------------------------
    static CRxDataSource dataSource() {
        return CRxDataSourceManager.shared.m_dictDataSources.get(CRxDataSourceManager.dsGame);
    }

    //---------------------------------------------------------------------------
    private void calcPointsFromDataSources() {
        CRxDataSource aDS = CRxGame.dataSource();
        if (aDS == null) { return; }

        m_iPoints = 0;
        m_catForester.reset();
        m_catCulturist.reset();
        m_catVisitor.reset();
        m_catRecyclist.reset();
        m_bWasteVokVisited = false;
        m_bWasteTextileVisited = false;
        m_bWasteElectroVisited = false;
        for (CRxEventRecord rec : aDS.m_arrItems) {
            CRxCheckInReward reward = addPoints(rec);
            m_iPoints += reward.points;
        }
    }

    //---------------------------------------------------------------------------
    void reinit() {
        calcPointsFromDataSources();
    }

    //---------------------------------------------------------------------------
    class CRxCheckInReward {
        int points, newStars;
        int newLevel = 0;
        String catName = null;
    }
    private CRxCheckInReward addPoints(CRxEventRecord record) {
        int iReward = 40;
        int iNewStars = 0;
        String sCatName = null;
        String category = record.m_eCategory;
        if (category != null) {
            if (category.equals(CRxCategory.pamatka)) {
                iNewStars = m_catCulturist.incProgress();
                sCatName = m_catCulturist.m_sName;
            }
            else if (category.equals(CRxCategory.pamatnyStrom) || category.equals(CRxCategory.vyznamnyStrom)) {
                iNewStars = m_catForester.incProgress();
                sCatName = m_catForester.m_sName;
            }
            else if (category.equals(CRxCategory.zajimavost)) {
                iNewStars = m_catVisitor.incProgress();
                sCatName = m_catVisitor.m_sName;
            }
            else if (category.equals(CRxCategory.waste) && !m_bWasteVokVisited) {
                iNewStars = m_catRecyclist.incProgress(); m_bWasteVokVisited = true;
                sCatName = m_catRecyclist.m_sName;
                iReward = 150;
            }
            else if (category.equals(CRxCategory.wasteTextile) && !m_bWasteTextileVisited) {
                iNewStars = m_catRecyclist.incProgress(); m_bWasteTextileVisited = true;
                sCatName = m_catRecyclist.m_sName;
                iReward = 80;
            }
            else if (category.equals(CRxCategory.wasteElectro) && !m_bWasteElectroVisited) {
                iNewStars = m_catRecyclist.incProgress(); m_bWasteElectroVisited = true;
                sCatName = m_catRecyclist.m_sName;
                iReward = 80;
            }
            else { iReward = 10; }   // 40 pts in game categories, 10 pt in other
        }
        if (iNewStars > 0) {
            iReward *= 2;
        }
        CRxCheckInReward ret = new CRxCheckInReward();
        ret.points = iReward;
        ret.newStars = iNewStars;
        ret.catName = sCatName;
        return ret;
    }

    //---------------------------------------------------------------------------
    CRxCheckInReward checkIn(CRxEventRecord record) {
        CRxDataSource aDS = CRxGame.dataSource();
        if (aDS == null) { return null; }

        CRxEventRecord recGame = new CRxEventRecord(record.m_sTitle);
        recGame.m_eCategory = record.m_eCategory;
        recGame.m_aDate = new Date();
        aDS.m_arrItems.add(recGame);
        CRxDataSourceManager.shared.save(aDS);

        // return reward
        int iOldLevel = playerLevel().level;

        CRxCheckInReward reward = addPoints(record);
        m_iPoints += reward.points;

        int iNewLevel = playerLevel().level;
        if (iNewLevel <= iOldLevel) {
            iNewLevel = 0;
        }

        sendScoreToServer();

        reward.newLevel = iNewLevel;
        return reward;
    }

    //---------------------------------------------------------------------------
    boolean playerWas(CRxEventRecord record) {
        CRxDataSource aDS = CRxGame.dataSource();
        if (aDS == null) { return true; }

        for (CRxEventRecord recGame: aDS.m_arrItems) {
            if (recGame.m_sTitle.equals(record.m_sTitle) && recGame.m_eCategory.equals(record.m_eCategory)) {
                return true;
            }
        }
        return false;
    }

    //---------------------------------------------------------------------------
    class CRxPlayerStats {
        int level, points, pointsPrevLevel, pointsNextLevel;
    }
    CRxPlayerStats playerLevel() {
        int iLevel = 1;
        int iLevelSize = 60;
        int iToNextLevel = iLevelSize;

        while (iToNextLevel <= m_iPoints) {
            iLevel += 1;
            iLevelSize += 20;
            iToNextLevel += iLevelSize;
        }
        CRxPlayerStats ret = new CRxPlayerStats();
        ret.level = iLevel;
        ret.points = m_iPoints;
        ret.pointsPrevLevel = iToNextLevel-iLevelSize;
        ret.pointsNextLevel = iToNextLevel;
        return ret;
    }

    //---------------------------------------------------------------------------
    void sendScoreToServer() {
        CRxDataSource aDS = CRxGame.dataSource();
        if (aDS == null) { return; }

        if (aDS.m_sUuid == null) {
            // generate new unique ID for this device
            aDS.m_sUuid = UUID.randomUUID().toString();
            CRxDataSourceManager.shared.save(aDS);
        }
        if (aDS.m_sUuid != null && CRxAppDefinition.shared.m_sServerDataBaseUrl != null) {
            String sScore = String.format(Locale.US, "%d", m_iPoints);
            // calc checksum
            int iChecksum = 0;
            for (int i = 0; i < aDS.m_sUuid.length(); i++) iChecksum += aDS.m_sUuid.codePointAt(i);
            for (int i = 0; i < sScore.length(); i++) iChecksum += sScore.codePointAt(i);

            String sParams = String.format(Locale.US, "?id=%s&s=%s&c=%d", aDS.m_sUuid, sScore, iChecksum);
            try {
                final URL url = new URL(CRxAppDefinition.shared.m_sServerDataBaseUrl + "game_putscore.php" + sParams);
                Thread thread = new Thread(new Runnable(){
                    @Override
                    public void run(){
                        try {
                            InputStream inStream = url.openStream();

                            DataInputStream stream = new DataInputStream(inStream);
                            BufferedInputStream bufferedReader = new BufferedInputStream(stream);

                            byte[] buffer = new byte[2048];
                            int bytesRead = 0;
                            ByteArrayOutputStream byteArray = new ByteArrayOutputStream();

                            while ((bytesRead = bufferedReader.read(buffer))!= -1) {
                                byteArray.write(buffer, 0, bytesRead);  // TODO: is it really needed to read the output??
                            }

                            stream.close();
                        }
                        catch (Exception e) {
                            e.printStackTrace();
                        }
                    }
                });
                thread.start();

            }
            catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
}
