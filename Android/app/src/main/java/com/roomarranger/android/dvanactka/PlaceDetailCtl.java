package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.os.Bundle;

public class PlaceDetailCtl extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_place_detail_ctl);

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        String sRecordHash = getIntent().getStringExtra(MainActivity.EXTRA_EVENT_RECORD);
        if (sDataSource == null || sRecordHash == null) return;
        CRxDataSource aDs = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDataSource);
        if (aDs == null) return;

    }
}
