package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseExpandableListAdapter;
import android.widget.Button;
import android.widget.ExpandableListView;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.location.LocationListener;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationServices;

import java.text.DateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

public class EventCtl extends Activity implements GoogleApiClient.ConnectionCallbacks, GoogleApiClient.OnConnectionFailedListener, LocationListener {

    CRxDataSource m_aDataSource = null;
    String m_sParentFilter = null;          // show only items with this filter (for ds with filterAsParentView)

    HashMap<String, ArrayList<CRxEventRecord>> m_orderedItems = new HashMap<String, ArrayList<CRxEventRecord>>();
    ArrayList<String> m_orderedCategories = new ArrayList<String>();    // sorted category local names
    boolean m_bUserLocationAcquired = false;
    Location m_coordLast = null;
    GoogleApiClient m_GoogleApiClient = null;
    LocationRequest m_LocationRequest;
    //SwipeRefreshLayout m_refreshControl;
    Toast m_refreshMessage;

    ExpandListAdapter m_adapter;

    static class NewsListItemHolder {
        TextView m_lbTitle;
        TextView m_lbText;
        TextView m_lbDate;
        Button m_btnWebsite;
        ImageButton m_btnFavorite;
        ImageButton m_btnAction;
        Button m_btnBuy;
        Button m_btnAddToCalendar;
        ImageView m_imgIcon;
    }

    public class ExpandListAdapter extends BaseExpandableListAdapter {
        private Context m_context;

        ExpandListAdapter(Context context) {
            super();
            m_context = context;
        }

        public int getGroupCount() {
            return m_orderedCategories.size();
        }

        public long getGroupId(int groupPosition) {
            return groupPosition;
        }

        public Object getGroup(int groupPosition) {
            return null;
        }

        public int getChildrenCount(int groupPosition) {
            ArrayList<CRxEventRecord> arr = m_orderedItems.get(m_orderedCategories.get(groupPosition));
            if (arr != null)
                return arr.size();
            else
                return 0;
        }

        public View getGroupView(int groupPosition, boolean isLastChild, View view,
                                 ViewGroup parent)
        {
            ExpandableListView pListView = (ExpandableListView)parent;  // expand the group
            pListView.expandGroup(groupPosition);

            if (view == null) {
                LayoutInflater inInflater = (LayoutInflater) m_context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                view = inInflater.inflate(R.layout.group_header, null);
            }
            TextView tvName = (TextView) view.findViewById(android.R.id.text1);
            tvName.setText(m_orderedCategories.get(groupPosition));
            if (m_orderedCategories.size() < 2)
                view.setVisibility(View.GONE);
            return view;
        }

        public Object getChild(int groupPosition, int childPosition) {
            return null;
        }

        public long getChildId(int groupPosition, int childPosition) {
            return childPosition;
        }

        public View getChildView(int groupPosition, int childPosition, boolean isLastChild, View view,
                                 ViewGroup parent) {

            NewsListItemHolder cell;
            if (view == null) {
                LayoutInflater inInflater = (LayoutInflater)m_context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                int resId = R.layout.list_item_places;
                switch (m_aDataSource.m_eType) {
                    case CRxDataSource.DATATYPE_news: resId = R.layout.list_item_news; break;
                    case CRxDataSource.DATATYPE_events: resId = R.layout.list_item_events; break;
                    case CRxDataSource.DATATYPE_places: resId = R.layout.list_item_places; break;
                }
                view = inInflater.inflate(resId, null);//android.R.layout.simple_list_item_2, null);//R.layout.list_item_places, null);

                cell = new NewsListItemHolder();
                cell.m_lbTitle = (TextView)view.findViewById(R.id.title);
                cell.m_lbText = (TextView)view.findViewById(R.id.text);

                switch (m_aDataSource.m_eType) {
                    case CRxDataSource.DATATYPE_news:
                        cell.m_btnFavorite = (ImageButton)view.findViewById(R.id.btnFavorite);
                        cell.m_lbDate = (TextView)view.findViewById(R.id.date);
                        cell.m_btnWebsite = (Button)view.findViewById(R.id.btnWebsite);
                        cell.m_btnAction = (ImageButton)view.findViewById(R.id.btnAction);
                        break;
                    case CRxDataSource.DATATYPE_events:
                        cell.m_lbDate = (TextView)view.findViewById(R.id.date);
                        cell.m_btnWebsite = (Button)view.findViewById(R.id.btnWebsite);
                        //cell.m_btnAddToCalendar = (Button)view.findViewById(R.id.btnAddToCalendar);
                        break;
                    case CRxDataSource.DATATYPE_places:
                        cell.m_imgIcon = (ImageView)view.findViewById(R.id.icon);
                        break;
                }
                view.setTag(cell);
            } else {
                cell = (NewsListItemHolder)view.getTag();
            }

            ArrayList<CRxEventRecord> arr = m_orderedItems.get(m_orderedCategories.get(groupPosition));
            CRxEventRecord rec = arr.get(childPosition);

            // fill cell contents
            cell.m_lbTitle.setText(rec.m_sTitle);
            switch (m_aDataSource.m_eType) {
                case CRxDataSource.DATATYPE_news:
                    if (rec.m_sText != null)
                        cell.m_lbText.setText(rec.m_sText);
                    break;

                case CRxDataSource.DATATYPE_events:
                    break;

                case CRxDataSource.DATATYPE_places:
                    if (rec.m_sText != null)
                        cell.m_lbText.setText(rec.m_sText);
                    int iIcon = CRxCategory.categoryIconName(rec.m_eCategory);
                    if (iIcon != -1)
                        cell.m_imgIcon.setImageDrawable(getDrawable(iIcon));
                    cell.m_imgIcon.setVisibility(iIcon != -1 ? View.VISIBLE : View.GONE);
                    break;
            }
            return view;
        }

        public boolean hasStableIds() {
            return true;
        }

        public boolean isChildSelectable(int arg0, int arg1) {
            return true;
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_event_ctl);

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        if (sDataSource == null) return;
        m_aDataSource = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDataSource);
        if (m_aDataSource == null) return;
        m_sParentFilter = getIntent().getStringExtra(MainActivity.EXTRA_PARENT_FILTER);

        if (m_sParentFilter != null) {
            setTitle(m_sParentFilter);
        }
        else {
            setTitle(m_aDataSource.m_sTitle);
        }

        setRecordsDistance();
        sortRecords();

        ExpandableListView ExpandList = (ExpandableListView)findViewById(R.id.ExpList);
        m_adapter = new ExpandListAdapter(this);
        ExpandList.setAdapter(m_adapter);
        if (m_aDataSource.m_eType == CRxDataSource.DATATYPE_places) {
            ExpandList.setOnChildClickListener(new ExpandableListView.OnChildClickListener() {
                @Override
                public boolean onChildClick(ExpandableListView expandableListView, View view, int groupPosition, int childPosition, long id) {
                    ArrayList<CRxEventRecord> arr = m_orderedItems.get(m_orderedCategories.get(groupPosition));
                    CRxEventRecord rec = arr.get(childPosition);
                    Intent intent = new Intent(EventCtl.this, PlaceDetailCtl.class);
                    intent.putExtra(MainActivity.EXTRA_EVENT_RECORD, m_aDataSource.m_sId);
                    intent.putExtra(MainActivity.EXTRA_EVENT_RECORD, rec.recordHash());
                    startActivity(intent);
                    return false;
                }
            });

            m_GoogleApiClient = new GoogleApiClient.Builder(this)
                    .addConnectionCallbacks(this)
                    .addOnConnectionFailedListener(this)
                    .addApi(LocationServices.API)
                    .build();

            m_LocationRequest = new LocationRequest();
            m_LocationRequest.setInterval(10000);
            m_LocationRequest.setFastestInterval(5000);
            m_LocationRequest.setPriority(LocationRequest.PRIORITY_HIGH_ACCURACY);
        }
    }

    //--------------------------------------------------------------------------
    void sortRecords() {
        CRxDataSource ds = m_aDataSource;
        if (ds == null) return;

        m_orderedItems.clear();
        m_orderedCategories.clear();

        DateFormat df = DateFormat.getDateTimeInstance(DateFormat.FULL, 0);

        Calendar c = Calendar.getInstance();
        Date today = c.getTime();

        // first add objects to groups
        for (CRxEventRecord rec: ds.m_arrItems) {
            // favorities
            if (ds.m_eType == CRxDataSource.DATATYPE_news) {
                rec.m_bMarkFavorite = (CRxDataSourceManager.sharedInstance().findFavorite(rec) != null);

            } else if (ds.m_eType == CRxDataSource.DATATYPE_places) {
                rec.m_bMarkFavorite = CRxDataSourceManager.sharedInstance().m_setPlacesNotified.contains(rec.m_sTitle);
            }

            // filter
            if (ds.m_bFilterable) {
                if (ds.m_setFilter != null && rec.m_sFilter != null)
                {
                    if (ds.m_setFilter.contains(rec.m_sFilter) ){
                        continue;   // skip this record
                    }
                }
            }
            if (ds.m_bFilterAsParentView) {
                if (rec.m_sFilter != null && m_sParentFilter != null)
                {
                    if (!rec.m_sFilter.equals(m_sParentFilter)) {
                        continue;
                    }
                }
            }

            // categories
            String sCatName = "";
            switch (ds.m_eType) {
            case CRxDataSource.DATATYPE_news: break;    // one category for news

            case CRxDataSource.DATATYPE_places:
                if (ds.m_bGroupByCategory) {
                    sCatName = CRxCategory.categoryLocalName(rec.m_eCategory, this);
                }
                break;

            case CRxDataSource.DATATYPE_events:   // use date as category
                if (rec.m_aDate == null) {
                    continue;    // remove records without date
                }
                if (rec.m_aDate.before(today) && rec.m_aDateTo != null && rec.m_aDateTo.after(today)) {
                    sCatName = getString(R.string.multi_day_events);
                }
                else if (rec.m_aDate.before(today)) {   // do not show old events
                    continue;
                }
                else {
                    sCatName = df.format(rec.m_aDate);
                }
                break;
            }
            // categories
            if (!m_orderedItems.containsKey(sCatName)) {
                ArrayList<CRxEventRecord> arr = new ArrayList<CRxEventRecord>();
                arr.add(rec);
                m_orderedItems.put(sCatName, arr);   // new category
                m_orderedCategories.add(sCatName);
            }
            else {
                ArrayList<CRxEventRecord> arr = m_orderedItems.get(sCatName);
                arr.add(rec);  // into existing
            }
        }

        // now sort each group by distance (places) or date (events, news)
        for (Map.Entry<String, ArrayList<CRxEventRecord>> groupIt: m_orderedItems.entrySet()) {
            ArrayList<CRxEventRecord> arr = groupIt.getValue();
            switch (ds.m_eType) {
                case CRxDataSource.DATATYPE_news:
                    Collections.sort(arr, new Comparator<CRxEventRecord>() {
                        @Override
                        public int compare(CRxEventRecord t0, CRxEventRecord t1)
                        {
                            return t0.m_aDate.after(t1.m_aDate) ? 1 : -1;
                        }
                    });
                    break;
                case CRxDataSource.DATATYPE_events:
                    Collections.sort(arr, new Comparator<CRxEventRecord>() {
                        @Override
                        public int compare(CRxEventRecord t0, CRxEventRecord t1)
                        {
                            return t0.m_aDate.before(t1.m_aDate) ? 1 : -1;
                        }
                    });
                    break;
                case CRxDataSource.DATATYPE_places:
                    Collections.sort(arr, new Comparator<CRxEventRecord>() {
                        @Override
                        public int compare(CRxEventRecord t0, CRxEventRecord t1)
                        {
                            if (t0.m_bMarkFavorite != t1.m_bMarkFavorite)        // show favorite first
                                return t0.m_bMarkFavorite ? -1 : 1;
                            return t0.m_distFromUser < t1.m_distFromUser ? -1 : 1;
                        }
                    });
                    break;
            }
        }

        // remember last item shown
        if (ds.m_eType == CRxDataSource.DATATYPE_news && !ds.m_sId.equals(CRxDataSourceManager.dsSavedNews)) {
            if (ds.m_arrItems.size() > 0) {
                String sNewRecHash = ds.m_arrItems.get(0).recordHash();
                if (!sNewRecHash.equals(ds.m_sLastItemShown)) { // resave only when something changed
                    ds.m_sLastItemShown = sNewRecHash;
                    CRxDataSourceManager.sharedInstance().save(ds);
                }
            }
        }
    }

    //--------------------------------------------------------------------------
    void setRecordsDistance() {
        CRxDataSource ds = m_aDataSource;
        if (ds == null) return;

        if (!m_bUserLocationAcquired || m_coordLast == null) {
            return;
        }
        for (CRxEventRecord rec : ds.m_arrItems) {
            if (rec.m_aLocation != null) {
                rec.m_distFromUser = rec.m_aLocation.distanceTo(m_coordLast);
            }
        }
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

    @Override
    protected void onStart()
    {
        super.onStart();
        if (m_GoogleApiClient != null)
            m_GoogleApiClient.connect();
    }

    @Override
    protected void onPause()
    {
        super.onPause();
        stopLocationUpdates();
    }

    @Override
    public void onResume()
    {
        super.onResume();
        if (m_GoogleApiClient != null && m_GoogleApiClient.isConnected())
            startLocationUpdates();
    }

    @Override
    public void onConnected(Bundle connectionHint) {

        //Toast.makeText(this, "Connected", Toast.LENGTH_SHORT).show();
        //if (servicesConnected())
        {
            Location aLastLocation = LocationServices.FusedLocationApi.getLastLocation(m_GoogleApiClient);
            if (aLastLocation != null)
            {
                m_coordLast = aLastLocation;
                m_bUserLocationAcquired = true;
                updateListWhenLocationChanged();

            }
            startLocationUpdates();
        }
    }

    protected void startLocationUpdates() {
        try {
            LocationServices.FusedLocationApi.requestLocationUpdates(m_GoogleApiClient, m_LocationRequest, this);
        }
        catch(Exception e){
        }
    }

    protected void stopLocationUpdates() {
        try {
            LocationServices.FusedLocationApi.removeLocationUpdates(m_GoogleApiClient, this);
        }
        catch(Exception e){
        }
    }

    void updateListWhenLocationChanged()
    {
        // reorder list of VOKs and show distance to current location
        setRecordsDistance();
        sortRecords();
        if (m_adapter != null)
            m_adapter.notifyDataSetChanged();
    }

    @Override
    public void onConnectionSuspended(int i) {
        Toast.makeText(this, "Google Play Services disconnected. Please re-connect.",
                Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onConnectionFailed(ConnectionResult connectionResult) {
        Toast.makeText(this, "Connection to Google Play Services failed.",
                Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onLocationChanged(Location location) {
        m_coordLast = location;
        m_bUserLocationAcquired = true;
        updateListWhenLocationChanged();
    }
}
