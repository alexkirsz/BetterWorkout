import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Math;
import Toybox.Time;
import Toybox.System;

const INACTIVE_STROKE_WIDTH = 6.0;
const ACTIVE_STROKE_WIDTH = 12.0;

class PaceTargets {
    hidden var low as Number;
    hidden var high as Number;

    function initialize(low as Number, high as Number) as Void {
        self.low = low;
        self.high = high;
    }

    function getLow() as Number {
        return low;
    }

    function getHigh() as Number {
        return high;
    }
}

function intensityToString(intensity as Activity.WorkoutIntensity) as String? {
    switch (intensity) {
    case Activity.WORKOUT_INTENSITY_ACTIVE:
        return "Active";
    case Activity.WORKOUT_INTENSITY_REST:
        return "Rest";
    case Activity.WORKOUT_INTENSITY_WARMUP:
        return "Warm up";
    case Activity.WORKOUT_INTENSITY_COOLDOWN:
        return "Cool down";
    case Activity.WORKOUT_INTENSITY_RECOVERY:
        return "Recovery";
    case Activity.WORKOUT_INTENSITY_INTERVAL:
        return "Interval";
    default:
        return null;
    }
}

function formatTimeMs(time as Number?) as String {
    if (time == null) {
        return "-:--";
    }

    time = time / 1000;

    var seconds = time % 60;
    var minutes = time / 60;

    if (minutes < 60) {
        return minutes.format("%d") + ":" + seconds.format("%02d");
    }

    var hours = minutes / 60;
    minutes = minutes % 60;

    return hours.format("%d") + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
}

const STATIONARY_THRESHOLD = 1000.0 / 3600.0; // m/s

function formatPace(speed as Number?) as String {
    if (speed == null || speed < STATIONARY_THRESHOLD) {
        return "-:--";
    }

    var secondsPerKm = Math.round(1.0 / (speed / 1000.0)).toNumber();
    var paceSeconds = secondsPerKm % 60;
    var paceMinutes = secondsPerKm / 60;
    return paceMinutes.format("%d") + ":" + paceSeconds.format("%02d");
}

function getWorkoutStepName(stepInfo as Activity.WorkoutStepInfo) {
    return stepInfo.name.length() > 0
                ? stepInfo.name
                : stepInfo.notes.length() > 0
                    ? stepInfo.notes
                    : intensityToString(stepInfo.intensity);
}

function max(a as Lang.Numeric, b as Lang.Numeric) as Lang.Numeric {
    return a > b ? a : b;
}

function min(a as Lang.Numeric, b as Lang.Numeric) as Lang.Numeric {
    return a < b ? a : b;
}

class BetterWorkoutView extends WatchUi.DataField {
    hidden var paceTargets as PaceTargets?;
    hidden var currentStepName as String?;
    hidden var nextStepName as String?;
    hidden var remainingTime as Number?;

    hidden var avgPace as Number?;
    hidden var currentSpeed as Number?;
    hidden var currentBpm as Number?;
    hidden var currentSpm as Number?;
    hidden var timerTime as Number?;

    hidden var currentStepStartTimerTime as Number?;
    hidden var currentStepStartDistance as Number?;
    
    hidden var currentStepTimerTime as Number?;
    hidden var currentStepAverageSpeed as Number?;

    function initialize() {
        DataField.initialize();

        currentSpeed = null;
        currentBpm = null;
        currentSpm = null;
        timerTime = null;

        avgPace = null;
        paceTargets = null;
        currentStepName = null;
        remainingTime = null;
        nextStepName = null;

        currentStepStartTimerTime = null;
        currentStepStartDistance = null;

        currentStepTimerTime = null;
        currentStepAverageSpeed = null;
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Void {
        var now = System.getTimer();

        currentBpm = info.currentHeartRate;
        currentSpm = info.currentCadence;
        currentSpeed = info.currentSpeed;
        timerTime = info.timerTime;

        if (currentStepStartTimerTime != null) {
            currentStepTimerTime = timerTime - currentStepStartTimerTime;

            if (currentStepStartDistance != null && info.elapsedDistance != null) {
                currentStepAverageSpeed = (info.elapsedDistance - currentStepStartDistance) / (currentStepTimerTime / 1000.0);
            } else {
                currentStepAverageSpeed = null;
            }
        } else {
            currentStepTimerTime = null;
            currentStepAverageSpeed = null;
        }
        
        if (!(Activity has : getCurrentWorkoutStep)) {
            avgPace = null;
            paceTargets = null;
            currentStepName = null;
            remainingTime = null;
            nextStepName = null;
            return;
        }

        var workoutStepInfo = Activity.getCurrentWorkoutStep();

        if (workoutStepInfo == null) {
            return;
        }

        currentStepName = getWorkoutStepName(workoutStepInfo);

        var step;
        if (workoutStepInfo.step instanceof Activity.WorkoutStep) {
            step = workoutStepInfo.step;
        } else {
            step = workoutStepInfo.step.activeStep;
        }

        if (currentStepTimerTime != null && step.durationType == Activity.WORKOUT_STEP_DURATION_TIME) {
            remainingTime =
                Math.round(step.durationValue * 1000.0).toNumber()
                - currentStepTimerTime;
        } else {
            remainingTime = null;
        }

        if (step.targetType == Activity.WORKOUT_STEP_TARGET_SPEED) {
            paceTargets = new PaceTargets(step.targetValueLow, step.targetValueHigh);
        } else {
            paceTargets = null;
        }

        var nextWorkoutStepInfo = Activity.getNextWorkoutStep();

        if (nextWorkoutStepInfo == null) {
            nextStepName = null;
            return;
        }

        nextStepName = getWorkoutStepName(nextWorkoutStepInfo);
    }

    function drawPaceGauge(ctx as GraphicsContext) as Void {
        if (paceTargets == null) {
            return;
        }

        var size = ctx.getSize();
        var width = size.getWidth();
        var height = size.getHeight();

        var radius = width / 2;

        var redArcStartAngle = Math.PI / 22;
        var redArcEndAngle = Math.PI - Math.PI / 22;
        var greenArcStartAngle = Math.PI / 5;
        var greenArcEndAngle = 4 * Math.PI / 5;
        var redGreenDistPx = 2.0;
        var redGreenAngleDiff = redGreenDistPx / radius;
        var fontDistPx = 8.0;
        var fontAngleDiff = fontDistPx / radius;

        var highStrokeWidth;
        var targetStrokeWidth;
        var lowStrokeWidth;
        var arrowAngle;
        var targetRange = paceTargets.getHigh() - paceTargets.getLow();
        var sideRange = targetRange / 2;
        if (currentSpeed > paceTargets.getHigh()) {
            highStrokeWidth = ACTIVE_STROKE_WIDTH;
            targetStrokeWidth = INACTIVE_STROKE_WIDTH;
            lowStrokeWidth = INACTIVE_STROKE_WIDTH;
            arrowAngle =
                redArcStartAngle
                + 
                    (greenArcStartAngle - redArcStartAngle)
                    * (1.0 - min(1.0, (currentSpeed - paceTargets.getHigh()) / sideRange));
        } else if (currentSpeed < paceTargets.getLow()) {
            highStrokeWidth = INACTIVE_STROKE_WIDTH;
            targetStrokeWidth = INACTIVE_STROKE_WIDTH;
            lowStrokeWidth = ACTIVE_STROKE_WIDTH;
            arrowAngle =
                greenArcEndAngle
                + 
                    (redArcEndAngle - greenArcEndAngle)
                    * min(1.0, (paceTargets.getLow() - currentSpeed) / sideRange);
        } else {
            highStrokeWidth = INACTIVE_STROKE_WIDTH;
            targetStrokeWidth = ACTIVE_STROKE_WIDTH;
            lowStrokeWidth = INACTIVE_STROKE_WIDTH;
            arrowAngle =
                greenArcStartAngle
                +
                    (greenArcEndAngle - greenArcStartAngle)
                    * (1.0 - (currentSpeed - paceTargets.getLow()) / targetRange);
        }
 
        ctx.setColor(0xC00000);
        ctx.setStrokeWidth(highStrokeWidth);
        ctx.drawArc(new Point(width / 2, height / 2), radius - ACTIVE_STROKE_WIDTH + highStrokeWidth / 2, redArcStartAngle, greenArcStartAngle - redGreenAngleDiff);
        ctx.setStrokeWidth(lowStrokeWidth);
        ctx.drawArc(new Point(width / 2, height / 2), radius - ACTIVE_STROKE_WIDTH + lowStrokeWidth / 2, greenArcEndAngle + redGreenAngleDiff, redArcEndAngle);
        
        ctx.setColor(0x00FF00);
        ctx.setStrokeWidth(targetStrokeWidth);
        ctx.drawArc(new Point(width / 2, height / 2), radius - ACTIVE_STROKE_WIDTH + targetStrokeWidth / 2, greenArcStartAngle, greenArcEndAngle);
    
        drawPaceArrow(ctx, arrowAngle);
    }

    function drawPaceArrow(ctx as GraphicsContext, arrowAngle as Float) as Void {
        var size = ctx.getSize();
        var width = size.getWidth();
        var height = size.getHeight();

        var radius = width / 2;

        var arrowBorder = 2.0;
        var arrowWidth = 11.0;
        var arrowHeight = 14.0;
        var arrowBorderOffset = ACTIVE_STROKE_WIDTH / 2;
        var x = radius * Math.cos(arrowAngle) + width / 2;
        var y = radius * -Math.sin(arrowAngle) + height / 2;
        ctx.setColor(0x000000);
        ctx.drawArrowAtDist(
            new Point(x, y),
            // The border offset is not correct here: it depends on the arrow angle.
            new Size(arrowWidth + arrowBorder, arrowHeight + arrowBorder),
            arrowAngle,
            arrowBorderOffset
        );
        ctx.setColor(0xFFFFFF);
        ctx.drawArrowAtDist(
            new Point(x, y),
            new Size(arrowWidth, arrowHeight),
            arrowAngle,
            arrowBorderOffset + arrowBorder * 2
        );
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc as Dc) as Void {
        var ctx = new GraphicsContext(dc);
        ctx.init();

        drawPaceGauge(ctx);

        var size = ctx.getSize();
        var width = size.getWidth();
        var height = size.getHeight();

        // Avg pace
        var sepOffsetPx = 6.0;
        var currentStepAvgPace = formatPace(currentStepAverageSpeed);
        var currentStepAvgPaceLineHeight = height * 0.17;
        var avgDims = ctx.textDimensions("AVG", Graphics.FONT_SYSTEM_XTINY);
        var currentStepAvgPaceDims = ctx.textDimensions(currentStepAvgPace, Graphics.FONT_GLANCE);
        var lineWidth = avgDims[0] + sepOffsetPx + currentStepAvgPaceDims[0];
        var lineStart = width / 2 - lineWidth / 2;
        var avgStart = Math.round(lineStart);
        ctx.setColor(0x808080);
        ctx.drawText(new Point(avgStart, currentStepAvgPaceLineHeight), "AVG", Graphics.FONT_SYSTEM_XTINY, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var currentStepAvgPaceStart = Math.round(avgStart + avgDims[0] + sepOffsetPx);
        ctx.setColor(0xFFFFFF);
        ctx.drawText(new Point(currentStepAvgPaceStart, currentStepAvgPaceLineHeight), currentStepAvgPace, Graphics.FONT_GLANCE, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Current pace
        var pacePoint = new Point(
            width / 2,
            height * 0.32
        );
        ctx.setColor(0xFFFFFF);
        ctx.drawText(pacePoint, formatPace(currentSpeed), Graphics.FONT_NUMBER_HOT, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Step name
        if (currentStepName != null) {
            ctx.setColor(0xFFFFFF);
            ctx.drawText(new Point(width / 2, height * 0.5), currentStepName, Graphics.FONT_SYSTEM_SMALL, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Pace limits
        if (paceTargets != null) {
            ctx.setColor(0xFFFFFF);
            var paceLimitsDistPx = 6.0;
            var paceLimitsBaselineAdjustmentPx = 26.0;

            var limitHighPoint = new Point(width, height * 0.5);
            ctx.drawText(limitHighPoint, formatPace(paceTargets.getHigh()), Graphics.FONT_GLANCE, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

            var limitLowPoint = new Point(0, height * 0.5);
            ctx.drawText(limitLowPoint, formatPace(paceTargets.getLow()), Graphics.FONT_GLANCE, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        
        if (nextStepName != null) {
            var thenNextLineHeight = height * 0.6;
            var thenDims = ctx.textDimensions("THEN", Graphics.FONT_SYSTEM_XTINY);
            var nextDims = ctx.textDimensions(nextStepName, Graphics.FONT_GLANCE);
            var thenNextLineWidth = thenDims[0] + sepOffsetPx + nextDims[0];
            var thenNextLineStart = width / 2 - thenNextLineWidth / 2;
            var thenStart = Math.round(thenNextLineStart);
            ctx.setColor(0x808080);
            ctx.drawText(new Point(thenStart, thenNextLineHeight), "THEN", Graphics.FONT_SYSTEM_XTINY, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            var nextStart = Math.round(thenStart + thenDims[0] + sepOffsetPx);
            ctx.setColor(0xFFFFFF);
            ctx.drawText(new Point(nextStart, thenNextLineHeight), nextStepName, Graphics.FONT_GLANCE, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var nextRowHeight = height * 0.645;
        var sizeMeasuresAlignmentX = 0.18;
        var xtinySepPx = 14.0;

        ctx.setColor(0x808080);
        ctx.drawText(new Point(width * sizeMeasuresAlignmentX, nextRowHeight), "BPM", Graphics.FONT_SYSTEM_XTINY, Graphics.TEXT_JUSTIFY_CENTER);
        ctx.setColor(0xFFFFFF);
        ctx.drawText(new Point(width * sizeMeasuresAlignmentX, nextRowHeight + xtinySepPx), currentBpm != null ? currentBpm.format("%d") : "-", Graphics.FONT_SYSTEM_SMALL, Graphics.TEXT_JUSTIFY_CENTER);

        ctx.setColor(0x808080);
        ctx.drawText(new Point(width * 0.5, nextRowHeight), "REM", Graphics.FONT_SYSTEM_XTINY, Graphics.TEXT_JUSTIFY_CENTER);
        ctx.setColor(0xFFFFFF);
        ctx.drawText(new Point(width * 0.5, nextRowHeight + xtinySepPx), formatTimeMs(remainingTime), Graphics.FONT_SYSTEM_SMALL, Graphics.TEXT_JUSTIFY_CENTER);

        ctx.setColor(0x808080);
        ctx.drawText(new Point(width * (1.0 - sizeMeasuresAlignmentX), nextRowHeight), "SPM", Graphics.FONT_SYSTEM_XTINY, Graphics.TEXT_JUSTIFY_CENTER);
        ctx.setColor(0xFFFFFF);
        ctx.drawText(new Point(width * (1.0 - sizeMeasuresAlignmentX), nextRowHeight + xtinySepPx), currentSpm != null ? currentSpm.format("%d") : "-", Graphics.FONT_SYSTEM_SMALL, Graphics.TEXT_JUSTIFY_CENTER);

        var lastRowHeight = height * 0.82;

        ctx.setColor(0x808080);
        ctx.drawText(new Point(width * 0.5, lastRowHeight), "TIME", Graphics.FONT_SYSTEM_XTINY, Graphics.TEXT_JUSTIFY_CENTER);
        ctx.setColor(0xFFFFFF);
        ctx.drawText(
            new Point(width * 0.5, lastRowHeight + xtinySepPx),
            formatTimeMs(timerTime),
            Graphics.FONT_SYSTEM_SMALL,
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }

    function onWorkoutStarted() as Void {
        var info = Activity.getActivityInfo();
        currentStepStartTimerTime = info.timerTime;
        // info.elapsedDistance is sometimes null when this is called.
        currentStepStartDistance = info.elapsedDistance == null ? 0.0 : info.elapsedDistance;
    }

    function onWorkoutStepComplete() as Void {
        var info = Activity.getActivityInfo();
        currentStepStartTimerTime = info.timerTime;
        currentStepStartDistance = info.elapsedDistance;
    }

    function onTimerStart() as Void {
    }

    function onTimerPause() as Void {
    }

    function onTimerStop() as Void {
    }

    function onTimerReset() as Void {
    }

    function onTimerResume() as Void {
    }
}
