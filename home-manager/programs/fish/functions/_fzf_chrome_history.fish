function _fzf_chrome_history --description="fzf Chrome history"
    # Chrome history database location (macOS)
    set -l chrome_history "$HOME/Library/Application Support/Google/Chrome/Default/History"

    # Check if Chrome history exists
    if not test -f "$chrome_history"
        echo "Chrome history not found at: $chrome_history"
        return 1
    end

    # Copy database to temp file (Chrome locks the original)
    set -l tmp_db (mktemp)
    cp "$chrome_history" "$tmp_db"

    # Query history: url, title, date (sorted by recency, deduplicated by title)
    # Chrome stores time as microseconds since 1601-01-01, we convert to Unix epoch
    set -l query "
        SELECT
            url,
            title,
            datetime(last_visit_time/1000000 + strftime('%s', '1601-01-01'), 'unixepoch', 'localtime') as date
        FROM urls
        GROUP BY title
        ORDER BY last_visit_time DESC
        LIMIT 10000
    "

    # Run sqlite3 query, format output, and pipe to fzf
    set -l selected (sqlite3 -separator '	' "$tmp_db" "$query" 2>/dev/null | \
        awk -F '\t' '{printf "%s\t%s\t%s\n", $3, $2, $1}' | \
        fzf --prompt=(_fzf_preview_name "Chrome History") \
            --no-color \
            --delimiter='\t' \
            --with-nth=1,2 \
            --preview='echo {3}' \
            --preview-window=down:1)

    # Cleanup temp file
    rm -f "$tmp_db"

    if test -n "$selected"
        # Extract URL (third field)
        set -l url (echo "$selected" | awk -F '\t' '{print $3}')

        if test -n "$url"
            open "$url"
        end
    end

    commandline --function repaint
end
