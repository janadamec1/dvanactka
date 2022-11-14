package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.location.Location;
import android.Manifest;
import android.os.Bundle;
import androidx.core.content.ContextCompat;
import android.view.MenuItem;

import com.google.android.gms.maps.CameraUpdate;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.MapFragment;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.UiSettings;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;

import org.nairteashop.SegmentedControl;

/*
 Copyright 2016-2018 Jan Adamec.

 This file is part of "Dvanactka".

 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.

 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
*/

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

        SegmentedControl segmMapSwitch = findViewById(R.id.segmMapSwitch);
        segmMapSwitch.check(R.id.opt_0);
        segmMapSwitch.setOnCheckedChangeListener((group, checkedId) -> {
            if (m_map != null) {
                if (checkedId == R.id.opt_0)
                    m_map.setMapType(GoogleMap.MAP_TYPE_NORMAL);
                else if (checkedId == R.id.opt_1)
                    m_map.setMapType(GoogleMap.MAP_TYPE_SATELLITE);
                else if (checkedId == R.id.opt_2)
                    m_map.setMapType(GoogleMap.MAP_TYPE_HYBRID);
            }
        });
    }

    //---------------------------------------------------------------------------
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int id = item.getItemId();
        if (id == android.R.id.home) {
            // Respond to the action bar's Up/Home button
            onBackPressed();        // go to the activity that brought user here, not to parent activity
            return true;
        }
        return super.onOptionsItemSelected(item);
    }

    //---------------------------------------------------------------------------
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
            if (CRxAppDefinition.shared.m_aMunicipalityCenter != null) {
                coord = MapCtl.loc2LatLng(CRxAppDefinition.shared.m_aMunicipalityCenter);
            }
            CameraUpdate cameraUpdate = CameraUpdateFactory.newLatLngZoom(coord, 15);
            m_map.moveCamera(cameraUpdate);
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED)
            m_map.setMyLocationEnabled(true);
        UiSettings settings = m_map.getUiSettings();
        settings.setZoomControlsEnabled(true);

        m_map.setOnMapLongClickListener(latLng -> {
            if (m_aPin != null)
                m_aPin.remove();

            m_aPin = m_map.addMarker(new MarkerOptions().position(latLng));

            // send result
            Intent resultIntent = new Intent();
            resultIntent.putExtra(MainActivity.EXTRA_USER_LOCATION_LAT, latLng.latitude);
            resultIntent.putExtra(MainActivity.EXTRA_USER_LOCATION_LONG, latLng.longitude);
            setResult(RESULT_OK, resultIntent);
        });
    }
}
