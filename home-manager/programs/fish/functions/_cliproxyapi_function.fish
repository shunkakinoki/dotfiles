function _cliproxyapi_function --description "Start cliproxyapi service"
    if test (uname) = Darwin
        cd ~/.cli-proxy-api && /opt/homebrew/bin/cliproxyapi -config config.yaml
    else
        systemctl --user restart cliproxyapi && journalctl --user -u cliproxyapi -f
    end
end
