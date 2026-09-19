package com.anamika.ai.media3d;

import android.view.View;
import android.widget.AdapterView;

final class SimpleItemSelectedListener implements AdapterView.OnItemSelectedListener {
    private final Runnable onSelected;
    SimpleItemSelectedListener(Runnable onSelected) { this.onSelected = onSelected; }
    @Override public void onItemSelected(AdapterView<?> parent, View view, int position, long id) { onSelected.run(); }
    @Override public void onNothingSelected(AdapterView<?> parent) { }
}
