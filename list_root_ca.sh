#!/bin/bash
for d in $(ls -d */); do echo "${d%%/}"; done
