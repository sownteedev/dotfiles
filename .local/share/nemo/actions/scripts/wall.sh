#!/bin/bash

type=$(echo 'beautiful = require("beautiful"); return beautiful.type' | awesome-client | sed -e 's/string //' -e 's/"//g' | xargs)
ESC_WP_PATH=$(printf %q "$1")
awesome-client "changewall(\"$ESC_WP_PATH\", \"$type\")"
