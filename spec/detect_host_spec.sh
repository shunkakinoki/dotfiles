#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'scripts/detect-host.sh'
SCRIPT="$PWD/scripts/detect-host.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'Linux detection'
It 'maps a Framework 13 AMD Ryzen AI 300 board to matic'
When run env OS=Linux ARCH=x86_64 DMI_SYS_VENDOR=Framework \
  DMI_PRODUCT_NAME='Laptop 13 (AMD Ryzen AI 300 Series)' \
  RUNPOD_POD_ID= bash "$SCRIPT"
The status should be success
The output should equal 'matic'
End

It 'prefers a RunPod pod over DMI data'
When run env OS=Linux ARCH=x86_64 DMI_SYS_VENDOR=Framework \
  DMI_PRODUCT_NAME='Laptop 13 (AMD Ryzen AI 300 Series)' \
  RUNPOD_POD_ID=abc123 bash "$SCRIPT"
The status should be success
The output should equal 'pod'
End

It 'ignores a Framework board that is not the AMD Ryzen AI 300 model'
When run env OS=Linux ARCH=x86_64 DMI_SYS_VENDOR=Framework \
  DMI_PRODUCT_NAME='Laptop 13 (12th Gen Intel Core)' \
  RUNPOD_POD_ID= bash "$SCRIPT"
The status should be success
The output should equal ''
End

It 'ignores matching product data from another vendor'
When run env OS=Linux ARCH=x86_64 DMI_SYS_VENDOR=Acme \
  DMI_PRODUCT_NAME='Laptop 13 (AMD Ryzen AI 300 Series)' \
  RUNPOD_POD_ID= bash "$SCRIPT"
The status should be success
The output should equal ''
End

It 'reports no host when there is no DMI data'
When run env OS=Linux ARCH=x86_64 DMI_SYS_VENDOR= DMI_PRODUCT_NAME= \
  RUNPOD_POD_ID= bash "$SCRIPT"
The status should be success
The output should equal ''
End
End

Describe 'Darwin detection'
It 'reports no host on a non-arm64 Mac'
When run env OS=Darwin ARCH=x86_64 bash "$SCRIPT"
The status should be success
The output should equal ''
End
End

Describe 'unknown platforms'
It 'reports no host'
When run env OS=Plan9 ARCH=x86_64 bash "$SCRIPT"
The status should be success
The output should equal ''
End

It 'reports no host when OS is unset'
When run env -u OS ARCH=x86_64 bash "$SCRIPT"
The status should be success
The output should equal ''
End
End
End
