import Toybox.Lang;

class Stack {
    private var stack;

    function initialize() {
        self.stack = null;
    }

    function push(x) as Void {
        stack = [x, stack];
    }

    function pop() {
        if (empty()) {
            throw new EmptyStackException();
        }

        var ret = stack[0];
        stack = stack[1];
        return ret;
    }

    function empty() as Boolean {
        return stack == null;
    }
}


class EmptyStackException extends Lang.Exception {
    function initialize() {
        Exception.initialize();
    }
}