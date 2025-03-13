#!/usr/bin/env python3
import os
import sys
import shutil
import openai
import json
import re
import pwd
import grp
from dotenv import load_dotenv

# Load automove.conf from the same directory
BASE_DIR = os.path.dirname(os.path.realpath(__file__))
load_dotenv(os.path.join(BASE_DIR, 'automove.conf'))


# Create OpenAI client with specified base_url
client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"), base_url=os.getenv("OPENAI_BASE_URL"))

# Get model from config, default to gpt-4o-mini
MODEL_NAME = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

# List of video extensions
VIDEO_EXTENSIONS = {".mp4", ".mkv", ".avi", ".mov", ".flv", ".wmv", ".ts", ".webm"}

# Define target file owner and group, default read from environment variables
TARGET_USER = os.getenv("TARGET_USER", "")  # Empty string if not provided
TARGET_GROUP = os.getenv("TARGET_GROUP", "")  # Empty string if not provided

def move_file(file_path, dest_dir):
    """ Move file to target directory, ensuring no incomplete files with the same name exist during transfer.
        Using fixed extension .tmp as temporary file suffix. """
    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir)

    base_name = os.path.basename(file_path)
    final_path = os.path.join(dest_dir, base_name)
    temp_path = final_path + ".tmp"  # Use fixed extension .tmp as temporary file

    print(f"Starting to copy {file_path} to temporary file {temp_path} ...")
    shutil.copy2(file_path, temp_path)
    print("Copy completed.")

    # Rename temporary file to final file (atomic operation)
    os.rename(temp_path, final_path)
    print(f"Rename successful: {temp_path} -> {final_path}")

    # Delete source file
    os.remove(file_path)
    print(f"Source file deleted: {file_path}")

    # Modify target file owner and group
    try:
        if TARGET_USER and TARGET_GROUP:
            uid = pwd.getpwnam(TARGET_USER).pw_uid
            gid = grp.getgrnam(TARGET_GROUP).gr_gid
            print(f"Using provided user and group: {TARGET_USER}:{TARGET_GROUP}")
        else:
            # If not provided, use existing owner and group of target directory
            stat_info = os.stat(dest_dir)
            uid, gid = stat_info.st_uid, stat_info.st_gid
            print(f"No user or group provided, using target directory's owner and group: UID={uid}, GID={gid}")
    except KeyError as e:
        print(f"Error modifying file owner and group: {e}")
        stat_info = os.stat(dest_dir)
        uid, gid = stat_info.st_uid, stat_info.st_gid

    os.chown(final_path, uid, gid)
    print(f"Changed {final_path} owner and group to UID:{uid} GID:{gid}")

def is_video_file(file_path):
    """ Check if file is a video file """
    ext = os.path.splitext(file_path)[1].lower()
    return ext in VIDEO_EXTENSIONS

def get_directory_structure(base_dir):
    """
    Traverse all directories under base_dir, construct a dictionary,
    keys are relative paths, values are lists of subdirectories.
    """
    structure = {}
    for root, dirs, _ in os.walk(base_dir):
        rel_path = os.path.relpath(root, base_dir)
        if rel_path == ".":
            rel_path = ""
        structure[rel_path] = dirs
    return structure


def ask_llm_for_target_directory(file_name, candidate_list):
    """
    Call LLM to select a matching directory from the candidate list.
    Candidate list is provided in JSON format, requiring the model to return only
    one string from the candidate list without any explanation.
    Return "None" if no suitable option is found.
    """
    # Convert candidate list to JSON string
    candidate_json = json.dumps(candidate_list, ensure_ascii=False)
    prompt = f"""
I have a video file named: "{file_name}".
Below is the list of candidate storage paths (in JSON format):
{candidate_json}

Please select the most suitable storage path from the above candidate list for this file, and **return only one exact matching string**,
without any additional explanation. If no suitable option is found, please return "None".
"""
    # Print content sent to LLM (for debugging)
    print("====== Content Sent to LLM ======")
    print(prompt)
    print("=================================")

    response = client.chat.completions.create(
        model=MODEL_NAME,  # Use configured model name
        messages=[{"role": "user", "content": prompt}]
    )

    output = response.choices[0].message.content.strip()

    # Print raw content returned by LLM
    print("====== Raw Content Returned by LLM ======")
    print(output)
    print("=================================")

    # If return is exactly "None", return None
    if output.lower() == "none":
        return None

    # Remove possible quotes
    candidate = output.strip('"').strip()

    # Verify if returned result is in candidate list (strict match)
    if candidate in candidate_list:
        return candidate
    else:
        print(f"⚠️ Path returned by LLM not in candidate list: {candidate}")
        return None

def main():
    """ Main function """
    if len(sys.argv) < 2:
        print("Usage: automove.py <file_path> [target_folder]")
        sys.exit(1)
    
    file_path = sys.argv[1]
    target_folder = sys.argv[2] if len(sys.argv) > 2 else os.getenv("TARGET_FOLDER")
    if not target_folder:
        print("Error: Target directory not specified. Please provide target directory parameter or configure TARGET_FOLDER in automove.conf")
        sys.exit(1)

    # Ensure file exists
    if not os.path.exists(file_path):
        print(f"Error: {file_path} not found")
        sys.exit(1)

    # Check if it's a video file
    if not is_video_file(file_path):
        print(f"Skipping: {file_path} is not a video file")
        sys.exit(0)

    # Get current video directory structure
    directory_structure = get_directory_structure(target_folder)
    # Generate candidate directory list, here we directly use all keys from directory_structure
    candidate_list = list(directory_structure.keys())
    # If root directory ("") is not wanted as a candidate, remove it from the list
    if "" in candidate_list:
        candidate_list.remove("")

    # Ask LLM for target directory
    target_subdir = ask_llm_for_target_directory(os.path.basename(file_path), candidate_list)

    if target_subdir:
        target_path = os.path.join(target_folder, target_subdir)
        if os.path.exists(target_path):
            move_file(file_path, target_path)
        else:
            print(f"Destination path {target_path} does not exist. Please check your candidate directories.")
    else:
        print(f"No suitable directory found for {file_path}, keeping it in {target_folder}")

if __name__ == "__main__":
    main()
