#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Docker publishing defaults'
It 'binds default and newly created bridge networks to loopback'
When run jq -e '.ip == "127.0.0.1" and ."default-network-opts".bridge."com.docker.network.bridge.host_binding_ipv4" == "127.0.0.1"' home-manager/services/docker/daemon.json
The status should be success
The output should equal 'true'
End

It 'keeps containers running across a dockerd restart'
When run bash -c "jq -e '.\"live-restore\" == true' home-manager/services/docker/daemon.json && grep -x 'KillMode=process' home-manager/services/docker/docker.service"
The status should be success
The output should include 'KillMode=process'
End
End
