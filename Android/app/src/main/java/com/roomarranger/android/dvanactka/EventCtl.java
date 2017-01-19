package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Paint;
import android.location.Location;
import android.net.Uri;
import android.os.Bundle;
import android.provider.CalendarContract;
import android.support.v4.widget.SwipeRefreshLayout;
import android.text.Spannable;
import android.text.SpannableString;
import android.view.LayoutInflater;
import android.view.Menu;
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

import com.google.android.gms.analytics.HitBuilders;
import com.google.android.gms.analytics.Tracker;
import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.location.LocationListener;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationServices;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

interface CRxDetailRefreshParentDelegate {
    void detailRequestsRefresh();
}

public class EventCtl extends Activity implements GoogleApiClient.ConnectionCallbacks, GoogleApiClient.OnConnectionFailedListener, LocationListener,
        CRxDataSourceRefreshDelegate, CRxDetailRefreshParentDelegate, CRxFilterChangeDelegate, SwipeRefreshLayout.OnRefreshListener {

    CRxDataSource m_aDataSource = null;
    String m_sParentFilter = null;          // show only items with this filter (for ds with filterAsParentView)

    HashMap<String, ArrayList<CRxEventRecord>> m_orderedItems = new HashMap<String, ArrayList<CRxEventRecord>>();
    ArrayList<String> m_orderedCategories = new ArrayList<String>();    // sorted category local names
    boolean m_bUserLocationAcquired = false;
    Location m_coordLast = null;
    GoogleApiClient m_GoogleApiClient = null;
    LocationRequest m_LocationRequest;
    SwipeRefreshLayout m_refreshControl;
    Toast m_refreshMessage;

    static CRxDetailRefreshParentDelegate g_CurrentRefreshDelegate = null;  // hack for passing pointer to child activity
    static CRxFilterChangeDelegate g_CurrentFilterChangeDelegate = null;
    CRxDetailRefreshParentDelegate m_refreshParentDelegate = null;          // delegate of this activity

    ExpandListAdapter m_adapter;

    static String formatDate(int iDateStyle, int iTimeStyle, Date date) {
        if (iDateStyle == -1 && iTimeStyle == -1) return "";
        if (iDateStyle == -1) return new SimpleDateFormat("HH:mm").format(date);// DateFormat.getTimeInstance(iTimeStyle).format(date);
        if (iTimeStyle == -1) return DateFormat.getDateInstance(iDateStyle).format(date);
        return new SimpleDateFormat("dd.MM.yyyy HH:mm").format(date);//DateFormat.getDateTimeInstance(iDateStyle, iTimeStyle).format(date);
    }

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
            //if (m_orderedCategories.size() < 2)
            //    view.setVisibility(View.GONE);
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
                        cell.m_btnBuy = (Button)view.findViewById(R.id.btnBuy);
                        cell.m_btnAddToCalendar = (Button)view.findViewById(R.id.btnAddToCalendar);
                        break;
                    case CRxDataSource.DATATYPE_places:
                        cell.m_imgIcon = (ImageView)view.findViewById(R.id.icon);
                        break;
                }
                if (cell.m_btnWebsite != null)
                    cell.m_btnWebsite.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null)
                                aRecClicked.openInfoLink(m_context);
                        }
                    });
                if (cell.m_btnBuy != null)
                    cell.m_btnBuy.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null)
                                aRecClicked.openBuyLink(m_context);

                            // Google Analytics
                            Tracker aTracker = MainActivity.getDefaultTracker();
                            if (aTracker != null) {
                                aTracker.send(new HitBuilders.EventBuilder()
                                        .setCategory("Buy")
                                        .setAction("Buy")
                                        .setLabel(getTitle().toString())
                                        .build());
                            }
                        }
                    });
                if (cell.m_btnFavorite != null)
                    cell.m_btnFavorite.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null) {
                                aRecClicked.m_bMarkFavorite = !aRecClicked.m_bMarkFavorite;
                                ImageButton btn = (ImageButton)view;
                                btn.setImageResource(aRecClicked.m_bMarkFavorite ? R.drawable.goldstar25 : R.drawable.goldstar25dis);
                                CRxDataSourceManager.sharedInstance().setFavorite(aRecClicked, aRecClicked.m_bMarkFavorite);

                                if (m_aDataSource.m_sId.equals(CRxDataSourceManager.dsSavedNews) && m_refreshParentDelegate != null ){
                                    m_refreshParentDelegate.detailRequestsRefresh();
                                }
                            }
                        }
                    });
                if (cell.m_btnAddToCalendar != null)
                    cell.m_btnAddToCalendar.setOnClickListener(new View.OnClickListener() {
                        @Override
                        public void onClick(View view) {
                            CRxEventRecord aRecClicked = (CRxEventRecord)view.getTag();
                            if (aRecClicked != null) {
                                Intent calIntent = new Intent(Intent.ACTION_INSERT);
                                calIntent.setData(CalendarContract.Events.CONTENT_URI);
                                calIntent.putExtra(CalendarContract.Events.TITLE, aRecClicked.m_sTitle);
                                if (aRecClicked.m_sAddress != null)
                                    calIntent.putExtra(CalendarContract.Events.EVENT_LOCATION, aRecClicked.m_sAddress);
                                if (aRecClicked.m_sText != null)
                                    calIntent.putExtra(CalendarContract.Events.DESCRIPTION, aRecClicked.m_sText);
                                if (aRecClicked.m_aDate != null)
                                    calIntent.putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, aRecClicked.m_aDate.getTime());
                                if (aRecClicked.m_aDateTo != null)
                                    calIntent.putExtra(CalendarContract.EXTRA_EVENT_END_TIME, aRecClicked.m_aDateTo.getTime());
                                startActivity(calIntent);
                            }
                        }
                    });
                view.setTag(cell);
            } else {
                cell = (NewsListItemHolder)view.getTag();
            }

            ArrayList<CRxEventRecord> arr = m_orderedItems.get(m_orderedCategories.get(groupPosition));
            CRxEventRecord rec = arr.get(childPosition);

            if (cell.m_btnWebsite != null)
                cell.m_btnWebsite.setTag(rec);
            if (cell.m_btnAction != null)
                cell.m_btnAction.setTag(rec);
            if (cell.m_btnBuy != null)
                cell.m_btnBuy.setTag(rec);
            if (cell.m_btnAddToCalendar != null)
                cell.m_btnAddToCalendar.setTag(rec);
            if (cell.m_btnFavorite != null)
                cell.m_btnFavorite.setTag(rec);

            // fill cell contents
            switch (m_aDataSource.m_eType) {
                case CRxDataSource.DATATYPE_news: {

                    cell.m_lbTitle.setText(rec.m_sTitle);

                    String sText = "";
                    int iBoldTo = 0;
                    if (rec.m_sFilter != null) {
                        sText += rec.m_sFilter;
                        iBoldTo = sText.length();
                    }
                    if (rec.m_sText != null && !rec.m_sText.isEmpty()) {
                        if (sText.length() > 0) {
                            sText += " - ";
                        }
                        sText += rec.m_sText;
                    }
                    final SpannableString str = new SpannableString(sText);
                    if (iBoldTo > 0)
                        str.setSpan(new android.text.style.StyleSpan(android.graphics.Typeface.BOLD), 0, iBoldTo, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE);
                    cell.m_lbText.setText(str);
                    cell.m_lbText.setVisibility(sText.isEmpty() ? View.GONE : View.VISIBLE);

                    String sDateText = "";
                    if (rec.m_aDate != null) {
                        if (rec.m_aDateTo != null) {
                            DateFormat df = DateFormat.getDateInstance(DateFormat.MEDIUM);
                            sDateText += df.format(rec.m_aDate) + " - " + df.format(rec.m_aDateTo);
                        }
                        else {
                            DateFormat df = DateFormat.getDateInstance(DateFormat.FULL);
                            sDateText = df.format(rec.m_aDate);
                        }
                    }
                    cell.m_lbDate.setText(sDateText);
                    cell.m_btnWebsite.setVisibility(rec.m_sInfoLink == null ? View.GONE : View.VISIBLE);
                    cell.m_btnAction.setVisibility(rec.m_sInfoLink == null ? View.GONE : View.VISIBLE);
                    cell.m_btnFavorite.setImageResource(rec.m_bMarkFavorite ? R.drawable.goldstar25 : R.drawable.goldstar25dis);
                    break;
                }

                case CRxDataSource.DATATYPE_events: {

                    cell.m_lbTitle.setText(rec.m_sTitle);

                    if (rec.m_sText != null)
                        cell.m_lbText.setText(rec.m_sText);
                    cell.m_lbText.setVisibility(rec.m_sText == null ? View.GONE : View.VISIBLE);

                    String sDateText = "";
                    if (rec.m_aDate != null) {
                        int iDateStyle = -1;
                        int iTimeStyle = DateFormat.SHORT;

                        Calendar calFrom = Calendar.getInstance();
                        calFrom.setTime(rec.m_aDate);

                        if ((int)calFrom.get(Calendar.HOUR) == 0 && (int)calFrom.get(Calendar.MINUTE) == 0) {
                            iTimeStyle = -1;
                        }
                        sDateText = EventCtl.formatDate(iDateStyle, iTimeStyle, rec.m_aDate);
                        if (rec.m_aDateTo != null) {
                            Calendar calTo = Calendar.getInstance();
                            calTo.setTime(rec.m_aDateTo);

                            if ((int)calFrom.get(Calendar.DAY_OF_YEAR) != (int)calTo.get(Calendar.DAY_OF_YEAR)) {
                                iDateStyle = DateFormat.SHORT;
                                sDateText = EventCtl.formatDate(iDateStyle, iTimeStyle, rec.m_aDate);
                            }

                            iTimeStyle = DateFormat.SHORT;
                            if ((int)calTo.get(Calendar.HOUR) == 0 && (int)calTo.get(Calendar.MINUTE) == 0) {
                                iTimeStyle = -1;
                            }
                            sDateText += "\n- " + EventCtl.formatDate(iDateStyle, iTimeStyle, rec.m_aDateTo);
                        }
                    }
                    cell.m_lbDate.setText(sDateText);
                    cell.m_btnWebsite.setVisibility(rec.m_sInfoLink == null ? View.GONE : View.VISIBLE);
                    cell.m_btnBuy.setVisibility(rec.m_sBuyLink == null ? View.GONE : View.VISIBLE);
                    cell.m_btnAddToCalendar.setVisibility(rec.m_aDate==null ? View.GONE : View.VISIBLE);
                    break;
                }

                case CRxDataSource.DATATYPE_places: {

                    String sRecTitle = rec.m_sTitle;
                    if (CRxGame.sharedInstance.playerWas(rec))
                        sRecTitle += " ✓";
                    cell.m_lbTitle.setText(sRecTitle);

                    // strike-out obsolete accidents
                    boolean bObsolete = (rec.m_aDateTo != null && rec.m_aDateTo.before(new Date()));
                    if (bObsolete)
                        cell.m_lbTitle.setPaintFlags(cell.m_lbTitle.getPaintFlags() | Paint.STRIKE_THRU_TEXT_FLAG);
                    else
                        cell.m_lbTitle.setPaintFlags(cell.m_lbTitle.getPaintFlags() & (~Paint.STRIKE_THRU_TEXT_FLAG));

                    String sDistance = "";
                    if (m_bUserLocationAcquired && rec.m_aLocation != null) {
                        if (rec.m_distFromUser > 1000) {
                            sDistance = String.format("%.2f km ", rec.m_distFromUser/1000.0);
                        }
                        else {
                            sDistance = String.format("%d m ", (int)rec.m_distFromUser);
                        }
                    }
                    String sSubtitle = "";
                    String sNextEvent = rec.nextEventOccurenceString(m_context);
                    String sTodayHours = rec.todayOpeningHoursString(m_context);
                    if (sNextEvent != null) {
                        sSubtitle = sNextEvent;
                    }
                    else if (sTodayHours != null) {
                        sSubtitle = sTodayHours;
                    }
                    else if (rec.m_sText != null) {
                        sSubtitle = rec.m_sText;
                    }
                    if (!sSubtitle.isEmpty()) {
                        if (!sDistance.isEmpty()) {
                            sDistance += " | ";
                        }
                        sDistance += sSubtitle;
                    }
                    if (sDistance.isEmpty()) {
                        sDistance = "  ";    // must not be empty, causes strange effects
                    }
                    cell.m_lbText.setText(sDistance);

                    int iIcon = CRxCategory.categoryIconName(rec.m_eCategory);
                    if (rec.m_bMarkFavorite)
                        iIcon = R.drawable.goldstar25;
                    if (iIcon != -1)
                        cell.m_imgIcon.setImageResource(iIcon);
                    cell.m_imgIcon.setVisibility(iIcon != -1 ? View.VISIBLE : View.GONE);
                    break;
                }
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

        m_refreshParentDelegate = EventCtl.g_CurrentRefreshDelegate;
        EventCtl.g_CurrentRefreshDelegate = null;

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        if (sDataSource == null) return;
        if (sDataSource.equals(CRxDataSourceManager.dsSavedNews))
            m_aDataSource = CRxDataSourceManager.sharedInstance().m_aSavedNews;
        else
            m_aDataSource = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDataSource);
        if (m_aDataSource == null) return;
        m_sParentFilter = getIntent().getStringExtra(MainActivity.EXTRA_PARENT_FILTER);

        if (m_aDataSource.m_bIsBeingRefreshed)
            m_aDataSource.delegate = this;

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
                    EventCtl.g_CurrentRefreshDelegate = EventCtl.this;
                    Intent intent = new Intent(EventCtl.this, PlaceDetailCtl.class);
                    intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
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

        m_refreshControl = (SwipeRefreshLayout)findViewById(R.id.swipe_container);
        m_refreshControl.setOnRefreshListener(this);
        m_refreshMessage = Toast.makeText(getApplicationContext(), "", Toast.LENGTH_LONG);
        if (m_aDataSource.m_bIsBeingRefreshed)
            m_refreshControl.setRefreshing(true);

        // footer
        View viewFooter = findViewById(R.id.footer);
        TextView lbFooterText = (TextView)findViewById(R.id.footerText);
        Button btnFooterButton = (Button)findViewById(R.id.btnFooter);
        if (m_aDataSource.m_sId.equals(CRxDataSourceManager.dsWork)) {
            lbFooterText.setText(R.string.add_new_job_offer);
            btnFooterButton.setText("KdeJePrace.cz");
        }
        else if (m_aDataSource.m_eType == CRxDataSource.DATATYPE_places/* && !m_aDataSource.m_sId.equals(CRxDataSourceManager.dsCooltour)*/) {
            //m_lbFooterText.text = NSLocalizedString("Add record:", comment: "");
        }
        else {
            viewFooter.setVisibility(View.GONE);
        }
        btnFooterButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (m_aDataSource.m_sId.equals(CRxDataSourceManager.dsWork)) {
                    Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse("http://www.kdejeprace.cz/pridat?utm_source=dvanactka.info&utm_medium=app"));
                    startActivity(browserIntent);
                }
                else {
                    Intent intent = new Intent(Intent.ACTION_SEND);
                    intent.setType("message/rfc822");
                    intent.putExtra(Intent.EXTRA_EMAIL, new String[]{"info@dvanactka.info"});
                    intent.putExtra(Intent.EXTRA_SUBJECT, "P12app - přidat záznam");
                    String sTitle = m_aDataSource.m_sTitle;
                    if (m_sParentFilter != null)
                        sTitle += m_sParentFilter;
                    intent.putExtra(Intent.EXTRA_TEXT, sTitle);
                    try {
                        startActivity(Intent.createChooser(intent, getString(R.string.send_mail)));
                    } catch (android.content.ActivityNotFoundException ex) {
                        Toast.makeText(EventCtl.this, "There are no email clients installed.", Toast.LENGTH_SHORT).show();
                    }
                }
            }
        });

        // Google Analytics
        if (m_aDataSource != null) {
            Tracker aTracker = MainActivity.getDefaultTracker();
            if (aTracker != null) {
                if (m_sParentFilter != null)
                    aTracker.setScreenName("DS_" + m_sParentFilter);
                else
                    aTracker.setScreenName("DS_" + m_aDataSource.m_sId);
                aTracker.send(new HitBuilders.ScreenViewBuilder().build());
            }
        }
    }

    //--------------------------------------------------------------------------
    void sortRecords() {
        CRxDataSource ds = m_aDataSource;
        if (ds == null) return;

        m_orderedItems.clear();
        m_orderedCategories.clear();

        DateFormat df = DateFormat.getDateInstance(DateFormat.FULL);

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
                            return t0.m_aDate.after(t1.m_aDate) ? -1 : 1;
                        }
                    });
                    break;
                case CRxDataSource.DATATYPE_events:
                    Collections.sort(arr, new Comparator<CRxEventRecord>() {
                        @Override
                        public int compare(CRxEventRecord t0, CRxEventRecord t1)
                        {
                            return t0.m_aDate.before(t1.m_aDate) ? -1 : 1;
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
    public boolean onCreateOptionsMenu(Menu menu) {
        if (m_aDataSource == null) return super.onCreateOptionsMenu(menu);

        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_event_ctl, menu);

        MenuItem actFilter = menu.findItem(R.id.action_filter);
        MenuItem actMap = menu.findItem(R.id.action_map);
        MenuItem actSaved = menu.findItem(R.id.action_saved);
        actFilter.setVisible(false);
        actMap.setVisible(false);
        actSaved.setVisible(false);
        // make those visible
        if (m_aDataSource.m_eType == CRxDataSource.DATATYPE_places) {
            actMap.setVisible(true);
        }
        if (m_aDataSource.m_eType == CRxDataSource.DATATYPE_news && !m_aDataSource.m_sId.equals(CRxDataSourceManager.dsSavedNews)) {
            actSaved.setVisible(true);
            if (m_aDataSource.m_bFilterable)
                actFilter.setVisible(true);
        }
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            // Respond to the action bar's Up/Home button
            case android.R.id.home:
                onBackPressed();        // go to the activity that brought user here, not to parent activity
                return true;

            case R.id.action_map: {
                Intent intent = new Intent(EventCtl.this, MapCtl.class);
                intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                if (m_sParentFilter != null)
                    intent.putExtra(MainActivity.EXTRA_PARENT_FILTER, m_sParentFilter);
                if (m_bUserLocationAcquired)
                {
                    intent.putExtra(MainActivity.EXTRA_USER_LOCATION_LAT, m_coordLast.getLatitude());
                    intent.putExtra(MainActivity.EXTRA_USER_LOCATION_LONG, m_coordLast.getLongitude());
                }
                startActivity(intent);
                return true;
            }
            case R.id.action_saved: {
                EventCtl.g_CurrentRefreshDelegate = EventCtl.this;
                Intent intent = new Intent(EventCtl.this, EventCtl.class);
                intent.putExtra(MainActivity.EXTRA_DATASOURCE, CRxDataSourceManager.dsSavedNews);
                startActivity(intent);
                return true;
            }

            case R.id.action_filter: {
                EventCtl.g_CurrentFilterChangeDelegate = EventCtl.this;
                Intent intent = new Intent(EventCtl.this, FilterCtl.class);
                intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                startActivity(intent);
                return true;
            }
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
        if (m_GoogleApiClient != null)
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
            e.printStackTrace();
        }
    }

    protected void stopLocationUpdates() {
        try {
            LocationServices.FusedLocationApi.removeLocationUpdates(m_GoogleApiClient, this);
        }
        catch(Exception e){
            e.printStackTrace();
        }
    }

    //---------------------------------------------------------------------------
    void updateListWhenLocationChanged()
    {
        // reorder list of VOKs and show distance to current location
        setRecordsDistance();
        sortRecords();
        if (m_adapter != null)
            m_adapter.notifyDataSetChanged();
    }

    //---------------------------------------------------------------------------
    @Override
    public void detailRequestsRefresh() {
        sortRecords();
        if (m_adapter != null)
            m_adapter.notifyDataSetChanged();
    }

    //---------------------------------------------------------------------------
    @Override
    public void filterChanged(Set<String> setOut) {
        if (m_aDataSource == null) return;
        m_aDataSource.m_setFilter = setOut;
        CRxDataSourceManager.sharedInstance().save(m_aDataSource);
        sortRecords();
        if (m_adapter != null)
            m_adapter.notifyDataSetChanged();
    }

    //---------------------------------------------------------------------------
    @Override
    public void onConnectionSuspended(int i) {
        Toast.makeText(this, "Google Play Services disconnected. Please re-connect.",
                Toast.LENGTH_SHORT).show();
    }

    //---------------------------------------------------------------------------
    @Override
    public void onConnectionFailed(ConnectionResult connectionResult) {
        Toast.makeText(this, "Connection to Google Play Services failed.",
                Toast.LENGTH_SHORT).show();
    }

    //---------------------------------------------------------------------------
    @Override
    public void onLocationChanged(Location location) {
        m_coordLast = location;
        m_bUserLocationAcquired = true;
        updateListWhenLocationChanged();
    }

    //---------------------------------------------------------------------------
    @Override
    public void onRefresh() {       // from refreshLayout
        m_aDataSource.delegate = this;
        CRxDataSourceManager.sharedInstance().refreshDataSource(m_aDataSource.m_sId, true);
    }

    //---------------------------------------------------------------------------
    @Override
    public void dataSourceRefreshEnded(String error) { // protocol CRxDataSourceRefreshDelegate
        m_aDataSource.delegate = null;

        if (error != null) {
            m_refreshControl.setRefreshing(false);
            m_refreshMessage.setText(error);
            m_refreshMessage.show();
        }
        else {
            setRecordsDistance();
            sortRecords();
            if (m_adapter != null)
                m_adapter.notifyDataSetChanged();
            ////self.refreshControl?.attributedTitle = NSAttributedString(string: stringWithLastUpdateDate());
            m_refreshControl.setRefreshing(false);
        }
    }
}
