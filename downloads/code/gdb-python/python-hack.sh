#!/bin/bash
#
# Copyright 2016 by Bill Torpey. All Rights Reserved.
# This work is licensed under a Creative Commons Attribution-NonCommercial-NoDerivs 3.0 United States License.
# http://creativecommons.org/licenses/by-nc-nd/3.0/us/deed.en
#

# fugly hack for python support
# (see https://sourceware.org/gdb/wiki/CrossCompilingWithPythonSupport)

PYTHON_DIR=$(cd $(dirname $(which python))/.. && /bin/pwd)
#echo $PYTHON_DIR

# The first argument is the path to python-config.py, ignore it.
case "$2" in
   --includes)       echo "$($PYTHON_DIR/bin/python-config --includes)" ;;
   --ldflags)        echo -n "-L$PYTHON_DIR/lib "; echo "$($PYTHON_DIR/bin/python-config --ldflags)" ;;
   --exec-prefix)    echo "$($PYTHON_DIR/bin/python-config --exec-prefix)" ;;
   *) echo "Bad arg $2.  Blech!" >&2 ; exit 1 ;;
esac

exit 0