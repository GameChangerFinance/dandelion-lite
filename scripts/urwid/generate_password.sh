#!/bin/bash

tr -dc 'A-Za-z0-9' </dev/urandom | fold -w 16 | head -n1