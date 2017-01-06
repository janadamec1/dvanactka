package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ListView;

import java.text.Collator;
import java.util.ArrayList;
import java.util.Collections;

public class PlacesFilterCtl extends Activity {

    CRxDataSource m_aDataSource = null;
    ArrayList<String> m_arrFilter = new ArrayList<String>();

    public class PlacesFilterAdapter extends ArrayAdapter<String> {
        public PlacesFilterAdapter(Context context, ArrayList<String> array) {
            super(context, android.R.layout.simple_list_item_1, android.R.id.text1, array);
        }

        /*@Override
        public View getView(int position, View convertView, ViewGroup parent) {
            View view = super.getView(position, convertView, parent);
            String sValue = getItem(position);
            CheckedTextView tvName = (CheckedTextView)view.findViewById(android.R.id.text1);
            tvName.setText(sValue);

            String sDefVal = CRxFilterOptions.sharedInstance().m_sDistrict;
            boolean bChecked;
            if (position == 0)
                bChecked = (sDefVal == null || sDefVal.length() == 0);
            else
                bChecked = (sDefVal != null && sValue.equals(sDefVal));
            tvName.setChecked(bChecked);
            return view;
        }*/
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_places_filter_ctl);

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        if (sDataSource == null) return;
        m_aDataSource = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDataSource);
        if (m_aDataSource == null) return;

        setTitle(m_aDataSource.m_sTitle);

        // get the list of filter items
        for (CRxEventRecord rec: m_aDataSource.m_arrItems) {
            if (rec.m_sFilter != null) {
                if (!m_arrFilter.contains(rec.m_sFilter)) {
                    m_arrFilter.add(rec.m_sFilter);
                }
            }
        }
        Collator coll = Collator.getInstance(); // for sorting with locale
        coll.setStrength(Collator.PRIMARY);
        Collections.sort(m_arrFilter, coll);

        ListView lvList = (ListView)findViewById(R.id.listView);
        lvList.setAdapter(new PlacesFilterAdapter(this, m_arrFilter));
        lvList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id)
            {
                Intent intent = new Intent(PlacesFilterCtl.this, EventCtl.class);
                intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                intent.putExtra(MainActivity.EXTRA_PARENT_FILTER, (String)parent.getItemAtPosition(position));
                startActivity(intent);
            }
        });
    }
}
