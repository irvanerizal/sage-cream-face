import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class SageCreamView extends WatchUi.WatchFace {

    // ---- Palette -----------------------------------------------------------
    private const COLOR_BACKGROUND = 0x0D0F0E;
    private const COLOR_RING_TRACK = 0x1E2622;
    private const COLOR_RING_PROGRESS = 0x8FB996;
    private const COLOR_TIME = 0xF2EBDD;
    private const COLOR_TEXT = 0x8FB996;
    private const COLOR_TIME_SLEEP = 0x6F6A5F;

    // 12 o'clock in the drawArc angle system (0 = 3 o'clock, CCW positive).
    private const ARC_TOP = 90.0;

    // ---- Cached layout (computed once in onLayout) -------------------------
    private var mCx as Number = 0;
    private var mCy as Number = 0;
    private var mRingRadius as Number = 0;
    private var mPenWidth as Number = 1;
    private var mCapRadius as Float = 0.5;
    private var mDateY as Number = 0;
    private var mTimeY as Number = 0;
    private var mStepsY as Number = 0;

    private var mTimeFont as Graphics.FontType?;
    private var mSmallFont as Graphics.FontType = Graphics.FONT_XTINY;

    private var mSleeping as Boolean = false;

    public function initialize() {
        WatchFace.initialize();
    }

    //! Compute every position, radius and pen width once.
    public function onLayout(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();

        mCx = w / 2;
        mCy = h / 2;
        mRingRadius = (0.466 * w).toNumber();
        mPenWidth = (0.017 * w).toNumber();
        if (mPenWidth < 1) {
            mPenWidth = 1;
        }
        mCapRadius = mPenWidth / 2.0;

        mDateY = (0.291 * h).toNumber();
        mTimeY = (0.5 * h).toNumber();
        mStepsY = (0.726 * h).toNumber();

        // Bitmap font ships with the project (serif_digits.fnt + .png), so no
        // Graphics.FONT_NUMBER_HOT fallback is needed at runtime.
        mTimeFont = WatchUi.loadResource(Rez.Fonts.SerifDigits) as Graphics.FontType;
        mSmallFont = Graphics.FONT_XTINY;
    }

    public function onUpdate(dc as Dc) as Void {
        var now = Time.now();
        var is24Hour = System.getDeviceSettings().is24Hour;
        var greg = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var timeText = formatTime(greg.hour, greg.min, is24Hour);
        var timeFont = mTimeFont as Graphics.FontType;

        dc.setColor(COLOR_BACKGROUND, COLOR_BACKGROUND);
        dc.clear();

        // AMOLED sleep: only the dimmed time.
        if (mSleeping) {
            dc.setColor(COLOR_TIME_SLEEP, Graphics.COLOR_TRANSPARENT);
            dc.drawText(mCx, mTimeY, timeFont, timeText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // ---- Steps / goal (single ActivityMonitor read) ----
        var progress = 0.0;
        var stepsText = "0 steps";
        var info = ActivityMonitor.getInfo();
        if (info != null) {
            var steps = info.steps;
            var goal = info.stepGoal;
            if (steps != null) {
                stepsText = formatSteps(steps) + " steps";
                if (goal != null && goal > 0) {
                    progress = steps.toFloat() / goal.toFloat();
                    if (progress > 1.0) {
                        progress = 1.0;
                    } else if (progress < 0.0) {
                        progress = 0.0;
                    }
                }
            }
        }

        drawRing(dc, progress);

        // ---- Date ----
        var dateText = upperText(greg.day_of_week) + " " + greg.day.toString() + " " + upperText(greg.month);
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, mDateY, mSmallFont, dateText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ---- Time ----
        dc.setColor(COLOR_TIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, mTimeY, timeFont, timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // ---- Steps ----
        dc.setColor(COLOR_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCx, mStepsY, mSmallFont, stepsText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Ring track plus a clockwise progress arc starting at 12 o'clock.
    private function drawRing(dc as Dc, progress as Float) as Void {
        dc.setPenWidth(mPenWidth);
        dc.setColor(COLOR_RING_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(mCx, mCy, mRingRadius);

        if (progress <= 0.0) {
            return;
        }

        var sweep = 360.0 * progress;
        var endAngle = ARC_TOP - sweep;
        dc.setColor(COLOR_RING_PROGRESS, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(mCx, mCy, mRingRadius, Graphics.ARC_CLOCKWISE, ARC_TOP, endAngle);

        // drawArc has no rounded caps: fake them with filled circles.
        drawCap(dc, ARC_TOP);
        drawCap(dc, endAngle);
    }

    //! Filled circle of pen-width diameter at the given arc angle.
    private function drawCap(dc as Dc, angle as Float) as Void {
        var radians = angle * Math.PI / 180.0;
        var x = (mCx + mRingRadius * Math.cos(radians)).toNumber();
        var y = (mCy - mRingRadius * Math.sin(radians)).toNumber();
        dc.fillCircle(x, y, mCapRadius);
    }

    //! 24h -> %02d:%02d, 12h -> %d:%02d (no AM/PM).
    private function formatTime(hour as Number, minute as Number, is24Hour as Boolean) as String {
        if (is24Hour) {
            return hour.format("%02d") + ":" + minute.format("%02d");
        }
        var hour12 = hour % 12;
        if (hour12 == 0) {
            hour12 = 12;
        }
        return hour12.format("%d") + ":" + minute.format("%02d");
    }

    //! "8420" -> "8,420"
    private function formatSteps(steps as Number) as String {
        var digits = steps.toString();
        var out = "";
        var count = 0;
        for (var i = digits.length() - 1; i >= 0; i -= 1) {
            out = digits.substring(i, i + 1) + out;
            count += 1;
            if (count == 3 && i > 0) {
                out = "," + out;
                count = 0;
            }
        }
        return out;
    }

    //! Gregorian fields are Number or String depending on the format.
    private function upperText(value as Number or String) as String {
        if (value instanceof String) {
            return (value as String).toUpper();
        }
        return (value as Number).toString();
    }

    public function onEnterSleep() as Void {
        mSleeping = true;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        mSleeping = false;
        WatchUi.requestUpdate();
    }
}
