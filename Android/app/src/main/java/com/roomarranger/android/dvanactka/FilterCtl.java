package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.CheckedTextView;
import android.widget.ListView;

import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;

public class FilterCtl extends Activity {

    CRxDataSource m_aDataSource = null;
    ArrayList<String> m_arrFilter = new ArrayList<String>();
    CRxDetailRefreshParentDelegate m_refreshParentDelegate = null;          // delegate of this activity

    public class FilterSourceAdapter extends ArrayAdapter<String> {
        FilterSourceAdapter(Context context, ArrayList<String> array) {
            super(context, R.layout.checked_text_view, android.R.id.text1, array);
        }

        @Override
        public View getView(int position, View convertView, ViewGroup parent) {
            View view = super.getView(position, convertView, parent);
            String sValue = getItem(position);
            CheckedTextView tvName = (CheckedTextView)view.findViewById(android.R.id.text1);
            tvName.setText(sValue);

            boolean bChecked = true;
            if (m_aDataSource.m_setFilter != null)
                bChecked = !m_aDataSource.m_setFilter.contains(sValue);
            tvName.setChecked(bChecked);
            return view;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_filter_ctl);

        m_refreshParentDelegate = EventCtl.g_CurrentRefreshDelegate;
        EventCtl.g_CurrentRefreshDelegate = null;

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        if (sDataSource == null) return;
        m_aDataSource = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDataSource);
        if (m_aDataSource == null) return;

        for (CRxEventRecord rec: m_aDataSource.m_arrItems) {
            if (rec.m_sFilter != null && !m_arrFilter.contains(rec.m_sFilter)) {
                m_arrFilter.add(rec.m_sFilter);
            }
        }

        Collator coll = Collator.getInstance(); // for sorting with locale
        coll.setStrength(Collator.PRIMARY);
        Collections.sort(m_arrFilter, coll);

        ListView lvList = (ListView)findViewById(R.id.listView);
        lvList.setAdapter(new FilterSourceAdapter(this, m_arrFilter));

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
