#!/bin/bash

# Set up SIGINT handler at the beginning
trap '' SIGINT

# Get the directory where the script is located
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check Python and pip availability
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is not installed"
    exit 1
fi

# Get Python version and check compatibility
PYTHON_VERSION=$(python3 -V 2>&1 | cut -d' ' -f2)
echo "Found Python version: $PYTHON_VERSION"

# Create virtual environment
if [ ! -d "$BASE_DIR/venv" ]; then
    echo "Creating Python virtual environment..."
    # Remove any failed venv directory
    rm -rf "$BASE_DIR/venv"
    # Try to create venv with explicit python version
    python3 -m venv "$BASE_DIR/venv" --clear || {
        echo "Error: Failed to create virtual environment"
        exit 1
    }
fi

# Verify venv was created correctly
if [ ! -f "$BASE_DIR/venv/bin/python3" ]; then
    echo "Error: Virtual environment appears to be corrupted"
    echo "Try removing the venv directory and running setup again:"
    echo "rm -rf \"$BASE_DIR/venv\""
    exit 1
fi

# Activate virtual environment
echo "Activating Python virtual environment..."
source "$BASE_DIR/venv/bin/activate" || {
    echo "Error: Failed to activate virtual environment"
    exit 1
}

# Verify pip is available in venv
if [ ! -f "$BASE_DIR/venv/bin/pip" ]; then
    echo "Error: pip not found in virtual environment"
    echo "Try removing the venv directory and running setup again:"
    echo "rm -rf \"$BASE_DIR/venv\""
    exit 1
fi

# Install dependencies
echo "Installing Python dependencies..."
"$BASE_DIR/venv/bin/python3" -m pip install -r "$BASE_DIR/requirements.txt" || {
    echo "Error: Failed to install dependencies"
    exit 1
}

# Setup aria2 configuration
ARIA2_CONF=""

# First try to find config from running aria2c process
if pgrep aria2c > /dev/null; then
    echo "Found running aria2c process(es), checking for config path..."
    PROC_CONF=$(ps -ef | grep "[a]ria2c" | grep -o "\--conf-path=[^ ]*" | cut -d= -f2 | head -n1)
    if [ -n "$PROC_CONF" ] && [ -f "$PROC_CONF" ]; then
        ARIA2_CONF="$PROC_CONF"
        echo "Found config from running process: $ARIA2_CONF"
    fi
fi

# If not found from process, check common locations
if [ -z "$ARIA2_CONF" ]; then
    ARIA2_CONF_PATHS=("$HOME/.aria2/aria2.conf" "/etc/aria2/aria2.conf")
    for conf_path in "${ARIA2_CONF_PATHS[@]}"; do
        if [ -f "$conf_path" ]; then
            ARIA2_CONF="$conf_path"
            echo "Found aria2 configuration at: $ARIA2_CONF"
            break
        fi
    done
fi

# Ask user for aria2 config path
if [ -n "$ARIA2_CONF" ]; then
    echo -n "Enter path to aria2.conf [${ARIA2_CONF}] (Enter to use this path, 0 to skip, or input new path): "
    read input_conf
    if [ "$input_conf" = "0" ]; then
        ARIA2_CONF=""
    elif [ -n "$input_conf" ]; then
        ARIA2_CONF="$input_conf"
    fi
else
    echo -n "Enter path to aria2.conf (Enter to skip, or input path): "
    read input_conf
    if [ -n "$input_conf" ]; then
        ARIA2_CONF="$input_conf"
    fi
fi

if [ -n "$ARIA2_CONF" ]; then
    if [ ! -f "$ARIA2_CONF" ]; then
        echo "Note: Config file not found at: $ARIA2_CONF"
        echo "Please manually add the following line to your aria2 configuration:"
        echo "on-download-complete=$BASE_DIR/automove.sh"
    else
        # Check if config already has the correct setting
        CURRENT_SETTING=$(grep "^on-download-complete=" "$ARIA2_CONF" | head -n1)
        if [ "$CURRENT_SETTING" = "on-download-complete=$BASE_DIR/automove.sh" ]; then
            echo "aria2 configuration is already set up correctly"
        else
            # Backup original config
            cp "$ARIA2_CONF" "$ARIA2_CONF.backup"
            echo "Created backup at: $ARIA2_CONF.backup"
            
            # Add or update on-download-complete setting
            if grep -q "^on-download-complete=" "$ARIA2_CONF"; then
                sed -i "s|^on-download-complete=.*|on-download-complete=$BASE_DIR/automove.sh|" "$ARIA2_CONF"
            else
                echo "on-download-complete=$BASE_DIR/automove.sh" >> "$ARIA2_CONF"
            fi
            echo "Updated aria2 configuration successfully!"
            echo "You may need to restart aria2 for changes to take effect"
        fi
    fi
else
    echo "Please manually add the following line to your aria2 configuration then restart aria2 for changes to take effect:"
    echo "on-download-complete=$BASE_DIR/automove.sh"
fi

# Generate automove.conf if it doesn't exist
if [ ! -f "$BASE_DIR/automove.conf" ]; then
    echo "Generating automove.conf..."
    cp "$BASE_DIR/automove.conf.sample" "$BASE_DIR/automove.conf"
    echo "Created automove.conf from sample. Please edit it to set your OpenAI API key and target folder."
else
    echo "automove.conf already exists, skipping configuration"
fi

# Restore default SIGINT handler at the end
trap - SIGINT
echo "Installation complete!"
