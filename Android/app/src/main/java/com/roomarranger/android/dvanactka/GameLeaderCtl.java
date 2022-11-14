package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ListView;
import android.widget.ProgressBar;
import android.widget.TextView;

import java.net.URL;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Locale;

/*
 Copyright 2017-2018 Jan Adamec.

 This file is part of "Dvanactka".

 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.

 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
*/

public class GameLeaderCtl extends Activity {

    static class CRxBoardItem {
        int m_iPlaceFrom = 0;
        int m_iPlaceTo = 0;
        int m_iScore;

        CRxBoardItem(int score) {
            super();
            m_iScore = score;
        }
    }

    ArrayList<CRxBoardItem> m_arrItems = new ArrayList<>();
    String m_sMyUuid = null;
    int m_iMyScore = 0;
    boolean m_bLoading = true;
    BaseAdapter m_listAdapter;

    static class BoardItemViewHolder {
        TextView lbName, lbScore;
        ProgressBar spinner;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_game_leader_ctl);

        m_iMyScore = CRxGame.shared.m_iPoints;
        CRxDataSource aDS = CRxGame.dataSource();
        if (aDS != null)  {
            m_sMyUuid = aDS.m_sUuid;
        }

        m_listAdapter = new BaseAdapter()
        {
            @Override
            public int getCount()
            {
                return m_bLoading ? 1 : m_arrItems.size();
            }

            @Override
            public Object getItem(int position)
            {
                return null;
            }

            @Override
            public long getItemId(int position)
            {
                return position;
            }

            @Override
            public View getView(int position, View convertView, ViewGroup parent)
            {
                BoardItemViewHolder cell;
                if (convertView == null)
                {
                    LayoutInflater inflater = getLayoutInflater();
                    convertView = inflater.inflate(R.layout.list_item_game_board, parent, false);

                    cell = new BoardItemViewHolder();
                    cell.lbName = convertView.findViewById(R.id.name);
                    cell.lbScore = convertView.findViewById(R.id.playerScore);
                    cell.spinner = convertView.findViewById(R.id.spinner);
                    convertView.setTag(cell);
                }
                else
                    cell = (BoardItemViewHolder) convertView.getTag();

                if (m_bLoading) {
                    cell.lbName.setText(R.string.downloading_data);
                    cell.lbScore.setText("");
                    cell.spinner.setVisibility(View.VISIBLE);
                    return convertView;
                }
                CRxBoardItem item = m_arrItems.get(position);

                String sPlace;
                if (item.m_iPlaceFrom != item.m_iPlaceTo) {
                    sPlace = String.format(Locale.US, "%d. - %d.", item.m_iPlaceFrom, item.m_iPlaceTo);
                }
                else {
                    sPlace = String.format(Locale.US, "%d.", item.m_iPlaceFrom);
                }
                boolean bIsPlayer = (item.m_iScore == m_iMyScore);
                if (bIsPlayer) {
                    sPlace += " <-- " + getString(R.string.game_you);
                }
                cell.lbName.setText(sPlace);
                cell.lbScore.setText(String.format(Locale.US, "%d XP", item.m_iScore));

                int cl = bIsPlayer ? Color.WHITE : Color.parseColor("#d9d9d9");
                cell.lbName.setTextColor(cl);
                cell.lbScore.setTextColor(cl);
                cell.spinner.setVisibility(View.GONE);
                return convertView;
            }
        };
        ListView lvList = findViewById(R.id.listView);
        lvList.setAdapter(m_listAdapter);

        URL urlDownload = null;
        try {
            if (CRxAppDefinition.shared.m_sServerDataBaseUrl != null)
                urlDownload = new URL(CRxAppDefinition.shared.m_sServerDataBaseUrl + "game_leaders.txt");
        }
        catch (Exception e) {
            Log.e("GAME", "download leaderboard exception: " + e.getMessage());
        }
        if (urlDownload == null) {
            return;
        }

        CRxDataSourceManager.getDataFromUrl(urlDownload, new CRxDataSourceManager.DownloadCompletion() {
            @Override
            void run(String sData, String sError) {
                if (sData == null || sError != null) {
                    if (sError != null)
                        Log.e("JSON", sError);

                    // run in main thread
                    new Handler(Looper.getMainLooper()).post(() -> showDownloadError());
                    return;
                }
                // process the data
                loadTableFrom(sData);

                // run in main thread
                new Handler(Looper.getMainLooper()).post(() -> {
                    m_bLoading = false;
                    m_listAdapter.notifyDataSetChanged();
                });
            }
        });
    }

    //---------------------------------------------------------------------------
    void loadTableFrom(String sData) {
        boolean bPlayerFound = false;
        ArrayList<CRxBoardItem> arrNewItems = new ArrayList<>();
        String[] lines = sData.split("\\r?\\n");
        for (String line: lines) {
            String[] lineItems = line.split("\\|");
            if (lineItems.length < 2) {
                continue;
            }
            try {
                int iScore = Integer.parseInt(lineItems[1]);
                CRxBoardItem aNewItem = new CRxBoardItem(iScore);
                arrNewItems.add(aNewItem);

                if (m_sMyUuid != null && m_sMyUuid.equals(lineItems[0])) {
                    bPlayerFound = true;
                }
            } catch (NumberFormatException ignored) {}
        }
        if (!bPlayerFound && m_iMyScore > 0) {
            arrNewItems.add(new CRxBoardItem(m_iMyScore));
        }

        m_arrItems.clear();
        if (arrNewItems.size() > 0) {
            // sort by score
            Collections.sort(arrNewItems, (t0, t1) -> {
                if (t0.m_iScore == t1.m_iScore) return 0;
                else if (t0.m_iScore > t1.m_iScore) return -1;
                else return 1;
            });
            // calc places and filter out places with same score
            ArrayList<CRxBoardItem> arrFilteredItems = new ArrayList<>();
            int iPrevScore = 99999999;
            for (int i = 0; i < arrNewItems.size(); i++) {
                CRxBoardItem aItem = arrNewItems.get(i);
                if (aItem.m_iScore != iPrevScore) {
                    aItem.m_iPlaceFrom = i+1;
                    iPrevScore = aItem.m_iScore;
                    arrFilteredItems.add(aItem);
                }
            }
            // set shared place number
            int iPlayerIdx = 0;
            for (int i = 0; i < arrFilteredItems.size(); i++) {
                CRxBoardItem aItem = arrFilteredItems.get(i);
                if (aItem.m_iScore == m_iMyScore) {
                    iPlayerIdx = i;
                }
                if (i < arrFilteredItems.size()-1) {
                    aItem.m_iPlaceTo = arrFilteredItems.get(i+1).m_iPlaceFrom - 1;
                }
                else {  // last item
                    aItem.m_iPlaceTo = arrNewItems.size();
                }
            }
            // show only a few records above and below the player (iPlayerIdx)
            for (int i = 0; i < arrFilteredItems.size(); i++) {
                if ((iPlayerIdx <= 5 && i < 10)           // at the top, show first 10 items)
                        || (iPlayerIdx > 4 && (i==0 || Math.abs(i-iPlayerIdx) <= 4))) {   // below, show first and then 9 around player
                    m_arrItems.add(arrFilteredItems.get(i));
                }
            }
        }
    }

    //---------------------------------------------------------------------------
    void showDownloadError() {
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setMessage(R.string.error_downloading_data);
        builder.setOnCancelListener(dialogInterface -> {
            onBackPressed();    // navigate back to GameCtl
        });
        builder.create().show();
    }
}
