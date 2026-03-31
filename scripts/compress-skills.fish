#!/usr/bin/env fish
# Compress Claude Code skill descriptions to reduce context token usage
# Usage: fish scripts/compress-skills.fish [--dry-run] [--whitelist skills.txt]

set skills_dir ~/.claude/skills
set dry_run false
set whitelist_file ""

# Parse args
for i in (seq (count $argv))
    switch $argv[$i]
        case --dry-run
            set dry_run true
        case --whitelist
            set whitelist_file $argv[(math $i + 1)]
    end
end

# If whitelist provided, remove non-whitelisted skills
if test -n "$whitelist_file" -a -f "$whitelist_file"
    set whitelisted (cat $whitelist_file | string trim | grep -v '^#' | grep -v '^\s*$')
    set removed 0
    for d in $skills_dir/*/
        set name (basename $d)
        if not contains $name $whitelisted
            if test "$dry_run" = true
                echo "Would remove: $name"
            else
                rm -rf $d
                echo "Removed: $name"
            end
            set removed (math $removed + 1)
        end
    end
    echo "Removed $removed skills"
    exit 0
end

# Otherwise, compress all remaining skill descriptions
set total 0
set compressed 0
for d in $skills_dir/*/
    set name (basename $d)
    set skill_file "$d/SKILL.md"
    test -f $skill_file; or continue
    set total (math $total + 1)

    # Get current description length (word count)
    set desc (head -5 $skill_file | grep "^description:" | head -1 | sed 's/^description: *//' | sed "s/^'//" | sed "s/'$//")
    set word_count (echo $desc | wc -w | string trim)

    if test $word_count -gt 30
        if test "$dry_run" = true
            echo "[$word_count words] $name"
        end
        set compressed (math $compressed + 1)
    end
end

echo ""
echo "Total skills: $total"
echo "Skills with description > 30 words: $compressed"
echo ""
echo "To remove unused skills, create a whitelist file and run:"
echo "  fish scripts/compress-skills.fish --whitelist skills-whitelist.txt"
