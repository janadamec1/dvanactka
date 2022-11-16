package com.roomarranger.android.dvanactka;

import android.location.Location;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Locale;

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

class CRxAppDefinition {
    String m_sTitle = null;
    String m_sWebsite = null;
    String m_sCopyright = null;
    String m_sContactEmail = null;
    private String m_sRecordUpdateEmail = null;
    String m_sReportFaultEmail = null;
    String m_sReportFaultEmailCc = null;
    String m_sOutgoingLinkParameter = null;
    String m_sServerDataBaseUrl = null;
    String m_sMunicipality = null;
    Location m_aMunicipalityCenter = null;

    ArrayList<String> m_arrDataSourceOrder = new ArrayList<>(); // dataSource IDs in order in which they were in the json
    private String m_sCurrentLocale = "en";     // for loading localized strings from app definition json

    static CRxAppDefinition shared = new CRxAppDefinition();  // singleton

    private CRxAppDefinition() {
        super();
    }

    //--------------------------------------------------------------------------
    void loadFromJSONStream(InputStream inputStream) {
        String currentLocale = Locale.getDefault().getLanguage();
        if (!currentLocale.isEmpty())
            m_sCurrentLocale = currentLocale;

        String jsonData;
        try {
            InputStreamReader inputStreamReader = new InputStreamReader(inputStream);
            BufferedReader bufferedReader = new BufferedReader(inputStreamReader);
            String receiveString;
            StringBuilder stringBuilder = new StringBuilder();

            while ((receiveString = bufferedReader.readLine()) != null) {
                stringBuilder.append(receiveString);
            }

            inputStream.close();
            jsonData = stringBuilder.toString();
        }
        catch(Exception e) {
            Log.e("loadFromJSONStream", "JSON opening failed: " + e.getMessage()); return;
        }
        loadFromJSONString(jsonData);
    }

    //--------------------------------------------------------------------------
    private void loadFromJSONString(String data) {
        // decode JSON
        JSONObject json;
        try {
            json = new JSONObject(data);
        } catch(Exception e) {
            Log.e("loadFromJSON", "JSON parsing failed: " + e.getMessage()); return;
        }

        m_sTitle = loadLocalizedString("title", json);
        m_sWebsite = loadLocalizedString("website", json);
        m_sCopyright = loadLocalizedString("copyright", json);
        m_sContactEmail = loadLocalizedString("contactEmail", json);
        m_sRecordUpdateEmail = loadLocalizedString("recordUpdateEmail", json);
        m_sReportFaultEmail = loadLocalizedString("reportFaultEmail", json);
        m_sReportFaultEmailCc = loadLocalizedString("reportFaultEmailCc", json);
        m_sOutgoingLinkParameter = loadLocalizedString("outgoingLinkParameter", json);
        m_sServerDataBaseUrl = loadLocalizedString("serverDataBaseUrl", json);
        m_sMunicipality = loadLocalizedString("municipality", json);

        try {
            String locationLat = json.getString("municipalityCenterLat");
            String locationLong = json.getString("municipalityCenterLong");
            double dLocLat = Double.parseDouble(locationLat);
            double dLocLong = Double.parseDouble(locationLong);
            m_aMunicipalityCenter = new Location("json");
            m_aMunicipalityCenter.setLatitude(dLocLat);
            m_aMunicipalityCenter.setLongitude(dLocLong);
        }
        catch (Exception ignored) {}

        // load dataSources
        try {
            JSONArray jsonItems = json.getJSONArray("dataSources");
            for (int i = 0; i < jsonItems.length(); i++) {
                JSONObject item = jsonItems.getJSONObject(i);

                CRxDataSource aNewDS = CRxDataSource.fromAppDefJson(item);
                if (aNewDS != null) {
                    CRxDataSourceManager.shared.m_dictDataSources.put(aNewDS.m_sId, aNewDS);
                    m_arrDataSourceOrder.add(aNewDS.m_sId);
                }
            }
        }
        catch (JSONException ignored) {}
    }

    //--------------------------------------------------------------------------
    // load string with possible localization into current locale (in json: "key@locale":value)
    String loadLocalizedString(String key, JSONObject json) {

        String sVal = json.optString(key + "@" + m_sCurrentLocale, ""); // load localized
        if (sVal.isEmpty()) {
            sVal = json.optString(key, "");       // load english
        }
        if (sVal.isEmpty())
            return null;        // our function expect null when not founds
        else
            return sVal;
    }

    //--------------------------------------------------------------------------
    // convert color as CSS hex string into integer
    static int loadColor(String key, JSONObject json, int iDef) {

        try {
            String sVal = json.getString(key);
            if (sVal.startsWith("#"))
                sVal = sVal.substring(1);
            if (sVal.length() == 6) {
                try {
                    int cl = Integer.parseInt(sVal, 16); // hex to int
                    return ((cl & 0xFF0000) >> 16) + (cl & 0xFF00) + ((cl & 0xFF) << 16);
                }
                catch (NumberFormatException ignored) {}
            }
        }
        catch (JSONException e) { return iDef; }
        return iDef;
    }

    //--------------------------------------------------------------------------
    String recordUpdateEmail() {
        if (m_sRecordUpdateEmail != null) {
            return m_sRecordUpdateEmail;
        }
        else {
            return m_sContactEmail;
        }
    }
}
