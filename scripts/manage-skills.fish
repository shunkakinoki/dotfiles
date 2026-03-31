#!/usr/bin/env fish
# Manage Claude Code skills - archive unused skills to reduce context token usage
# Usage:
#   fish scripts/manage-skills.fish status        # Show current stats
#   fish scripts/manage-skills.fish archive       # Move non-whitelisted to archive
#   fish scripts/manage-skills.fish restore       # Restore all archived skills
#   fish scripts/manage-skills.fish restore NAME  # Restore specific skill

set skills_dir ~/.claude/skills
set archive_dir ~/.claude/skills-archive

# Skills to KEEP - relevant to dotfiles/infra/dev workflow
set whitelist \
    # Git/PR workflow
    commit \
    commit-lint \
    conventional-commit \
    create-branch \
    git-commit \
    pr-create \
    pr-label \
    pr-writer \
    iterate-pr \
    my-pull-requests \
    my-issues \
    gh-cli \
    gh-review-requests \
    using-gh-cli \
    using-git-worktrees \
    # Code quality
    biome-js \
    code-review \
    code-simplifier \
    code-simplify \
    code-polish \
    find-bugs \
    refactor \
    # Architecture/planning
    architecture \
    system-design \
    create-implementation-plan \
    prd-to-plan \
    # DevOps/infra
    deploy-checklist \
    devcontainer-setup \
    multi-stage-dockerfile \
    cloudflare \
    durable-objects \
    workers-best-practices \
    wrangler \
    # Security
    security-review \
    secret-scanning \
    gha-security-review \
    dependabot \
    # MCP/agents
    build-mcp-server \
    build-mcp-app \
    mcp-cli \
    mcp-configure \
    mcp-integration \
    agents-sdk \
    agents-md \
    agent-development \
    # Claude Code specific
    claude-md-improver \
    claude-settings-audit \
    claude-automation-recommender \
    hook-development \
    writing-hookify-rules \
    skill-creator \
    skill-writer \
    # Languages/tools used in dotfiles
    modern-python \
    antfu \
    effect-ts \
    tailwind-css \
    pnpm \
    turborepo \
    editorconfig \
    changesets \
    bump-deps \
    bump-release \
    # Testing
    tdd \
    test-driven-development \
    testing-strategy \
    vitest \
    # Nix (not a skill but keep related)
    # Docs
    documentation \
    documentation-writer \
    create-readme \
    # Debug
    debug \
    systematic-debugging \
    # Misc useful
    macos-screenshot \
    chrome-devtools \
    linear-cli \
    github-issues \
    serena \
    qmd \
    web-search \
    web-research

switch $argv[1]
    case status
        set total (ls -d $skills_dir/*/ 2>/dev/null | wc -l | string trim)
        set archived (ls -d $archive_dir/*/ 2>/dev/null | wc -l | string trim)
        echo "Active skills: $total"
        echo "Archived skills: $archived"
        echo "Whitelisted: "(count $whitelist)
        echo ""
        echo "Would archive: "(math $total - (count $whitelist))" skills"

    case archive
        mkdir -p $archive_dir
        set moved 0
        for d in $skills_dir/*/
            set name (basename $d)
            if not contains $name $whitelist
                mv $d $archive_dir/
                set moved (math $moved + 1)
            end
        end
        set remaining (ls -d $skills_dir/*/ 2>/dev/null | wc -l | string trim)
        echo "Archived $moved skills to $archive_dir"
        echo "Remaining active: $remaining"

    case restore
        if test (count $argv) -gt 1
            # Restore specific skill
            set name $argv[2]
            if test -d $archive_dir/$name
                mv $archive_dir/$name $skills_dir/
                echo "Restored: $name"
            else
                echo "Not found in archive: $name"
            end
        else
            # Restore all
            set count 0
            for d in $archive_dir/*/
                mv $d $skills_dir/
                set count (math $count + 1)
            end
            echo "Restored $count skills"
        end

    case list-archive
        ls $archive_dir/ 2>/dev/null; or echo "No archived skills"

    case '*'
        echo "Usage: manage-skills.fish [status|archive|restore|restore NAME|list-archive]"
end
