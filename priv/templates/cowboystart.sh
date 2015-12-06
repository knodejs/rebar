#!/bin/sh
erl +pc unicode -pa $PWD/ebin $PWD/deps/*/ebin $NOSHELL -s {{appid}}  -sname {{appid}}_dev
