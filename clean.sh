#!/bin/bash

docker rm -f ton-node
docker volume rm ton-db
git clean -fdX
