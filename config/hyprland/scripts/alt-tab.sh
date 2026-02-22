#!/bin/bash

STATE_DIR="/tmp/hypr-alt-tab"
STATE_FILE="$STATE_DIR/state"
TIME_FILE="$STATE_DIR/last_press"
CURRENT_INDEX_FILE="$STATE_DIR/current_index"
WINDOW_LIST_FILE="$STATE_DIR/window_list"

# Cooldown in seconds (time within which presses count as "continuous")
COOLDOWN=0.8

# Create state directory if it doesn't exist
mkdir -p "$STATE_DIR"

# Parse arguments
same_type=false
reverse=false
visible_only=false

for arg in "$@"; do
    case $arg in
        --same) same_type=true ;;
        --reverse) reverse=true ;;
        --visible) visible_only=true ;;
    esac
done

# Function to get window class
get_window_class() {
    local window="$1"
    hyprctl clients -j | jq -r --arg addr "$window" '.[] | select(.address == $addr) | .class'
}

# Function to get window title
get_window_title() {
    local window="$1"
    hyprctl clients -j | jq -r --arg addr "$window" '.[] | select(.address == $addr) | .title'
}

# Function to get window workspace ID
get_window_workspace() {
    local window="$1"
    hyprctl clients -j | jq -r --arg addr "$window" '.[] | select(.address == $addr) | .workspace.id'
}

# Function to get active workspaces (visible on monitors)
get_active_workspaces() {
    hyprctl monitors -j | jq -r '.[].activeWorkspace.id'
}

# Function to get all windows sorted by focus history (most recent first)
get_windows_by_focus() {
    hyprctl clients -j | jq -r 'sort_by(-.focusHistoryID) | .[].address'
}

# Function to get visible windows (on active workspaces)
get_visible_windows() {
    # Get all active workspace IDs
    mapfile -t active_workspaces < <(get_active_workspaces)

    if [[ ${#active_workspaces[@]} -eq 0 ]]; then
        return
    fi

    # Convert active workspaces to JSON array for jq query
    local workspaces_json="["
    for ws in "${active_workspaces[@]}"; do
        workspaces_json+="$ws,"
    done
    workspaces_json="${workspaces_json%,}]"

    # Get windows in active workspaces, sorted by focus history
    hyprctl clients -j | jq -r --argjson workspaces "$workspaces_json" '
        [.[] | select(.workspace.id as $ws | $workspaces | index($ws))]
        | sort_by(-.focusHistoryID)
        | .[].address
    '
}

# Function to get windows filtered by type (same class)
get_same_type_windows() {
    local current_window="$1"
    local current_class
    current_class=$(get_window_class "$current_window")

    # Get all windows with same class
    hyprctl clients -j | jq -r --arg class "$current_class" \
        '.[] | select(.class == $class) | .address'
}

# Function to get currently focused window
get_focused_window() {
    hyprctl activewindow -j | jq -r '.address'
}

# Function to check if window exists
window_exists() {
    local window="$1"
    [[ -n "$window" ]] && hyprctl clients -j | jq -r '.[].address' | grep -q "^${window}$"
}

# Function to validate and refresh window list
validate_window_list() {
    local windows=("$@")
    local valid_windows=()

    for window in "${windows[@]}"; do
        if window_exists "$window"; then
            valid_windows+=("$window")
        fi
    done

    printf '%s\n' "${valid_windows[@]}"
}

# Get currently focused window
current_focused=$(get_focused_window)

# Get appropriate window list based on mode
if [[ "$visible_only" == "true" ]]; then
    mapfile -t windows < <(get_visible_windows)

    # If no visible windows, fall back to all windows
    if [[ ${#windows[@]} -eq 0 ]]; then
        mapfile -t windows < <(get_windows_by_focus)
    fi

    # Apply same-type filter if requested
    if [[ "$same_type" == "true" ]] && [[ -n "$current_focused" ]]; then
        mapfile -t same_type_windows < <(get_same_type_windows "$current_focused")

        local filtered_windows=()
        for visible_window in "${windows[@]}"; do
            for same_window in "${same_type_windows[@]}"; do
                if [[ "$visible_window" == "$same_window" ]]; then
                    filtered_windows+=("$visible_window")
                    break
                fi
            done
        done

        if [[ ${#filtered_windows[@]} -gt 0 ]]; then
            windows=("${filtered_windows[@]}")
        fi
    fi
elif [[ "$same_type" == "true" ]] && [[ -n "$current_focused" ]]; then
    mapfile -t windows < <(get_same_type_windows "$current_focused")

    # If no same-type windows or only current window, fall back to all windows
    if [[ ${#windows[@]} -le 1 ]]; then
        mapfile -t windows < <(get_windows_by_focus)
    fi
else
    mapfile -t windows < <(get_windows_by_focus)
fi

# Validate windows still exist
mapfile -t windows < <(validate_window_list "${windows[@]}")

# Exit if no windows or only one window
if [[ ${#windows[@]} -le 1 ]]; then
    exit 0
fi

# Get current time
current_time=$(date +%s.%N)

# Read last press time
last_press=0
[[ -f "$TIME_FILE" ]] && last_press=$(<"$TIME_FILE")

# Calculate time difference
time_diff=$(echo "$current_time - $last_press" | bc -l 2>/dev/null || echo "1")

# Check if we're continuing the Alt+Tab session
continuing_session=false
if (( $(echo "$time_diff <= $COOLDOWN" | bc -l 2>/dev/null || echo "0") )); then
    continuing_session=true
fi

# Find current window index in the list
current_index=-1
for i in "${!windows[@]}"; do
    if [[ "${windows[$i]}" == "$current_focused" ]]; then
        current_index=$i
        break
    fi
done

# If current window not in filtered list, start from beginning
if [[ $current_index -eq -1 ]]; then
    current_index=0
fi

# Calculate target index
if [[ "$continuing_session" == "true" ]] && [[ -f "$CURRENT_INDEX_FILE" ]] && [[ -f "$WINDOW_LIST_FILE" ]]; then
    # Read saved state
    saved_index=$(<"$CURRENT_INDEX_FILE")
    mapfile -t saved_windows < "$WINDOW_LIST_FILE"

    # Check if saved windows match current windows
    same_list=true
    if [[ ${#windows[@]} -ne ${#saved_windows[@]} ]]; then
        same_list=false
    else
        for i in "${!windows[@]}"; do
            if [[ "${windows[$i]}" != "${saved_windows[$i]}" ]]; then
                same_list=false
                break
            fi
        done
    fi

    if [[ "$same_list" == "true" ]]; then
        if [[ "$reverse" == "true" ]]; then
            target_index=$(( (saved_index - 1 + ${#windows[@]}) % ${#windows[@]} ))
        else
            target_index=$(( (saved_index + 1) % ${#windows[@]} ))
        fi
    else
        if [[ "$reverse" == "true" ]]; then
            target_index=$(( (current_index - 1 + ${#windows[@]}) % ${#windows[@]} ))
        else
            target_index=$(( (current_index + 1) % ${#windows[@]} ))
        fi
    fi
else
    # Start new session - move from current window
    if [[ "$reverse" == "true" ]]; then
        target_index=$(( (current_index - 1 + ${#windows[@]}) % ${#windows[@]} ))
    else
        target_index=$(( (current_index + 1) % ${#windows[@]} ))
    fi
fi

# Save state
echo "$current_time" > "$TIME_FILE"
echo "$target_index" > "$CURRENT_INDEX_FILE"
printf '%s\n' "${windows[@]}" > "$WINDOW_LIST_FILE"

# Focus the target window
target_window="${windows[$target_index]}"
if window_exists "$target_window"; then
    hyprctl dispatch focuswindow "address:$target_window"
    hyprctl dispatch alterzorder top
fi

# Visual feedback: dim inactive windows temporarily
hyprctl keyword decoration:dim_inactive true 2>/dev/null

# Clear any existing reset timer
[[ -f "$STATE_DIR/dim_timer" ]] && kill "$(<"$STATE_DIR/dim_timer")" 2>/dev/null || true

# Start timer to reset dimming
(
    sleep 1.2
    hyprctl keyword decoration:dim_inactive false 2>/dev/null
) &
echo $! > "$STATE_DIR/dim_timer"
