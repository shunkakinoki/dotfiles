set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_cliproxyapi_function.fish

set call_log (mktemp)

# Mock uname to Linux for consistent CI behavior
function uname; echo Linux; end
function systemctl; echo $argv >> $call_log; end
function journalctl; end

_cliproxyapi_function 2>/dev/null; true

@test "linux path restarts cliproxyapi" (grep -c "restart cliproxyapi" $call_log) -ge 1

rm -f $call_log
