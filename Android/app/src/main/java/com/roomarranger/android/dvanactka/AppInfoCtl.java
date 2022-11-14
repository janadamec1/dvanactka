package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.TextView;
import android.widget.Toast;

/*
 Copyright 2018 Jan Adamec.

 This file is part of "Dvanactka".

 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.

 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
 */

public class AppInfoCtl extends Activity {

    CheckBox m_chkWifi;
    CheckBox m_chkDebugUseTestData;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_app_info_ctl);

        m_chkWifi = (CheckBox)findViewById(R.id.chkWifi);
        SharedPreferences sharedPref = getSharedPreferences(MainActivity.PREFERENCES_FILE, Context.MODE_PRIVATE);
        m_chkWifi.setChecked(sharedPref.getBoolean("wifiDataOnly", false));
        m_chkWifi.setOnCheckedChangeListener((compoundButton, bChecked) -> {
            SharedPreferences sharedPref2 = getSharedPreferences(MainActivity.PREFERENCES_FILE, Context.MODE_PRIVATE);
            sharedPref2.edit().putBoolean("wifiDataOnly", bChecked).apply();
        });

        m_chkDebugUseTestData = (CheckBox) findViewById(R.id.chkDebugUseTestData);
        if (BuildConfig.DEBUG) {
            m_chkDebugUseTestData.setChecked(CRxDataSourceManager.g_bUseTestFiles);
            m_chkDebugUseTestData.setOnCheckedChangeListener((compoundButton, bChecked) -> {
                CRxDataSourceManager.g_bUseTestFiles = bChecked;
                CRxDataSourceManager.shared.refreshAllDataSources(true, true, AppInfoCtl.this);
            });
        }
        else {
            m_chkDebugUseTestData.setVisibility(View.INVISIBLE);
        }

        if (CRxAppDefinition.shared.m_sCopyright != null) {
            TextView lbCopyright = (TextView)findViewById(R.id.copyright);
            lbCopyright.setText(CRxAppDefinition.shared.m_sCopyright);
        }

        Button btnEmail = (Button)findViewById(R.id.btnEmail);
        if (CRxAppDefinition.shared.m_sContactEmail == null) {
            btnEmail.setVisibility(View.GONE);
        }
        else {
            btnEmail.setText(CRxAppDefinition.shared.m_sContactEmail);
            btnEmail.setOnClickListener(view -> {
                Intent intent = new Intent(Intent.ACTION_SEND);
                intent.setType("message/rfc822");
                intent.putExtra(Intent.EXTRA_EMAIL, new String[]{CRxAppDefinition.shared.m_sContactEmail});

                String sAppName = "CityApp";
                if (CRxAppDefinition.shared.m_sTitle != null)
                    sAppName = CRxAppDefinition.shared.m_sTitle;
                intent.putExtra(Intent.EXTRA_SUBJECT, "Aplikace " + sAppName + " (Android)");

                try {
                    startActivity(Intent.createChooser(intent, getString(R.string.send_mail)));
                } catch (android.content.ActivityNotFoundException ex) {
                    Toast.makeText(AppInfoCtl.this, "There are no email clients installed.", Toast.LENGTH_SHORT).show();
                }
            });
        }
    }
}
