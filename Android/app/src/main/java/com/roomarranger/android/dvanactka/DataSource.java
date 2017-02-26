package com.roomarranger.android.dvanactka;

import android.content.Context;
import android.content.res.AssetManager;
import android.content.res.Resources;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Created by jadamec on 28.12.16.
 */

interface CRxDataSourceRefreshDelegate {
    void dataSourceRefreshEnded(String sDsId, String error);
}

class CRxDataSource {
    String m_sId;
    String m_sTitle;           // human readable
    String m_sShortTitle = null;
    String m_sIcon;
    int m_iBackgroundColor;
    int m_nRefreshFreqHours = 18;   // refresh after 18 hours
    String m_sTestJsonFile = null;  // offline data file
    String m_sLastItemShown = "";   // hash of the last record user displayed (to count unread news, etc)
    String m_sUuid = null;          // id used in game data source
    Date m_dateLastRefreshed = null;
    boolean m_bIsBeingRefreshed = false;
    ArrayList<CRxEventRecord> m_arrItems = new ArrayList<CRxEventRecord>();   // the data
    CRxDataSourceRefreshDelegate delegate = null;

    static final int DATATYPE_events = 0, DATATYPE_news = 1, DATATYPE_places = 2;
    int m_eType;        // contains DATATYPE_xxxx

    boolean m_bGroupByCategory = true;       // UI should show sections for each category
    boolean m_bFilterAsParentView = false;   // UI should first show the list of possible filters
    boolean m_bFilterable = false;           // UI can filter this datasource accoring to records' m_sFilter
    Set<String> m_setFilter = null;       // contains strings that should NOT be shown

    CRxDataSource(String id, String title, String icon, int type, int backgroundColor) {
        super();
        m_sId = id;
        m_sTitle = title;
        m_sIcon = icon;
        m_eType = type;
        m_iBackgroundColor = backgroundColor;
    }

    //--------------------------------------------------------------------------
    void loadFromJSON(File file) {
        try {
            loadFromJSONStream(new FileInputStream(file));
        }
        catch(Exception e) {
            Log.e("loadFromJSON", "JSON opening failed: " + e.getMessage());
        }
    }

    //--------------------------------------------------------------------------
    void loadFromJSONStream(InputStream inputStream) {
        String jsonData = "";
        try {
            InputStreamReader inputStreamReader = new InputStreamReader(inputStream);
            BufferedReader bufferedReader = new BufferedReader(inputStreamReader);
            String receiveString = "";
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
    void loadFromJSONString(String data) {
        // decode JSON
        JSONObject json = null;
        try {
            json = new JSONObject(data);
        } catch(Exception e) {
            Log.e("loadFromJSON", "JSON parsing failed: " + e.getMessage()); return;
        }

        // load data
        try {
            JSONArray jsonItems = json.getJSONArray("items");
            m_arrItems.clear();
            for (int i = 0; i < jsonItems.length(); i++) {
                JSONObject item = jsonItems.getJSONObject(i);
                CRxEventRecord aNewRecord = CRxEventRecord.fromJson(item);
                if (aNewRecord != null)
                    m_arrItems.add(aNewRecord);
            }
        }
        catch (JSONException e) {};

        // load config
        try {
            JSONObject config = json.getJSONObject("config");
            m_dateLastRefreshed = CRxEventRecord.loadDate(config.optString("dateLastRefreshed", null));
            m_sLastItemShown = config.optString("lastItemShown", "");
            m_sUuid = config.optString("uuid", null);
            try {
                String filter = config.getString("filter");
                m_setFilter = new HashSet<String>(Arrays.asList(filter.split("|")));
            }
            catch (JSONException e) {}

        }
        catch (JSONException e) {}
    }

    //--------------------------------------------------------------------------
    void saveToJSON(File file) {
        // save data
        JSONArray jsonItems = new JSONArray();
        for (CRxEventRecord item: m_arrItems) {
            jsonItems.put(item.saveToJSON());
        }

        JSONObject json = new JSONObject();
        try { json.put("items", jsonItems); } catch (JSONException e) {}

        // save config
        JSONObject config = new JSONObject();
        try { config.put("dateLastRefreshed", CRxEventRecord.saveDate(m_dateLastRefreshed)); } catch (JSONException e) {}
        try { config.put("lastItemShown", m_sLastItemShown); } catch (JSONException e) {}
        if (m_setFilter != null)
        {
            StringBuilder sb = new StringBuilder();
            for (String sFilter: m_setFilter) {
                if (sb.length() != 0) sb.append("|");
                sb.append(sFilter);
            }
            try { config.put("filter", sb.toString()); } catch (JSONException e) {}
        }
        if (m_sUuid != null) { try { config.put("uuid", m_sUuid); } catch (JSONException e) {} }

        if (config.length() > 0) {
            try { json.put("config", config); } catch (JSONException e) {}
        }

        // encode to JSON
        String jsonString = json.toString();
        try {
            OutputStreamWriter stream = new OutputStreamWriter(new FileOutputStream(file));
            stream.write(jsonString);
            stream.close();
        }
        catch (IOException e) {
            Log.e("Exception", "File write failed: " + e.toString());
        }
    }

    //--------------------------------------------------------------------------
    int unreadItemsCount() {
        if (m_eType == DATATYPE_news) {
            if (m_sLastItemShown.isEmpty()) {   // never opened
                return m_arrItems.size();
            }
            for (int i = 0; i < m_arrItems.size(); i++) {
                if (m_arrItems.get(i).recordHash().equals(m_sLastItemShown)) {
                    return i;
                }
            }
            return m_arrItems.size();    // read too old news item (all are newer)
        }
        return 0;
    }

    //--------------------------------------------------------------------------
    void sortNewsByDate() {
        if (m_eType == DATATYPE_news) {
            Collections.sort(m_arrItems, new Comparator<CRxEventRecord>() {
                @Override
                public int compare(CRxEventRecord t0, CRxEventRecord t1)
                {
                    return -t0.m_aDate.compareTo(t1.m_aDate);
                }
            });
        }
    }

    //--------------------------------------------------------------------------
    CRxEventRecord recordWithHash(String sRecordHash) {
        for (int i = 0; i < m_arrItems.size(); i++) {
            if (m_arrItems.get(i).recordHash().equals(sRecordHash)) {
                return m_arrItems.get(i);
            }
        }
        return null;
    }

}

//--------------------------------------------------------------------------
//--------------------------------------------------------------------------
class CRxDataSourceManager {
    private static final boolean g_bUseTestFiles = false;

    HashMap<String, CRxDataSource> m_dictDataSources = new HashMap<String, CRxDataSource>(); // dictionary on data sources, id -> source

    static final String dsRadNews = "dsRadNews";
    static final String dsRadEvents = "dsRadEvents";
    static final String dsRadDeska = "dsRadDeska";
    static final String dsBiografProgram = "dsBiografProgram";
    static final String dsCooltour = "dsCooltour";
    static final String dsSosContacts = "dsSosContacts";
    static final String dsWaste = "dsWaste";
    static final String dsShops = "dsShops";
    static final String dsWork = "dsWork";
    static final String dsSpolky = "dsSpolky";
    static final String dsSpolkyList = "dsSpolkyList";
    static final String dsReportFault = "dsReportFault";
    static final String dsGame = "dsGame";
    static final String dsTraffic = "dsTraffic";
    static final String dsSavedNews = "dsSavedNews";

    int m_nNetworkIndicatorUsageCount = 0;
    File m_urlDocumentsDir;
    AssetManager m_assetMan;
    CRxDataSource m_aSavedNews = new CRxDataSource(CRxDataSourceManager.dsSavedNews, "Saved News", "ds_news", CRxDataSource.DATATYPE_news, 0xffffff);    // (records over all news sources)
    Set<String> m_setPlacesNotified = new HashSet<String>();  // (titles)
    CRxDataSourceRefreshDelegate delegate = null; // one global delegate (main viewController)

    private static CRxDataSourceManager instance = null;
    private CRxDataSourceManager() {} // "private" prevents others from using the default '()' initializer for this class (so being singleton)

    public static CRxDataSourceManager sharedInstance()
    {
        if (instance == null)
            instance = new CRxDataSourceManager();
        return instance;
    }

    void defineDatasources(Context ctx) {
        Resources res = ctx.getResources();
        m_assetMan = res.getAssets();
        m_urlDocumentsDir = ctx.getDir("json", Context.MODE_PRIVATE);
        m_aSavedNews.m_sTitle = res.getString(R.string.saved_news);

        m_dictDataSources.put(CRxDataSourceManager.dsRadNews, new CRxDataSource(CRxDataSourceManager.dsRadNews, res.getString(R.string.news), "ds_news", CRxDataSource.DATATYPE_news, 0x3f4d88));
        m_dictDataSources.put(CRxDataSourceManager.dsRadEvents, new CRxDataSource(CRxDataSourceManager.dsRadEvents, res.getString(R.string.events), "ds_events", CRxDataSource.DATATYPE_events, 0xdb552d));
        m_dictDataSources.put(CRxDataSourceManager.dsRadDeska, new CRxDataSource(CRxDataSourceManager.dsRadDeska, res.getString(R.string.official_board), "ds_billboard", CRxDataSource.DATATYPE_news, 0x3f4d88));
        m_dictDataSources.put(CRxDataSourceManager.dsSpolky, new CRxDataSource(CRxDataSourceManager.dsSpolky, res.getString(R.string.indepenedent), "ds_magazine", CRxDataSource.DATATYPE_news, 0x08739f));
        m_dictDataSources.put(CRxDataSourceManager.dsSpolkyList, new CRxDataSource(CRxDataSourceManager.dsSpolkyList, res.getString(R.string.associations), "ds_usergroups", CRxDataSource.DATATYPE_places, 0x08739f));
        m_dictDataSources.put(CRxDataSourceManager.dsBiografProgram, new CRxDataSource(CRxDataSourceManager.dsBiografProgram, "Modřanský biograf", "ds_biograf", CRxDataSource.DATATYPE_events, 0xdb552d));
        m_dictDataSources.put(CRxDataSourceManager.dsCooltour, new CRxDataSource(CRxDataSourceManager.dsCooltour, res.getString(R.string.trips), "ds_landmarks", CRxDataSource.DATATYPE_places, 0x008000));
        m_dictDataSources.put(CRxDataSourceManager.dsWaste, new CRxDataSource(CRxDataSourceManager.dsWaste, res.getString(R.string.waste), "ds_waste", CRxDataSource.DATATYPE_places, 0x008000));
        m_dictDataSources.put(CRxDataSourceManager.dsSosContacts, new CRxDataSource(CRxDataSourceManager.dsSosContacts, res.getString(R.string.help), "ds_help", CRxDataSource.DATATYPE_places, 0x08739f));
        m_dictDataSources.put(CRxDataSourceManager.dsReportFault, new CRxDataSource(CRxDataSourceManager.dsReportFault, res.getString(R.string.report_fault), "ds_reportfault", CRxDataSource.DATATYPE_places, 0xb11a41));
        m_dictDataSources.put(CRxDataSourceManager.dsGame, new CRxDataSource(CRxDataSourceManager.dsGame, res.getString(R.string.game), "ds_game", CRxDataSource.DATATYPE_places, 0x603cbb));
        m_dictDataSources.put(CRxDataSourceManager.dsShops, new CRxDataSource(CRxDataSourceManager.dsShops, res.getString(R.string.shops), "ds_shop", CRxDataSource.DATATYPE_places, 0x0ab2b2));
        m_dictDataSources.put(CRxDataSourceManager.dsWork, new CRxDataSource(CRxDataSourceManager.dsWork, res.getString(R.string.work), "ds_work", CRxDataSource.DATATYPE_places, 0x0ab2b2));
        m_dictDataSources.put(CRxDataSourceManager.dsTraffic, new CRxDataSource(CRxDataSourceManager.dsTraffic, res.getString(R.string.traffix), "ds_roadblock", CRxDataSource.DATATYPE_places, 0xb11a41));

        // additional parameters
        CRxDataSource ds = m_dictDataSources.get(CRxDataSourceManager.dsRadDeska);
        ds.m_bFilterable = true;

        ds = m_dictDataSources.get(CRxDataSourceManager.dsRadEvents);
        ds.m_bFilterable = true;

        ds = m_dictDataSources.get(CRxDataSourceManager.dsSpolky);
        ds.m_bFilterable = true;

        ds = m_dictDataSources.get(CRxDataSourceManager.dsSpolkyList);
        ds.m_nRefreshFreqHours = 48;
        ds.m_sTestJsonFile = "/test_files/spolkyList";

        ds = m_dictDataSources.get(CRxDataSourceManager.dsBiografProgram);
        ds.m_nRefreshFreqHours = 48;
        ds.m_sShortTitle = "Biograf";

        ds = m_dictDataSources.get(CRxDataSourceManager.dsCooltour);
        ds.m_nRefreshFreqHours = 48;
        ds.m_sTestJsonFile = "/test_files/p12kultpamatky";

        ds = m_dictDataSources.get(CRxDataSourceManager.dsSosContacts);
        ds.m_nRefreshFreqHours = 48;
        ds.m_sTestJsonFile = "/test_files/sos";

        ds = m_dictDataSources.get(CRxDataSourceManager.dsWaste);
        ds.m_sTestJsonFile = "/test_files/dyn_waste";

        ds = m_dictDataSources.get(CRxDataSourceManager.dsReportFault);
        ds.m_nRefreshFreqHours = 1000;

        ds = m_dictDataSources.get(CRxDataSourceManager.dsGame);
        ds.m_nRefreshFreqHours = 1000;

        ds = m_dictDataSources.get(CRxDataSourceManager.dsShops);
        ds.m_nRefreshFreqHours = 48;
        ds.m_sTestJsonFile = "/test_files/p12shops";
        ds.m_bFilterAsParentView = true;

        ds = m_dictDataSources.get(CRxDataSourceManager.dsTraffic);
        ds.m_nRefreshFreqHours = 4;
    }

    //--------------------------------------------------------------------------
    File fileForDataSource(String id) {
        return new File(m_urlDocumentsDir, id + ".json");
    }

    //--------------------------------------------------------------------------
    void loadData() {
        for (Map.Entry<String, CRxDataSource> itemIt: m_dictDataSources.entrySet()) {
            CRxDataSource ds = itemIt.getValue();
            ds.loadFromJSON(fileForDataSource(ds.m_sId));

            // load test data in case we don't have any previously saved
            if (ds.m_arrItems.isEmpty() && ds.m_sTestJsonFile != null) {
                try {
                    ds.loadFromJSONStream(m_assetMan.open(ds.m_sTestJsonFile.substring(1) + ".json"));
                }
                catch (Exception e) { e.printStackTrace(); }
            }
        }
        loadFavorities();
    }

    //--------------------------------------------------------------------------
    void save(CRxDataSource dataSource) {
        dataSource.saveToJSON(fileForDataSource(dataSource.m_sId));
    }

    //--------------------------------------------------------------------------
    void setFavorite(String place, boolean set) {
        boolean bFound = m_setPlacesNotified.contains(place);

        if (set && !bFound) {
            m_setPlacesNotified.add(place);
            saveFavorities();
            MainActivity.resetAllNotifications();
        }
        else if (!set && bFound) {
            m_setPlacesNotified.remove(place);
            saveFavorities();
            MainActivity.resetAllNotifications();
        }
    }

    //--------------------------------------------------------------------------
    CRxEventRecord findFavorite(CRxEventRecord news) {
        String itemToFind = news.recordHash();
        for (CRxEventRecord rec: m_aSavedNews.m_arrItems) {
            if (rec.recordHash().equals(itemToFind)) {
                return rec;
            }
        }
        return null;
    }

    //--------------------------------------------------------------------------
    void setFavorite(CRxEventRecord news, boolean set) {
        boolean bFound = false;
        boolean bChanged = false;
        String itemToFind = news.recordHash();
        for (int i = 0; i < m_aSavedNews.m_arrItems.size(); i++) {
            CRxEventRecord rec = m_aSavedNews.m_arrItems.get(i);
            if (rec.recordHash().equals(itemToFind)) {
                bFound = true;
                if (!set) {
                    m_aSavedNews.m_arrItems.remove(i);
                    bChanged = true;
                }
                break;
            }
        }
        if (set && !bFound) {
            m_aSavedNews.m_arrItems.add(0, news);
            bChanged = true;
        }

        if (bChanged) {
            saveFavorities();
        }
    }

    //--------------------------------------------------------------------------
    void saveFavorities() {
        String sList = "";
        for (String sVal: m_setPlacesNotified)
        {
            if (!sList.isEmpty()) sList += "|";
            sList += sVal;
        }
        File urlPlaces = new File(m_urlDocumentsDir, "favPlaces.txt");
        try {
            OutputStreamWriter stream = new OutputStreamWriter(new FileOutputStream(urlPlaces));
            stream.write(sList);
            stream.close();
        } catch (Exception e) {
            Log.e("saveFavorities", "Saving favorite places failed: " + e.getMessage());
        }

        File urlNews = new File(m_urlDocumentsDir, "favNews.json");
        m_aSavedNews.saveToJSON(urlNews);
    }

    //--------------------------------------------------------------------------
    void loadFavorities() {
        File urlPlaces = new File(m_urlDocumentsDir, "favPlaces.txt");
        try {
            InputStream inputStream = new FileInputStream(urlPlaces);
            InputStreamReader inputStreamReader = new InputStreamReader(inputStream);
            BufferedReader bufferedReader = new BufferedReader(inputStreamReader);
            String receiveString = "";
            StringBuilder stringBuilder = new StringBuilder();

            while ((receiveString = bufferedReader.readLine()) != null) {
                stringBuilder.append(receiveString);
            }

            inputStream.close();
            String sLoaded = stringBuilder.toString();
            m_setPlacesNotified = new HashSet<String>(Arrays.asList(sLoaded.split("\\|")));
        } catch (Exception e) {
            Log.e("loadFavorities", "Loading favorite places failed: " + e.getMessage()); return;
        }

        File urlNews = new File(m_urlDocumentsDir, "favNews.json");
        m_aSavedNews.loadFromJSON(urlNews);
    }

    //--------------------------------------------------------------------------
    void showNetworkIndicator() {
        if (m_nNetworkIndicatorUsageCount == 0) {
            //UIApplication.shared.isNetworkActivityIndicatorVisible = true;
        }
        m_nNetworkIndicatorUsageCount += 1;
    }

    //--------------------------------------------------------------------------
    void hideNetworkIndicator() {
        if (m_nNetworkIndicatorUsageCount > 0) {
            m_nNetworkIndicatorUsageCount -= 1;
        }
        if (m_nNetworkIndicatorUsageCount == 0) {
            //UIApplication.shared.isNetworkActivityIndicatorVisible = false;
        }
    }

    //--------------------------------------------------------------------------
    void refreshAllDataSources(boolean force) {

        for (Map.Entry<String, CRxDataSource> dsIt: m_dictDataSources.entrySet()) {
            refreshDataSource(dsIt.getKey(), force);
        }
    }

    //--------------------------------------------------------------------------
    void refreshDataSource(String id, boolean force) {

        CRxDataSource ds = m_dictDataSources.get(id);
        if (ds == null) { return; }

        // check the last refresh date
        Date now = new Date();
        if (!force && ds.m_dateLastRefreshed != null  &&
                (now.getTime() - ds.m_dateLastRefreshed.getTime())/1000 < ds.m_nRefreshFreqHours*60*60) {
            if (ds.delegate != null)
                ds.delegate.dataSourceRefreshEnded(id, null);
            return;
        }

        if (id.equals(CRxDataSourceManager.dsRadNews)) {
            refreshStdJsonDataSource(id, "dyn_radAktual.json");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsRadEvents)) {
            refreshStdJsonDataSource(id, "dyn_events.php");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsRadDeska)) {
            refreshStdJsonDataSource(id, "dyn_radDeska.json");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsWork)) {
            refreshStdJsonDataSource(id, "dyn_kdejeprace.json");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsSpolky)) {
            refreshStdJsonDataSource(id, "dyn_spolky.php");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsBiografProgram)) {
            refreshStdJsonDataSource(id, "dyn_biograf.json");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsTraffic)) {
            refreshStdJsonDataSource(id, "dyn_doprava.json");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsSpolkyList)) {
            refreshStdJsonDataSource(id, "spolkyList.json");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsCooltour)) {
            refreshStdJsonDataSource(id, "p12kultpamatky.json");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsWaste)) {
            refreshStdJsonDataSource(id, "dyn_waste.json");
            return;

            /*if let path = Bundle.main.url(forResource: "/test_files/vokplaces", withExtension: "json") {
                ds.loadFromJSON(file: path);
                refreshWasteDataSource();
                ds.delegate?.dataSourceRefreshEnded(nil);
                return;
            }*/
        }
        else if (id.equals(CRxDataSourceManager.dsSosContacts)) {
            refreshStdJsonDataSource(id, "sos.json");
            return;
        }
        else if (id.equals(CRxDataSourceManager.dsShops)) {
            refreshStdJsonDataSource(id, "p12shops.json");
            return;
        }
    }

    //--------------------------------------------------------------------------
    // downloading daa from URL: http://stackoverflow.com/questions/24231680/loading-downloading-image-from-url-on-swift
    // async
    static abstract class DownloadCompletion {
        abstract void run(String sData, String sError);
    }
    void getDataFromUrl(final URL url, final DownloadCompletion completion) {
        Thread thread = new Thread(new Runnable(){
            @Override
            public void run(){
                String sError = null;
                String sData = null;
                try {
                    InputStream inStream;
                    if (url.toString().startsWith("file:///android_asset/"))
                        inStream = m_assetMan.open(url.toString().substring(22));
                    else
                        inStream = url.openStream();

                    DataInputStream stream = new DataInputStream(inStream);
                    BufferedInputStream bufferedReader = new BufferedInputStream(stream);

                    byte[] buffer = new byte[2048];
                    int bytesRead = 0;
                    ByteArrayOutputStream byteArray = new ByteArrayOutputStream();

                    while ((bytesRead = bufferedReader.read(buffer))!= -1) {
                        byteArray.write(buffer, 0, bytesRead);
                    }

                    stream.close();
                    sData = byteArray.toString("UTF-8");    // send to callee
                }
                catch (Exception e) {
                    sError = e.getMessage();
                }
                if (completion != null) {
                    try {
                        completion.run(sData, sError);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }
        });
        thread.start();
    }

    //--------------------------------------------------------------------------
    void refreshStdJsonDataSource(String sDsId, String url) {

        final CRxDataSource aDS = m_dictDataSources.get(sDsId);
        if (aDS == null) { return; }

        URL urlDownload = null;
        try {
            if (!g_bUseTestFiles) {
                if (url.startsWith("http")) {
                    urlDownload = new URL(url);
                }
                else {
                    urlDownload = new URL("https://dvanactka.info/own/p12/" + url);
                }
            }
            else if (aDS.m_sTestJsonFile != null) {
                urlDownload = new URL("file:///android_asset" + aDS.m_sTestJsonFile + ".json");
            }
            else
                return;
        }
        catch (Exception e) {
            Log.e("JSON", "refreshStdJsonDataSource exception: " + e.getMessage());
        }
        if (urlDownload == null) {
            if (aDS.delegate != null) aDS.delegate.dataSourceRefreshEnded(aDS.m_sId, "Cannot resolve URL");
            return;
        }

        aDS.m_bIsBeingRefreshed = true;
        showNetworkIndicator();

        getDataFromUrl(urlDownload, new DownloadCompletion() {
            @Override
            void run(String sData, String sError) {
                if (sData == null || sError != null)
                {
                    if (sError != null)
                        Log.e("JSON", sError);

                    new Handler(Looper.getMainLooper()).post(new Runnable() {   // run in main thread
                        @Override
                        public void run() {
                            aDS.m_bIsBeingRefreshed = false;
                            if (aDS.delegate != null) aDS.delegate.dataSourceRefreshEnded(aDS.m_sId, "Error when downloading data");
                            hideNetworkIndicator();
                        }
                    });
                    return;
                }
                // process the data
                aDS.loadFromJSONString(sData);

                new Handler(Looper.getMainLooper()).post(new Runnable() {   // run in main thread
                    @Override
                    public void run() {
                        aDS.sortNewsByDate();
                        aDS.m_dateLastRefreshed = new Date();
                        aDS.m_bIsBeingRefreshed = false;
                        save(aDS);
                        hideNetworkIndicator();
                        if (aDS.delegate != null) aDS.delegate.dataSourceRefreshEnded(aDS.m_sId, null);
                        if (delegate != null) delegate.dataSourceRefreshEnded(aDS.m_sId, null);     // to refresh unread count badge

                        if (aDS.m_sId.equals(CRxDataSourceManager.dsWaste))
                            MainActivity.resetAllNotifications();
                    }
                });
            }
        });
    }
}