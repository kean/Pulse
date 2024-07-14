#!/bin/sh

version=$1

swift doc generate ./Sources \
    --module-name Pulse \
    --format html \
    --base-url "https://kean-org.github.io/docs/pulse/$version"
