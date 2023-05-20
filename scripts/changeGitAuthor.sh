#!/bin/bash
git filter-branch --commit-filter '
if [ "$GIT_AUTHOR_EMAIL" = "lihu@eventslack.com" ]; 
then 
    GIT_AUTHOR_NAME="lihu"; 
    GIT_AUTHOR_EMAIL="1449488533qq@gmail.com"; 
    git commit-tree "$@"; 
else 
    git commit-tree "$@"; fi' HEAD

