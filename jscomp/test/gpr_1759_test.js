'use strict';

var Caml_obj   = require("../../lib/js/caml_obj.js");
var Pervasives = require("../../lib/js/pervasives.js");

Pervasives.print_int(Caml_obj.caml_compare(Pervasives.print_string(""), /* () */0));

Pervasives.print_string(/* () */0 !== Pervasives.print_string("") ? "true" : "false");

/*  Not a pure module */
