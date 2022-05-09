import Toybox.System;

module MyLog {
    function log(something) as Void {
        System.println(something);
    }
    
    function logd(dict as Dictionary) as Void {
        for (var i = 0; i < dict.size(); i++ ) {
            var key = dict.keys()[i];
            var value = dict.values()[i];
            System.println(key.toString() + "=" + (value == null ? "null" : value));
        }
    }
}