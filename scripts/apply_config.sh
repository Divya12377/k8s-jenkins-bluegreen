#!/bin/bash

echo "Applying Jenkins plugin configurations..."

if [ -f /var/jenkins_home/plugins.txt ]; then
    echo "Installing plugins from plugins.txt"
    /usr/local/bin/install-plugins.sh < /var/jenkins_home/plugins.txt
else
    echo "No plugins.txt found!"
fi

