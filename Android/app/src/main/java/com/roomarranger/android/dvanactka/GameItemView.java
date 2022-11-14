package com.roomarranger.android.dvanactka;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.drawable.Drawable;
import android.util.AttributeSet;
import android.view.View;

/*
 Copyright 2017-2018 Jan Adamec.

 This file is part of "Dvanactka".

 "Dvanactka" is free software; see the file COPYING.txt,
 included in this distribution, for details about the copyright.

 "Dvanactka" is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 ----------------------------------------------------------------------------
*/

public class GameItemView extends View {
    Paint m_paint;
    RectF m_rect;

    Drawable m_imgStar;
    Drawable m_imgEmptyStar;
    int m_iGameCategory = 0;

    public GameItemView(Context context, AttributeSet attrs) {
        super(context, attrs);

        m_paint = new Paint();
        m_paint.setColor(Color.RED);
        m_paint.setStyle(Paint.Style.STROKE);
        m_paint.setStrokeCap(Paint.Cap.ROUND);
        m_paint.setStrokeWidth(16);
        m_rect = new RectF();

        m_imgStar = getResources().getDrawable(R.drawable.goldstar25);
        m_imgEmptyStar = getResources().getDrawable(R.drawable.goldstar25dis);
    }

    void setGameCategory(int position) {
        m_iGameCategory = position;
        invalidate();
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        // Try for a width based on our minimum
        int minw = getPaddingLeft() + getPaddingRight() + getSuggestedMinimumWidth();
        int w = resolveSizeAndState(minw, widthMeasureSpec, 1);
        setMeasuredDimension(w, w);
    }

    @Override
    public void onDraw(Canvas canvas) {
        super.onDraw(canvas);

        CRxGameCategory item = CRxGame.shared.m_arrCategories.get(m_iGameCategory);

        float fCellSize = canvas.getWidth()-1;
        float fRadius = fCellSize/3;

        float fBorder = (fCellSize - 2*fRadius) / 2.0f;
        m_rect.set(fBorder, fBorder, fCellSize-fBorder, fCellSize-fBorder);
        m_paint.setColor(Color.argb(76, 102, 102, 102));
        canvas.drawArc(m_rect, -90, 360, false, m_paint);

        float fGameProgressRatio = item.m_iProgress / (float)item.nextStarPoints();
        if (fGameProgressRatio > 1.0) { fGameProgressRatio = 1.0f; }
        m_paint.setColor(Color.rgb(36, 90, 128));
        canvas.drawArc(m_rect, -90, 360*fGameProgressRatio, false, m_paint);

        if (m_imgStar != null && m_imgEmptyStar != null) {
            int fStarSize = (int)(fCellSize/4);
            int fStarSize_2 = fStarSize/2;

            int iStars = item.stars();
            Drawable img1 = (iStars > 0 ? m_imgStar : m_imgEmptyStar);
            Drawable img2 = (iStars > 1 ? m_imgStar : m_imgEmptyStar);
            Drawable img3 = (iStars > 2 ? m_imgStar : m_imgEmptyStar);

            int x = (int)(fCellSize/2 - fStarSize - fStarSize_2);
            int y = (int)(fCellSize/2-fStarSize_2);
            img1.setBounds(x, y, x+fStarSize, y+fStarSize);
            img1.draw(canvas);
            x += fStarSize;
            img2.setBounds(x, y, x+fStarSize, y+fStarSize);
            img2.draw(canvas);
            x += fStarSize;
            img3.setBounds(x, y, x+fStarSize, y+fStarSize);
            img3.draw(canvas);
        }
    }
}