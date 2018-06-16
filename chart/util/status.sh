#!/bin/bash

release=$(<release)

helm status $release
