package com.roomarranger.android.dvanactka;

import android.app.Activity;
import android.os.Bundle;
import android.text.Html;
import android.text.method.LinkMovementMethod;
import android.view.LayoutInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ListView;
import android.widget.RadioButton;
import android.widget.RelativeLayout;
import android.widget.TextView;

import org.nairteashop.SegmentedControl;

import java.util.ArrayList;


/*
 Copyright 2016-2020 Jan Adamec.

 This file is part of "Dvanactka".

 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.

 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
*/

public class QuestionsCtl extends Activity {

    BaseAdapter m_listAdapter;

    CRxDataSource m_aDataSource = null;
    CRxEventRecord rec = null;
    int m_iLevel = 0;

    ArrayList<CRxQuestionAnswer> m_arrFilteredItems = null;

    static class QuestionItemViewHolder {
        TextView m_lbTitle, m_lbText;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_questions_ctl);

        MainActivity.verifyDataInited(this);

        String sDataSource = getIntent().getStringExtra(MainActivity.EXTRA_DATASOURCE);
        String sRecordHash = getIntent().getStringExtra(MainActivity.EXTRA_EVENT_RECORD);
        if (sDataSource == null || sRecordHash == null) return;
        m_aDataSource = CRxDataSourceManager.shared.m_dictDataSources.get(sDataSource);
        if (m_aDataSource == null) return;
        rec = m_aDataSource.recordWithHash(sRecordHash);
        if (rec == null) return;

        setTitle(rec.m_sTitle);

        m_arrFilteredItems = new ArrayList<>();

        m_listAdapter = new BaseAdapter()
        {
            @Override
            public int getCount()
            {
                return m_arrFilteredItems.size();
            }

            @Override
            public Object getItem(int position)
            {
                return null;
            }

            @Override
            public long getItemId(int position)
            {
                return position;
            }

            @Override
            public View getView(int position, View convertView, ViewGroup parent)
            {
                QuestionsCtl.QuestionItemViewHolder cell;
                if (convertView == null)
                {
                    LayoutInflater inflater = getLayoutInflater();
                    convertView = inflater.inflate(R.layout.list_item_question, parent, false);

                    cell = new QuestionsCtl.QuestionItemViewHolder();
                    cell.m_lbTitle = convertView.findViewById(R.id.title);
                    cell.m_lbText = convertView.findViewById(R.id.text);
                    cell.m_lbText.setMovementMethod(LinkMovementMethod.getInstance()); // enable clicking through links in this textview
                    convertView.setTag(cell);
                }
                else
                    cell = (QuestionsCtl.QuestionItemViewHolder) convertView.getTag();

                CRxQuestionAnswer item = m_arrFilteredItems.get(position);
                cell.m_lbTitle.setText(item.m_sQuestion);

                if (item.m_sAnswer.startsWith("<dd")) {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N)
                        cell.m_lbText.setText(Html.fromHtml(item.m_sAnswer, Html.FROM_HTML_MODE_COMPACT));
                    else
                        cell.m_lbText.setText(Html.fromHtml(item.m_sAnswer));
                }
                else
                    cell.m_lbText.setText(item.m_sAnswer);
                return convertView;
            }
        };
        ListView lvList = findViewById(R.id.listView);
        lvList.setAdapter(m_listAdapter);

        RelativeLayout footer = findViewById(R.id.footer);
        SegmentedControl segmLevel = findViewById(R.id.segmLevel);
        segmLevel.check(R.id.opt_0);

        if (m_aDataSource.m_arrQaLabels == null || m_aDataSource.m_arrQaLabels.isEmpty()) {
            footer.setVisibility(View.INVISIBLE);
        }
        else {
            for (int i = 0; i < segmLevel.getChildCount(); i++) {
                RadioButton btn = (RadioButton) segmLevel.getChildAt(i);
                if (m_aDataSource.m_arrQaLabels.size() > i)
                    btn.setText(m_aDataSource.m_arrQaLabels.get(i));
                else
                    btn.setVisibility(View.INVISIBLE);
            }

            segmLevel.setOnCheckedChangeListener((group, checkedId) -> {
                if (checkedId == R.id.opt_0) { m_iLevel = 0; filterQuestions(); }
                else if (checkedId == R.id.opt_1) { m_iLevel = 1; filterQuestions(); }
                else if (checkedId == R.id.opt_2) { m_iLevel = 2; filterQuestions(); }
                else if (checkedId == R.id.opt_3) { m_iLevel = 3; filterQuestions(); }
            });
        }

        filterQuestions();
    }

    //--------------------------------------------------------------------------
    void filterQuestions() {

        m_arrFilteredItems.clear();
        if (rec == null || rec.m_arrQa == null) return;

        for (CRxQuestionAnswer item: rec.m_arrQa) {
            if (item.m_iLevel <= m_iLevel) {
                m_arrFilteredItems.add(item);
            }
        }

        m_listAdapter.notifyDataSetChanged();
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

}
