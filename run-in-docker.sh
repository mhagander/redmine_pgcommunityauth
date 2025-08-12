#!/bin/sh
set -e

docker build -t redmine-pgcommunityauth:dev .
docker run -it --rm -p 9292:9292 redmine-pgcommunityauth:dev
