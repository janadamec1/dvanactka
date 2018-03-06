package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.TextView;
import android.widget.Toast;

public class AppInfoCtl extends Activity {

    CheckBox m_chkWifi;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_app_info_ctl);

        m_chkWifi = (CheckBox)findViewById(R.id.chkWifi);
        SharedPreferences sharedPref = getSharedPreferences(MainActivity.PREFERENCES_FILE, Context.MODE_PRIVATE);
        m_chkWifi.setChecked(sharedPref.getBoolean("wifiDataOnly", false));
        m_chkWifi.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton compoundButton, boolean bChecked) {
                SharedPreferences sharedPref2 = getSharedPreferences(MainActivity.PREFERENCES_FILE, Context.MODE_PRIVATE);
                sharedPref2.edit().putBoolean("wifiDataOnly", bChecked).apply();
            }
        });

        if (CRxAppDefinition.shared.m_sCopyright != null) {
            TextView lbCopyright = (TextView)findViewById(R.id.copyright);
            lbCopyright.setText(CRxAppDefinition.shared.m_sCopyright);
        }

        Button btnEmail = (Button)findViewById(R.id.btnEmail);
        if (CRxAppDefinition.shared.m_sContactEmail == null)
            btnEmail.setVisibility(View.GONE);
        else
            btnEmail.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
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
                }
            });
    }
}
