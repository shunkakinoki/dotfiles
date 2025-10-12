# Claude Code Notifications on Your Wrist

Get Claude Code notifications on your smartwatch so you never miss when Claude is waiting for your input or needs permission.

## Overview

When working with Claude Code, it sometimes stops to request tool usage permissions or waits for user input. If the terminal is hidden or you're working on something else, you might miss these prompts, causing unnecessary delays.

This setup sends push notifications to your phone and smartwatch whenever Claude needs your attention.

## Prerequisites

- [Pushover](https://pushover.net/) account (30-day free trial, then $4.99 one-time purchase)
- Pushover app installed on your phone
- Smartwatch configured to receive phone notifications
- `jq` command-line tool (`brew install jq` on macOS)

## Pushover Setup

### 1. Create Account and Get Keys

1. Sign up at [Pushover.net](https://pushover.net/)
2. From your user dashboard, note your **User Key**
3. Create a new application under "Your Applications"
4. Note the **API Token** for your application

### 2. Configure Environment Variables

Add these to your shell configuration (~/.zshrc, ~/.bashrc, or ~/.config/fish/config.fish):

```bash
export PUSHOVER_API_TOKEN=your_pushover_api_token
export PUSHOVER_USER_KEY=your_pushover_user_key
```

**Security Warning**: Keep these keys secret! Anyone with access to them can send notifications to your devices.

### 3. Test the Setup

After setting the environment variables, test the notification:

```bash
curl -s \
    --form-string "token=${PUSHOVER_API_TOKEN}" \
    --form-string "user=${PUSHOVER_USER_KEY}" \
    --form-string "message=This is a test message" \
    --form-string "device=iphone15" \
    --form-string "title=Test Notification" \
    https://api.pushover.net/1/messages.json
```

You should receive a notification on your Pushover app. If you don't specify a device, the notification goes to all your registered devices.

### 4. Connect Smartwatch

Follow your smartwatch's instructions to enable notifications from your phone. For example:

- **Apple Watch**: Notifications mirror from iPhone by default
- **Android Wear**: Configure in the Wear OS app
- **Other devices**: Check your device's notification settings

## How It Works

The notification system uses Claude Code hooks to keep you informed of important events. By default, only essential notifications are enabled:

### Active Notifications

#### Notification Hook (High Priority)

Triggers when Claude needs your attention:

1. **"Claude is waiting for your input"** - Claude finished a task and is waiting for you
   - Sends: "⏸️ Waiting for your input" (high priority)

2. **"Claude needs your permission to use {tool}"** - Claude needs permission to use a specific tool
   - Sends: "🔐 {tool} permission required" (high priority)

3. **"Claude Code login successful"** - Login confirmation
   - No notification sent (you're already active)

4. **Other messages** - Any unexpected notification messages
   - Sends: "ℹ️ {message}" (normal priority)

#### Stop Hook (Low Priority)

Triggers when Claude completes work:

- **Work Completion** - Notifies when a session finishes
  - Sends: "✅ Work completed in {directory}" (low priority)

#### SessionEnd Hook (Low Priority)

Triggers when a Claude Code session ends:

- **Session End** - Notifies when session terminates
  - Sends: "👋 Session ended: {reason}" (low priority)
  - Reasons include: "clear", "logout", "prompt_input_exit"

#### PreCompact Hook (Low Priority)

Triggers before context compaction:

- **Auto Compact** - When context window is full
  - Sends: "🗜️ Auto-compacting context" (low priority)
- **Manual Compact** - When `/compact` is invoked
  - Sends: "🗜️ Manual compact triggered" (low priority)

#### SubagentStop Hook (Low Priority)

Triggers when a subagent (Task tool) completes:

- **Subagent Completion** - When a Task tool finishes
  - Sends: "🤖 Subagent task completed" (low priority)

### Optional Notifications (Commented Out)

The following notifications are disabled by default to reduce noise. To enable them, uncomment the relevant sections in `pushover.sh`:

- **SessionStart** - Session start/resume/clear events
- **PreToolUse** - Before each tool is used (very noisy)
- **PostToolUse** - After each tool completes (very noisy)

## Configuration Files

### pushover.sh

Location: `config/claude/pushover.sh`

The Pushover notification script that handles Claude Code hooks. Features:
- **Early exit if Pushover not configured** - Fails gracefully without errors
- Detects hook type from JSON structure
- Smart priority levels (high for permissions, low for info)
- Emoji indicators for quick visual recognition
- Only essential notifications enabled by default
- Optional hooks commented out (SessionStart, SessionEnd, tool tracking)

### settings.local.json

Location: `config/claude/settings.local.json`

The hooks configuration (local settings override global settings):

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.message' | xargs -I {} osascript -e 'display notification \"{}\" with title \"Claude Code\" sound name \"Sonar\"'"
          },
          {
            "type": "command",
            "command": "/Users/shunkakinoki/dotfiles/config/claude/pushover.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "cat | jq -r '\"Work completed in \" + .cwd + \" (Session: \" + .session_id[0:8] + \")\"' | xargs -I {} osascript -e 'display notification \"{}\" with title \"Claude Code\" sound name \"Sonar\"'"
          },
          {
            "type": "command",
            "command": "/Users/shunkakinoki/dotfiles/config/claude/pushover.sh"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/shunkakinoki/dotfiles/config/claude/pushover.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/shunkakinoki/dotfiles/config/claude/pushover.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/shunkakinoki/dotfiles/config/claude/pushover.sh"
          }
        ]
      }
    ]
  }
}
```

**Note**: The `Notification` and `Stop` hooks run both macOS notifications and Pushover. The other hooks (`SessionEnd`, `PreCompact`, `SubagentStop`) only run Pushover to reduce notification noise on macOS.

## Customization

### Device Names

Edit the `device=iphone15` parameter in `pushover.sh` to match your device name, or remove it to send to all devices:

```bash
curl -s \
    --form-string "token=${PUSHOVER_API_TOKEN}" \
    --form-string "user=${PUSHOVER_USER_KEY}" \
    --form-string "message=${NOTIFY_MSG}" \
    --form-string "title=Claude Code" \
    https://api.pushover.net/1/messages.json
```

### Notification Messages

Modify the case statement in `pushover.sh` to customize message text:

```bash
case "$MESSAGE" in
  'Claude is waiting for your input')
    NOTIFY_MSG="Your custom message here"
    ;;
  # Add more cases as needed
esac
```

### Priority Levels

The script automatically sets priority based on importance:

- **High Priority (1)**: Permission requests, waiting for input - plays sound
- **Normal Priority (0)**: General information messages
- **Low Priority (-1)**: Session events, completion notifications - no sound

You can customize these in `pushover.sh` by changing the priority parameter:

```bash
send_notification "message" 1   # High priority with sound
send_notification "message" 0   # Normal priority (default)
send_notification "message" -1  # Low priority, no sound
send_notification "message" 2   # Emergency - requires acknowledgment
```

### Enabling Optional Hooks

To enable additional notifications like `SessionStart` or `SessionEnd`:

1. **Uncomment the relevant section** in `pushover.sh` (around lines 60-90)
2. **Add the hook** to `settings.local.json`:

```json
"SessionStart": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "/Users/shunkakinoki/dotfiles/config/claude/pushover.sh"
      }
    ]
  }
]
```

**Note**: The script exits gracefully if Pushover is not configured, so it's safe to use even without environment variables set.

## Troubleshooting

### Notifications Not Appearing

1. Check environment variables are set:
   ```bash
   echo $PUSHOVER_API_TOKEN
   echo $PUSHOVER_USER_KEY
   ```

2. Test the curl command manually with a simple message

3. Verify the script has execute permissions:
   ```bash
   ls -l config/claude/pushover.sh
   # Should show: -rwxr-xr-x
   ```

4. Check Claude Code hook is configured correctly in settings.local.json

5. If Pushover is not configured, the script will silently exit without error - this is expected behavior

### Wrong Device Receiving Notifications

- Verify the device name in the script matches your Pushover device name
- Log into Pushover.net and check your registered devices
- Remove the device parameter to send to all devices

### Script Errors

Check Claude Code logs for error messages. The script requires:
- `jq` for JSON parsing
- Valid environment variables
- Network access to api.pushover.net

## Cost

As of January 2025, Pushover pricing:
- 30-day free trial
- $4.99 one-time purchase per platform (iOS, Android, or Desktop)
- No subscription required

The author purchased the iOS license for approximately ¥769 ($4.99 USD).

## Future Enhancements

Potential improvements:
- Respond to notifications directly from smartwatch (challenging, requires API integration)
- Custom notification sounds per message type
- Notification history tracking
- Integration with other notification services (Slack, Discord, etc.)

## Credits

Based on the article "How to Get Claude Code Notifications on Your Wrist" by [@kawarimidoll](https://zenn.dev/kawarimidoll).

## Available Claude Code Hooks

For reference, here are all available Claude Code hooks:

| Hook | Trigger | Use Case |
|------|---------|----------|
| **Notification** | When Claude needs permission or input is idle | Alert user attention needed |
| **Stop** | When main agent finishes responding | Completion notifications |
| **SubagentStop** | When subagent (Task tool) finishes | Track subagent completion |
| **SessionStart** | Session start/resume | Track session lifecycle |
| **SessionEnd** | Session ends | Cleanup and logging |
| **UserPromptSubmit** | User submits a prompt | Add context or validation |
| **PreToolUse** | Before processing a tool call | Preview or block tool usage |
| **PostToolUse** | After a tool completes | Add context or logging |
| **PreCompact** | Before context compaction | Add context before compacting |

## References

- [Pushover API Documentation](https://pushover.net/api)
- [Claude Code Hooks Documentation](https://docs.claude.com/en/docs/claude-code/hooks)
- [Original Japanese Article](https://zenn.dev/kawarimidoll/articles/claude-code-notification-on-wrist)
