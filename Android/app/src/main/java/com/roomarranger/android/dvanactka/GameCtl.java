package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.Manifest;
import android.os.Build;
import android.os.Bundle;
import android.support.v4.content.ContextCompat;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.BaseAdapter;
import android.widget.GridView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import java.util.Locale;

public class GameCtl extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_game_ctl);

        MainActivity.verifyDataInited(this);

        TextView lbLevel = (TextView)findViewById(R.id.level);
        ProgressBar progress = (ProgressBar)findViewById(R.id.progress);
        TextView lbXp = (TextView)findViewById(R.id.xp);
        CRxGame.CRxPlayerStats aPlayerStats = CRxGame.shared.playerLevel();
        lbLevel.setText(getString(R.string.level) + " " + String.valueOf(aPlayerStats.level));
        progress.setMax(aPlayerStats.pointsNextLevel-aPlayerStats.pointsPrevLevel);
        progress.setProgress(aPlayerStats.points-aPlayerStats.pointsPrevLevel);
        lbXp.setText(String.format(Locale.US, "%d / %d XP", aPlayerStats.points, aPlayerStats.pointsNextLevel));

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            TextView lbNote = (TextView)findViewById(R.id.note);
            lbNote.setText(R.string.game_permission);
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            progress.getProgressDrawable().setColorFilter(
                    Color.rgb(36, 90, 128), android.graphics.PorterDuff.Mode.SRC_IN);
        }

        GridView gridview = (GridView)findViewById(R.id.gridview);
        gridview.setAdapter(new GameCtl.GameAdapter(this));

        gridview.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            public void onItemClick(AdapterView<?> parent, View v,
                                    int position, long id) {
                CRxGameCategory item = CRxGame.shared.m_arrCategories.get(position);
                Toast.makeText(GameCtl.this, item.m_sHintMessage, Toast.LENGTH_SHORT).show();
            }
        });

        CRxDataSource aDS = CRxGame.dataSource();
        if (aDS != null && aDS.m_sUuid == null && CRxGame.shared.m_iPoints > 0)
            CRxGame.shared.sendScoreToServer();
    }

    //---------------------------------------------------------------------------
    static class CollectionViewHolder {
        GameItemView m_item;
        TextView m_lbName;
        TextView m_lbProgress;
    }

    public class GameAdapter extends BaseAdapter {
        private Context m_context;

        GameAdapter(Context c) {
            m_context = c;
        }

        public int getCount() { return CRxGame.shared.m_arrCategories.size(); }
        public Object getItem(int position) { return null;}
        public long getItemId(int position) { return 0; }

        // create a new ImageView for each item referenced by the Adapter
        public View getView(int position, View convertView, ViewGroup parent) {
            CollectionViewHolder cell;
            if (convertView == null) {
                LayoutInflater inflater = getLayoutInflater();
                convertView = inflater.inflate(R.layout.cell_game_collection, parent, false);
                //convertView.setLayoutParams(new GridView.LayoutParams(85, 105));

                cell = new CollectionViewHolder();
                cell.m_item = (GameItemView)convertView.findViewById(R.id.img);
                cell.m_lbName = (TextView)convertView.findViewById(R.id.name);
                cell.m_lbProgress = (TextView)convertView.findViewById(R.id.progress);
                convertView.setTag(cell);
            } else {
                cell = (CollectionViewHolder)convertView.getTag();
            }

            CRxGameCategory item = CRxGame.shared.m_arrCategories.get(position);
            cell.m_item.setGameCategory(position);
            cell.m_lbName.setText(item.m_sName);
            cell.m_lbProgress.setText(String.format(Locale.US, "%d / %d", item.m_iProgress, item.nextStarPoints()));
            return convertView;
        }
    }

    //---------------------------------------------------------------------------
    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_game_ctl, menu);
        return true;
    }

    //---------------------------------------------------------------------------
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            // Respond to the action bar's Up/Home button
            case android.R.id.home:
                onBackPressed();        // go to the activity that brought user here, not to parent activity
                return true;

            case R.id.action_leaderboard: {
                CRxDataSource aDS = CRxGame.dataSource();
                if (aDS != null && aDS.m_sUuid == null) {
                    AlertDialog.Builder builder = new AlertDialog.Builder(this);
                    builder.setMessage(R.string.gamestart_note);
                    builder.create().show();
                }
                else {
                    Intent intent = new Intent(GameCtl.this, GameLeaderCtl.class);
                    startActivity(intent);
                }
                return true;
            }
        }
        return super.onOptionsItemSelected(item);
    }
}
