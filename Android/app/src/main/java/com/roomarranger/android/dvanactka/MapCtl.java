package com.roomarranger.android.dvanactka;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.location.Location;
import android.support.v4.app.FragmentActivity;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewTreeObserver;
import android.widget.RadioGroup;

import com.google.android.gms.maps.CameraUpdate;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.MapFragment;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.UiSettings;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.LatLngBounds;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;

import org.nairteashop.SegmentedControl;

import java.util.HashMap;

public class MapCtl extends FragmentActivity implements OnMapReadyCallback {

    CRxDataSource m_aDataSource = null;
    String m_sParentFilter = null;          // show only items with this filter (for ds with filterAsParentView)

    private GoogleMap m_map;
    private HashMap<Marker, Integer> m_mapMarkers;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_map_ctl);

        MainActivity.verifyDataInited(this);

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        if (sDataSource == null) return;
        m_aDataSource = CRxDataSourceManager.sharedInstance().m_dictDataSources.get(sDataSource);
        if (m_aDataSource == null) return;
        m_sParentFilter = getIntent().getStringExtra(MainActivity.EXTRA_PARENT_FILTER);

        MapFragment mapFragment = (MapFragment)(getFragmentManager().findFragmentById(R.id.map));
        mapFragment.getMapAsync(this);

        SegmentedControl segmMapSwitch = (SegmentedControl) findViewById(R.id.segmMapSwitch);
        segmMapSwitch.check(R.id.opt_0);
        segmMapSwitch.setOnCheckedChangeListener(new RadioGroup.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(RadioGroup group, int checkedId) {
                if (m_map != null) {
                    switch (checkedId) {
                        case R.id.opt_0:
                            m_map.setMapType(GoogleMap.MAP_TYPE_NORMAL);
                            break;
                        case R.id.opt_1:
                            m_map.setMapType(GoogleMap.MAP_TYPE_SATELLITE);
                            break;
                        case R.id.opt_2:
                            m_map.setMapType(GoogleMap.MAP_TYPE_HYBRID);
                            break;
                    }
                }
            }
        });
    }

    public static LatLng loc2LatLng(Location loc)
    {
        return new LatLng(loc.getLatitude(), loc.getLongitude());
    }

    @Override
    public void onMapReady(GoogleMap googleMap) {
        m_map = googleMap;

        int nCount = 0;
        Location coordMin = new Location("min"), coordMax = new Location("max"), coordUser = null;
        double dUserLat = getIntent().getDoubleExtra(MainActivity.EXTRA_USER_LOCATION_LAT, 0.0);
        double dUserLong = getIntent().getDoubleExtra(MainActivity.EXTRA_USER_LOCATION_LONG, 0.0);
        if (dUserLat != 0.0 || dUserLong != 0.0)
        {
            coordUser = new Location("user");
            coordUser.setLatitude(dUserLat);
            coordUser.setLongitude(dUserLong);
            coordMin.set(coordUser); coordMax.set(coordUser);
            //nCount = 1;
        }

        m_mapMarkers = new HashMap<Marker, Integer>();

        int nVokCount = m_aDataSource.m_arrItems.size();
        for (int i = 0; i < nVokCount; i++)
        {
            CRxEventRecord rec = m_aDataSource.m_arrItems.get(i);
            // filter
            if (m_aDataSource.m_bFilterAsParentView) {
                if (rec.m_sFilter != null && m_sParentFilter != null) {
                    if (!rec.m_sFilter.equals(m_sParentFilter)) {
                        continue;
                    }
                }
            }

            if (rec.m_aLocation != null) {

                String sSubtitle = CRxCategory.categoryLocalName(rec.m_eCategory, this);
                if (rec.m_sFilter != null)
                    sSubtitle = rec.m_sFilter;

                Location coord = rec.m_aLocation;
                MarkerOptions opt = new MarkerOptions().position(loc2LatLng(coord))
                        .title(rec.m_sTitle)
                        .snippet(sSubtitle);
                int iIcon = CRxCategory.categoryIconName(rec.m_eCategory);
                if (iIcon != -1)
                    opt = opt.icon(BitmapDescriptorFactory.fromResource(iIcon));

                Marker aMarker = m_map.addMarker(opt);
                m_mapMarkers.put(aMarker, Integer.valueOf(i));

                if (nCount == 0) {
                    coordMin.set(coord); coordMax.set(coord);
                }
                else {
                    if (coord.getLongitude() < coordMin.getLongitude()) coordMin.setLongitude(coord.getLongitude());
                    if (coord.getLatitude() < coordMin.getLatitude()) coordMin.setLatitude(coord.getLatitude());
                    if (coord.getLongitude() > coordMax.getLongitude()) coordMax.setLongitude(coord.getLongitude());
                    if (coord.getLatitude() > coordMax.getLatitude()) coordMax.setLatitude(coord.getLatitude());
                }
                nCount += 1;
            }
        }
        if (nCount > 0)
        {
            CameraUpdate cameraUpdate;
            if (nCount == 1) {
                cameraUpdate = CameraUpdateFactory.newLatLngZoom(loc2LatLng(coordMin), 15);
                m_map.moveCamera(cameraUpdate);
            }
            else
            {
                // http://stackoverflow.com/questions/13692579/movecamera-with-cameraupdatefactory-newlatlngbounds-crashes
                final View mapView = getFragmentManager().findFragmentById(R.id.map).getView();
                try {
                    if (mapView.getViewTreeObserver().isAlive()) {
                        final Location _coordMin = coordMin;
                        final Location _coordMax = coordMax;
                        mapView.getViewTreeObserver().addOnGlobalLayoutListener(
                                new ViewTreeObserver.OnGlobalLayoutListener() {
                                    @Override
                                    public void onGlobalLayout() {
                                        mapView.getViewTreeObserver().removeOnGlobalLayoutListener(this);
                                        CameraUpdate cameraUpdate = CameraUpdateFactory.newLatLngBounds(new LatLngBounds(loc2LatLng(_coordMin), loc2LatLng(_coordMax)), mapView.getWidth(), mapView.getHeight(), 100);
                                        m_map.moveCamera(cameraUpdate);
                                    }
                                });
                    }
                }
                catch (Exception e) { e.printStackTrace(); }
            }
        }
        m_map.setMyLocationEnabled(true);
        UiSettings settings = m_map.getUiSettings();
        settings.setZoomControlsEnabled(true);

        m_map.setOnInfoWindowClickListener(new GoogleMap.OnInfoWindowClickListener() {
            @Override
            public void onInfoWindowClick(Marker marker) {
                Integer aInt = m_mapMarkers.get(marker);
                if (aInt != null) {
                    CRxEventRecord rec = m_aDataSource.m_arrItems.get(aInt.intValue());
                    if (rec == null) return;
                    Intent intent = new Intent(MapCtl.this, PlaceDetailCtl.class);
                    intent.putExtra(MainActivity.EXTRA_DATASOURCE, m_aDataSource.m_sId);
                    intent.putExtra(MainActivity.EXTRA_EVENT_RECORD, rec.recordHash());
                    startActivity(intent);
                }
            }
        });
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
