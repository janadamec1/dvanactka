package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.os.Bundle;
import android.view.MenuItem;

public class ReportFaultCtl extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_report_fault_ctl);

        setTitle("  "); // empty action bar title


    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            // Respond to the action bar's Up/Home button
            case android.R.id.home:
                onBackPressed();        // go to the activity that brought user here, not to parent activity
                return true;
        }
        return super.onOptionsItemSelected(item);
    }
}
