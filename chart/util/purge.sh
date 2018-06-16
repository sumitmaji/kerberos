#!/bin/bash

release=$(<release)
helm del --purge $release
