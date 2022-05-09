import Toybox.Graphics;
import Toybox.Math;
import Toybox.Lang;

class GraphicsContextState {
    public var foreground as Graphics.ColorType;
    public var background as Graphics.ColorType;
    public var strokeWidth as Number;

    function initialize(foreground as Graphics.ColorType, background as Graphics.ColorType, strokeWidth as Number) {
        self.foreground = foreground;
        self.background = background;
        self.strokeWidth = strokeWidth;
    }

    function withForeground(foreground as Graphics.ColorType) as GraphicsContextState {
        return new GraphicsContextState(
            foreground,
            self.background,
            self.strokeWidth
        );
    }

    function withBackground(background as Graphics.ColorType) as GraphicsContextState {
        return new GraphicsContextState(
            self.foreground,
            background,
            self.strokeWidth
        );
    }

    function withStrokeWidth(strokeWidth as Number) as GraphicsContextState {
        return new GraphicsContextState(
            self.foreground,
            self.background,
            strokeWidth
        );
    }

    function apply(dc as Dc) {
        dc.setColor(self.foreground, self.background);
        dc.setPenWidth(self.strokeWidth);
    }
}

class RestoreException extends Lang.Exception {
    function initialize() {
        Exception.initialize();
    }
}

class GraphicsContext {
    private var dc as Dc;
    private var state as GraphicsContextState;
    private var prevStates as Stack;
    private var size as Size;

    function initialize(dc as Dc) as Void {
        self.dc = dc;
        self.state = new GraphicsContextState(
            0xFFFFFF,
            0x000000,
            1
        );
        self.prevStates = new Stack();
        self.size = new Size(dc.getWidth().toFloat(), dc.getHeight().toFloat());
    }

    function init() as Void {
        state.apply(dc);
        dc.clear();
        dc.setAntiAlias(true);
        state = state.withBackground(Graphics.COLOR_TRANSPARENT);
        state.apply(dc);
    }

    function save() as Void {
        self.prevStates.push(state);
    }

    function restore() as Void {
        try {
            state = self.prevStates.pop();
        } catch (e instanceof EmptyStackException) {
            throw new RestoreException();
        }
        state.apply(dc);
    }

    function getSize() as Size {
        return size;
    }

    function setColor(color as Number) as Void {
        state = state.withForeground(color);
        state.apply(dc);
    }

    function setStrokeWidth(strokeWidth as Number) as Void {
        state = state.withStrokeWidth(strokeWidth);
        state.apply(dc);
    }

    function debugPoint(p as Point) as Void {
        save();
        setColor(0xFFFFFF);
        drawDisc(p, 5);
        restore();
    }

    function drawRectangle(p as Point, s as Size) as Void {
        dc.fillRectangle(p.getX(), p.getY(), s.getWidth(), s.getHeight());
    }

    function drawDisc(c as Point, r as Float) as Void {
        dc.fillCircle(c.getX(), c.getY(), r);
    }

    function drawArc(c as Point, r as Float, from as Float, to as Float) as Void {
        dc.drawArc(
            c.getX(),
            c.getY(),
            r,
            Graphics.ARC_COUNTER_CLOCKWISE,
            // Unfortunately, the API expects degrees as integers and will truncate floats.
            Math.round(Math.toDegrees(from)),
            Math.round(Math.toDegrees(to))
        );
    }

    function drawArrow(p as Point, size as Size, angle as Float) as Void {
        var p1 = p;
        var p2 = p.add(new Point(size.getWidth() / 2, size.getHeight())).rotate(p, angle - Math.PI / 2);
        var p3 = p.add(new Point(-size.getWidth() / 2, size.getHeight())).rotate(p, angle - Math.PI / 2);
        dc.fillPolygon([
            p1.toArray(),
            p2.toArray(),
            p3.toArray()
        ]);
    }

    function drawArrowAtDist(p as Point, size as Size, angle as Float, dist as Float) as Void {
        drawArrow(p.add(new Point(dist, 0)).rotate(p, angle + Math.PI), size, angle);
    }

    function drawText(p as Point, text as String, font as Graphics.FontDefinition, justification as Graphics.TextJustification) as Void {
        dc.drawText(
            // Text is pixel perfect, so it doesn't make sense to pass floats.
            Math.round(p.getX()),
            Math.round(p.getY()),
            font,
            text,
            justification
        );
    }

    function textDimensions(text as String, font as Graphics.FontDefinition) as Array<Number> {
        return dc.getTextDimensions(text, font);
    }
}
