class Point {
    protected var x as Float;
    protected var y as Float;

    function initialize(x as Float, y as Float) as Void {
        self.x = x;
        self.y = y;
    }

    function toArray() as Array {
        return [x, y];
    }

    function getX() as Float {
        return x;
    }

    function getY() as Float {
        return y;
    }

    function neg() as Point {
        return new Point(-x, -y);
    }

    function add(other as Point) as Point {
        return new Point(x + other.x, y + other.y);
    }

    function sub(other as Point) as Point {
        return new Point(x - other.x, y - other.y);
    }

    function mul(scalar as Float) as Point {
        return new Point(x * scalar, y * scalar);
    }

    function div(scalar as Float) as Point {
        return new Point(x / scalar, y / scalar);
    }

    function rotate(origin as Point, angle as Float) as Point {
        return new Point(
            Math.cos(-angle) * (x - origin.x) - Math.sin(-angle) * (y - origin.y) + origin.x,
            Math.sin(-angle) * (x - origin.x) + Math.cos(-angle) * (y - origin.y) + origin.y
        );
    }

    function dist(other as Point) as Float {
        return Math.sqrt(Math.pow(x - other.x, 2) + Math.pow(y - other.y, 2));
    }
}