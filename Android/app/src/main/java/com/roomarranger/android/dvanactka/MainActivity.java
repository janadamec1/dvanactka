package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.res.AssetManager;
import android.content.res.Resources;
import android.graphics.drawable.ColorDrawable;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;

public class MainActivity extends Activity implements CRxDataSourceRefreshDelegate
{
    ArrayList<String> m_arrSources = new ArrayList<String>();    // data source ids in order they should appear in the collection

    public static final String EXTRA_DATASOURCE = "com.roomarranger.dvanactka.DATASOURCE";
    public static final String EXTRA_PARENT_FILTER = "com.roomarranger.dvanactka.PARENT_FILTER";
    public static final String EXTRA_EVENT_RECORD = "com.roomarranger.dvanactka.EVENT_RECORD";

    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // from AppDelegate.swift
        CRxDataSourceManager dsm = CRxDataSourceManager.sharedInstance();
        dsm.defineDatasources(this);
        dsm.loadData();
        dsm.refreshAllDataSources(false);
        //dsm.refreshDataSource(CRxDataSourceManager.dsSosContacts, true);
        //application.applicationIconBadgeNumber = 0;
        CRxGame.sharedInstance.init(this);
        CRxGame.sharedInstance.reinit();

        // from ViewController.swift
        m_arrSources.add(CRxDataSourceManager.dsRadNews);
        m_arrSources.add(CRxDataSourceManager.dsSpolky);
        m_arrSources.add(CRxDataSourceManager.dsRadEvents);
        m_arrSources.add(CRxDataSourceManager.dsBiografProgram);
        m_arrSources.add(CRxDataSourceManager.dsShops);
        m_arrSources.add(CRxDataSourceManager.dsWork);
        m_arrSources.add(CRxDataSourceManager.dsWaste);
        m_arrSources.add(CRxDataSourceManager.dsReportFault);
        m_arrSources.add(CRxDataSourceManager.dsRadDeska);
        m_arrSources.add(CRxDataSourceManager.dsTraffic);
        m_arrSources.add(CRxDataSourceManager.dsCooltour);
        m_arrSources.add(CRxDataSourceManager.dsSosContacts);
        m_arrSources.add(CRxDataSourceManager.dsGame);
        CRxDataSourceManager.sharedInstance().delegate = this;

        try {
            getActionBar().setBackgroundDrawable(new ColorDrawable(getResources().getColor(R.color.colorActionBarBkg)));
        } catch (Exception e) {}

        GridView gridview = (GridView)findViewById(R.id.gridview);
        gridview.setAdapter(new ImageAdapter(this, m_arrSources));

        gridview.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            public void onItemClick(AdapterView<?> parent, View v,
                                    int position, long id) {
                String sDsSelected = m_arrSources.get(position);
                CRxDataSource aDS = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDsSelected);

                Intent intent = null;
                if (sDsSelected.equals(CRxDataSourceManager.dsReportFault)) {
                    //performSegue(withIdentifier: "segueReportFault", sender: self);
                }
                else if (sDsSelected.equals(CRxDataSourceManager.dsGame)) {
                    intent = new Intent(MainActivity.this, GameCtl.class);
                }
                else if (aDS != null && aDS.m_bFilterAsParentView) {
                    intent = new Intent(MainActivity.this, PlacesFilterCtl.class);
                    intent.putExtra(MainActivity.EXTRA_DATASOURCE, sDsSelected);
                }
                else {
                    intent = new Intent(MainActivity.this, EventCtl.class);
                    intent.putExtra(MainActivity.EXTRA_DATASOURCE, sDsSelected);
                }
                if (intent != null)
                    startActivity(intent);
            }
        });
    }

    static class CollectionViewHolder {
        ImageView imgIcon;
        TextView lbName;
    }

    public class ImageAdapter extends BaseAdapter {
        private Context m_Context;
        private ArrayList<String> m_list;

        ImageAdapter(Context c, ArrayList<String> list) {
            m_Context = c;
            m_list = list;
        }

        public int getCount() { return m_list.size(); }
        public Object getItem(int position) { return null;}
        public long getItemId(int position) { return 0; }

        // create a new ImageView for each item referenced by the Adapter
        public View getView(int position, View convertView, ViewGroup parent) {
            CollectionViewHolder cell;
            if (convertView == null) {
                LayoutInflater inflater = getLayoutInflater();
                convertView = inflater.inflate(R.layout.cell_main_collection, parent, false);
                //convertView.setLayoutParams(new GridView.LayoutParams(85, 105));

                cell = new CollectionViewHolder();
                cell.lbName = (TextView)convertView.findViewById(R.id.textView);
                cell.imgIcon = (ImageView)convertView.findViewById(R.id.imageView);
                convertView.setTag(cell);
            } else {
                cell = (CollectionViewHolder)convertView.getTag();
            }

            CRxDataSource ds = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(m_list.get(position));
            if (ds != null) {
                int iconId = m_Context.getResources().getIdentifier(ds.m_sIcon, "drawable", m_Context.getPackageName());
                cell.imgIcon.setImageResource(iconId);
                if (ds.m_sShortTitle != null)
                    cell.lbName.setText(ds.m_sShortTitle);
                else
                    cell.lbName.setText(ds.m_sTitle);
            }
            return convertView;
        }
    }

    public void dataSourceRefreshEnded(String error) {
        // TODO - refresh badge
    }

}
