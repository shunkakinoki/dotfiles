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
    eval (keychain --eval --quiet --confirm ~/.ssh/id_ed25519_github)

    # Verify the key was added
    if ssh-add -l | grep -q "id_ed25519_github"
        echo "✅ GitHub SSH key added successfully"
        echo "🧪 Testing GitHub connection..."
        ssh -T git@github.com
    else
        echo "❌ Failed to add GitHub SSH key"
        return 1
    end
end
