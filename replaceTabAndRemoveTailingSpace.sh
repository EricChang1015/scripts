#!/bin/bash

sed -i 's/\t/    /g' $@
sed -i -E "s/[ ]+$//g" $@
