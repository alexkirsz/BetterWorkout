class Size {
    protected var width as Float;
    protected var height as Float;

    function initialize(width as Float, height as Float) as Void {
        self.width = width;
        self.height = height;
    }

    function toArray() as Array {
        return [width, height];
    }

    function getWidth() as Float {
        return width;
    }

    function getHeight() as Float {
        return height;
    }

    function neg() as Size {
        return new Size(-x, -y);
    }

    function add(other as Size) as Size {
        return new Size(x + other.x, y + other.y);
    }

    function sub(other as Size) as Size {
        return new Size(x - other.x, y - other.y);
    }

    function mul(scalar as Float) as Size {
        return new Size(x * scalar, y * scalar);
    }

    function div(scalar as Float) as Size {
        return new Size(x / scalar, y / scalar);
    }
}