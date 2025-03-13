#!/bin/sh

# Get the directory where the script is located
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse parameters (parameters passed by aria2 in order: TASK_ID, FILE_COUNT, FILE_PATH)
TASK_ID="$1"
FILE_COUNT="$2"
FILE_PATH="$3"

# Log file is placed in the script directory
LOG_FILE="$BASE_DIR/automove.log"

# Record log: time, each parameter, and the complete parameter list
echo "Download completed: $(date)" >> "$LOG_FILE"
echo "Task ID: $TASK_ID" >> "$LOG_FILE"
echo "File Count: $FILE_COUNT" >> "$LOG_FILE"
echo "File Path: $FILE_PATH" >> "$LOG_FILE"
echo "All parameters: $@" >> "$LOG_FILE"

# Use Python interpreter from the virtual environment (assuming the virtual environment is in the myenv folder in the script directory)
PYTHON="$BASE_DIR/venv/bin/python3"

# Before calling the Python script, record the complete command
CMD="$PYTHON $BASE_DIR/automove.py \"$FILE_PATH\""
echo "Calling: $CMD" >> "$LOG_FILE"
echo "Calling: $CMD"

# Execute the Python script and append output and errors to the log
$PYTHON "$BASE_DIR/automove.py" "$FILE_PATH" >> "$LOG_FILE" 2>&1


