#!/bin/bash
ls -al

echo "Run tests $COVERAGE"
$COVERAGE ./dot.sh -M
