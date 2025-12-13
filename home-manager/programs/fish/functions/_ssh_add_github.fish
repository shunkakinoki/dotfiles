function _ssh_add_github --description "Add GitHub SSH key to ssh-agent"
    # Check if key exists
    if not test -f ~/.ssh/id_ed25519_github
        echo "❌ GitHub SSH key not found at ~/.ssh/id_ed25519_github"
        return 1
    end

    # Check if keychain is available
    if not command -v keychain >/dev/null
        echo "❌ keychain not found. Please install keychain."
        return 1
    end

    # Initialize keychain and add the GitHub key
    echo "🔑 Adding GitHub SSH key to keychain..."
    # Use bash to evaluate keychain output, then use ssh-add
    bash -c 'eval $(keychain --eval --quiet --confirm ~/.ssh/id_ed25519_github 2>/dev/null); ssh-add -l' >/dev/null 2>&1

    # Alternative: directly use ssh-add if keychain already initialized ssh-agent
    if not ssh-add -l >/dev/null 2>&1
        # Start ssh-agent if not running
        eval (ssh-agent -c)
    end

    # Add the key directly
    ssh-add ~/.ssh/id_ed25519_github

    # Verify the key was added (check for either the filename or email)
    if ssh-add -l | grep -qE "(id_ed25519_github|shunkakinoki@gmail.com)"
        echo "✅ GitHub SSH key added successfully"
        echo "🧪 Testing GitHub connection..."
        ssh -T git@github.com
        return 0
    else
        echo "⚠️  Could not verify key was added, but ssh-add may have succeeded"
        echo "🧪 Testing GitHub connection anyway..."
        ssh -T git@github.com
        return $status
    end
end
