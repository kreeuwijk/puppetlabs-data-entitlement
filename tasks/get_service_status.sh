#!/bin/sh
set -e

# Puppet Task Name: get_service_status
#
# This task gets the status of the HDP docker-compose services.
#
cd /opt/puppetlabs/data_entitlement
docker-compose ps
