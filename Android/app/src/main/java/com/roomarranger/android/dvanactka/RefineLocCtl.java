package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Intent;
import android.location.Location;
import android.os.Bundle;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;

import com.google.android.gms.maps.CameraUpdate;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.MapFragment;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.UiSettings;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;

public class RefineLocCtl extends Activity implements OnMapReadyCallback {

    GoogleMap m_map;
    Marker m_aPin;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_refine_loc_ctl);

        setTitle("  "); // empty action bar title

        m_aPin = null;

        MapFragment mapFragment = (MapFragment)(getFragmentManager().findFragmentById(R.id.map));
        mapFragment.getMapAsync(this);

        Button btnMapStandard = (Button)findViewById(R.id.btnMapStandard);
        Button btnMapSatellite = (Button)findViewById(R.id.btnMapSatellite);
        Button btnMapHybrid = (Button)findViewById(R.id.btnMapHybrid);

        btnMapStandard.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (m_map != null)
                    m_map.setMapType(GoogleMap.MAP_TYPE_NORMAL);
            }
        });
        btnMapSatellite.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (m_map != null)
                    m_map.setMapType(GoogleMap.MAP_TYPE_SATELLITE);
            }
        });
        btnMapHybrid.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (m_map != null)
                    m_map.setMapType(GoogleMap.MAP_TYPE_HYBRID);
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

    @Override
    public void onMapReady(GoogleMap googleMap) {
        m_map = googleMap;

        double dLat = getIntent().getDoubleExtra(MainActivity.EXTRA_USER_LOCATION_LAT, 0);
        double dLong = getIntent().getDoubleExtra(MainActivity.EXTRA_USER_LOCATION_LONG, 0);
        if (dLat != 0.0 && dLong != 0.0) {
            Location loc = new Location("fault");
            loc.setLatitude(dLat);
            loc.setLongitude(dLong);
            LatLng coord = MapCtl.loc2LatLng(loc);
            m_aPin = m_map.addMarker(new MarkerOptions().position(coord));

            CameraUpdate cameraUpdate = CameraUpdateFactory.newLatLngZoom(coord, 15);
            m_map.moveCamera(cameraUpdate);
        }
        else {
            // center will be center of Praha 12
            LatLng coord = new LatLng(50.0020275, 14.4185889);
            CameraUpdate cameraUpdate = CameraUpdateFactory.newLatLngZoom(coord, 15);
            m_map.moveCamera(cameraUpdate);
        }

        m_map.setMyLocationEnabled(true);
        UiSettings settings = m_map.getUiSettings();
        settings.setZoomControlsEnabled(true);

        m_map.setOnMapLongClickListener(new GoogleMap.OnMapLongClickListener() {
            @Override
            public void onMapLongClick(LatLng latLng) {
                if (m_aPin != null)
                    m_aPin.remove();

                m_aPin = m_map.addMarker(new MarkerOptions().position(latLng));

                // send result
                Intent resultIntent = new Intent();
                resultIntent.putExtra(MainActivity.EXTRA_USER_LOCATION_LAT, latLng.latitude);
                resultIntent.putExtra(MainActivity.EXTRA_USER_LOCATION_LONG, latLng.longitude);
                setResult(RESULT_OK, resultIntent);
            }
        });
    }
}
