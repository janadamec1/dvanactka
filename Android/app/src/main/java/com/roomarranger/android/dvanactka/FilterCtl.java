package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.CheckedTextView;
import android.widget.ListView;

import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

public class FilterCtl extends Activity {

    CRxDataSource m_aDataSource = null;
    Set<String> m_setOut = new HashSet<String>();
    ArrayList<String> m_arrFilter = new ArrayList<String>();
    ArrayAdapter<String> m_adapter = null;

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

            boolean bChecked = !m_setOut.contains(sValue);
            tvName.setChecked(bChecked);

            tvName.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    CheckedTextView chk = (CheckedTextView)view;
                    String sChkValue = chk.getText().toString();
                    boolean bCheck = !chk.isChecked();
                    if (bCheck)
                        m_setOut.remove(sChkValue);
                    else
                        m_setOut.add(sChkValue);
                    chk.setChecked(bCheck);
                    notifyFilterChanged();
                }
            });
            return view;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_filter_ctl);

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        if (sDataSource == null) return;
        m_aDataSource = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDataSource);
        if (m_aDataSource == null) return;

        if (m_aDataSource.m_setFilter != null)
            m_setOut.addAll(m_aDataSource.m_setFilter);

        for (CRxEventRecord rec: m_aDataSource.m_arrItems) {
            if (rec.m_sFilter != null && !m_arrFilter.contains(rec.m_sFilter)) {
                m_arrFilter.add(rec.m_sFilter);
            }
        }

        Collator coll = Collator.getInstance(); // for sorting with locale
        coll.setStrength(Collator.PRIMARY);
        Collections.sort(m_arrFilter, coll);

        m_adapter = new FilterSourceAdapter(this, m_arrFilter);
        ListView lvList = (ListView)findViewById(R.id.listView);
        lvList.setAdapter(m_adapter);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_filter_ctl, menu);
        return true;
    }

    void notifyFilterChanged() {
        if (m_aDataSource != null) {
            m_aDataSource.m_setFilter = m_setOut;
            CRxDataSourceManager.sharedInstance().save(m_aDataSource);
        }
        setResult(RESULT_OK);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            // Respond to the action bar's Up/Home button
            case android.R.id.home:
                onBackPressed();        // go to the activity that brought user here, not to parent activity
                return true;

            case R.id.action_all: {
                m_setOut.clear();
                if (m_adapter != null)
                    m_adapter.notifyDataSetChanged();
                notifyFilterChanged();
                return true;
            }
            case R.id.action_none: {
                m_setOut.clear();
                if (m_arrFilter != null)
                    m_setOut.addAll(m_arrFilter);
                if (m_adapter != null)
                    m_adapter.notifyDataSetChanged();
                notifyFilterChanged();
                return true;
            }
        }
        return super.onOptionsItemSelected(item);
    }
}
