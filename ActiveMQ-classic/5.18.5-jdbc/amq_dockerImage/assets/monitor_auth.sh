#!/bin/bash
set -u
DEST_FILE="/opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml"

# Placeholders in DEST_FILE
START_PLACEHOLDER="<!--BeginAuth-->"
END_PLACEHOLDER="<!--EndAuth-->"

# Temporary location for script operations
TEMP_DIR_BASE="/tmp/activemq_config_updater_$(date +%s%N)" # Unique temp base to allow parallel runs if ever needed for other purposes
TEMP_GIT_CHECKOUT_DIR="${TEMP_DIR_BASE}/git_checkout"
SOURCE_FILE_FROM_REPO="${TEMP_DIR_BASE}/$BROKER_NAME_FILE"

# Git auth
gh auth login --with-token < /config/github_token.sec
gh auth setup-git

# Function to log messages with a timestamp
log_message() {
    echo "Auth monitor - $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to fetch the latest file from Git
fetch_from_git() {
    log_message "Fetching latest file '$BROKER_NAME_FILE' from Git repository '$GIT_REPO_URL' (branch '$GIT_BRANCH')..."

    # Clean up any previous git checkout directory and create a fresh one
    rm -rf "$TEMP_GIT_CHECKOUT_DIR"
    mkdir -p "$TEMP_GIT_CHECKOUT_DIR"

    if ! gh auth status > /dev/null 2>&1; then
        log_message "GitHub CLI not authenticated. Attempting login..."
        if [ ! -f "/config/github_token.sec" ]; then
            log_message "Error: GitHub token file /config/github_token.sec not found."
            return 1
        fi
        if ! gh auth login --with-token < /config/github_token.sec; then
            log_message "Error: GitHub CLI login failed."
            return 1
        fi
        log_message "GitHub CLI login successful."
    else
        log_message "GitHub CLI already authenticated."
    fi
    

 # Using a shallow clone for efficiency
    if git clone --quiet --depth 1 --branch "$GIT_BRANCH" --no-tags --single-branch "$GIT_REPO_URL" "$TEMP_GIT_CHECKOUT_DIR"; then
        local repo_local_file_path="$TEMP_GIT_CHECKOUT_DIR/$BROKER_NAME_FILE"
        if [ -f "$repo_local_file_path" ]; then
            cp "$repo_local_file_path" "$SOURCE_FILE_FROM_REPO"
            log_message "Successfully fetched '$BROKER_NAME_FILE' and copied to $SOURCE_FILE_FROM_REPO"
            rm -rf "$TEMP_GIT_CHECKOUT_DIR" # Clean up cloned repo
            return 0 # Success
        else
            log_message "Error: File '$BROKER_NAME_FILE' not found in the cloned repository at '$repo_local_file_path'."
            rm -rf "$TEMP_GIT_CHECKOUT_DIR" # Clean up
            return 1 # Failure
        fi
    else
        log_message "Error: Failed to clone repository from '$GIT_REPO_URL'."
        rm -rf "$TEMP_GIT_CHECKOUT_DIR" # Clean up
        return 1 # Failure
    fi
}

# Function to update the destination file if changes are detected
update_destination_file() {
    if [ ! -f "$SOURCE_FILE_FROM_REPO" ]; then
        log_message "Error: Source file from repo '$SOURCE_FILE_FROM_REPO' not found. Skipping update."
        return 1
    fi

    if [ ! -f "$DEST_FILE" ]; then
        log_message "Error: Destination file '$DEST_FILE' not found. Skipping update."
        return 1
    fi
    
    if [ ! -w "$DEST_FILE" ]; then
        log_message "Error: Destination file '$DEST_FILE' is not writable. Skipping update."
        return 1
    fi

    # Check if both placeholders exist in the destination file
    # This is robust even if placeholders contain characters that are special to regex.
    if ! grep -qF "$START_PLACEHOLDER" "$DEST_FILE" || ! grep -qF "$END_PLACEHOLDER" "$DEST_FILE"; then
        log_message "Error: One or both placeholders ('$START_PLACEHOLDER', '$END_PLACEHOLDER') are missing in $DEST_FILE."
        log_message "Please ensure both placeholders exist in $DEST_FILE."
        return 1
    fi

    # Escape regex special characters in placeholders for awk matching
    local start_esc
    start_esc=$(printf '%s\n' "$START_PLACEHOLDER" | sed 's:[][\\/.^$*]:\\&:g')
    local end_esc
    end_esc=$(printf '%s\n' "$END_PLACEHOLDER" | sed 's:[][\\/.^$*]:\\&:g')

    # Define awk patterns to match placeholder lines, allowing for leading/trailing whitespace
    local awk_start_pattern="^[[:space:]]*${start_esc}[[:space:]]*$"
    local awk_end_pattern="^[[:space:]]*${end_esc}[[:space:]]*$"

    # Extract current content from DEST_FILE between placeholders
    # awk script: set flag p=1 after start line (next), clear p=0 on end line, print line if p=1
    local current_data_in_dest
    current_data_in_dest=$(awk -v start_re="$awk_start_pattern" -v end_re="$awk_end_pattern" \
        '$0 ~ start_re {p=1; next} $0 ~ end_re {p=0} p {print}' \
        "$DEST_FILE")
    
    local new_data_from_git
    new_data_from_git=$(<"$SOURCE_FILE_FROM_REPO") # Command substitution strips single trailing newline

    # Compare new_data_from_git with current_data_in_dest
    # Both variables will have their single trailing newlines stripped by command substitution,
    # making the comparison fairly robust for content.
    # Using printf to avoid issues with echo and leading hyphens or backslashes in data.
    if [ "$(printf '%s' "$new_data_from_git")" = "$(printf '%s' "$current_data_in_dest")" ]; then
        log_message "No changes detected between '$BROKER_NAME_FILE' from git and content in '$DEST_FILE'. No update needed."
        return 0 # Success, no changes
    fi

    log_message "Changes detected. Updating content for '$START_PLACEHOLDER' in '$DEST_FILE'..."
    # For debugging, you might want to see the content:
    # log_message "DEBUG: Current data hash: $(printf '%s' "$current_data_in_dest" | md5sum)"
    # log_message "DEBUG: New data hash: $(printf '%s' "$new_data_from_git" | md5sum)"

    local temp_dest_file="${DEST_FILE}.tmp.$$" # Add PID for more uniqueness
    
    # awk script to replace content.
    # It reads the replacement content from SOURCE_FILE_FROM_REPO.
    # Uses the escaped and anchored regexes for matching placeholder lines.
    awk -v start_re_match="$awk_start_pattern" \
        -v end_re_match="$awk_end_pattern" \
        -v replacement_file="$SOURCE_FILE_FROM_REPO" \
    '
    BEGIN {
        # Read the entire replacement content from the file into the variable rep_content
        rep_content = ""; # Initialize to empty string
        while ((getline line < replacement_file) > 0) {
            rep_content = rep_content line ORS; # ORS is Output Record Separator, usually newline
        }
        close(replacement_file);
        # Remove trailing ORS if rep_content is not empty and ends with ORS
        # This logic is correct for a single-character ORS (like \n)
        if (rep_content != "" && substr(rep_content, length(rep_content), 1) == ORS) {
            rep_content = substr(rep_content, 1, length(rep_content) - length(ORS));
        }
    }
    {
        if ($0 ~ start_re_match) {
            print $0;                   # Print the start placeholder line itself
            if (rep_content != "") {    # Print new content only if it is not empty
                print rep_content;
            }
            inside_block = 1;           # We are now in the section that has been replaced
        } else if ($0 ~ end_re_match) {
            inside_block = 0;           # We have exited the section
            print $0;                   # Print the end placeholder line itself
        } else if (!inside_block) {
            print $0;                   # Print lines outside the placeholder block
        }
        # Lines that were originally between start and end (and not matching end) are skipped
    }' "$DEST_FILE" > "$temp_dest_file"

    if [ $? -eq 0 ] && [ -s "$temp_dest_file" ]; then # Check awk success and if temp file is not empty
        local perms
        perms=$(stat -c "%a" "$DEST_FILE")
        local owner_group
        owner_group=$(stat -c "%u:%g" "$DEST_FILE")

        # Before moving, ensure the temp file is different from the original if we want to be super safe
        # For now, the content check above should suffice.
        mv "$temp_dest_file" "$DEST_FILE"
        if [ $? -eq 0 ]; then
            log_message "Successfully updated '$DEST_FILE'."
            chown "$owner_group" "$DEST_FILE" 2>/dev/null || log_message "Warning: Could not restore ownership on $DEST_FILE."
            chmod "$perms" "$DEST_FILE" 2>/dev/null || log_message "Warning: Could not restore permissions on $DEST_FILE."
            return 0 # Success
        else
            log_message "Error: Failed to move temporary file '$temp_dest_file' to '$DEST_FILE'."
            rm -f "$temp_dest_file" # Clean up temp file
            return 1 # Failure
        fi
    else
        log_message "Error: awk command failed to update '$DEST_FILE' or created an empty file. Temp file: $temp_dest_file (if exists and not moved)."
        # Do not remove temp_dest_file in this case if awk failed, it might be useful for debugging
        # However, if awk succeeded but temp_dest_file is empty, it might be intentional if source was empty
        # The -s check handles the "created an empty file" part if it wasn't intended.
        # If temp_dest_file exists and awk failed ($? -ne 0), keep it.
        if [ $? -ne 0 ] && [ -f "$temp_dest_file" ]; then
             log_message "AWK failed, temporary file $temp_dest_file kept for debugging."
        elif [ -f "$temp_dest_file" ]; then # AWK succeeded but file was empty and shouldn't have been (or other issue)
             rm -f "$temp_dest_file"
        fi
        return 1 # Failure
    fi
}

# --- Cleanup trap ---
cleanup() {
    log_message "Cleaning up temporary directory: $TEMP_DIR_BASE"
    rm -rf "$TEMP_DIR_BASE"
    log_message "Script finished."
}
trap cleanup EXIT SIGINT SIGTERM # Add HUP SIGHUP if needed

# --- Main Execution ---
log_message "Starting ActiveMQ config updater script..."
# Ensure required environment variables are set
: "${AMQ_VERSION:?Error: AMQ_VERSION environment variable is not set.}"
: "${GIT_REPO_URL:?Error: GIT_REPO_URL environment variable is not set.}"
: "${GIT_BRANCH:?Error: GIT_BRANCH environment variable is not set.}"
: "${BROKER_NAME_FILE:?Error: BROKER_NAME_FILE (file path in git repo) environment variable is not set.}"
: "${CHECK_INTERVAL:?Error: CHECK_INTERVAL environment variable is not set.}"
# REPO_FILE_PATH was used in logs but BROKER_NAME_FILE is used for operations. Standardized to BROKER_NAME_FILE.

log_message "Monitoring Git repo: $GIT_REPO_URL, branch: $GIT_BRANCH, file in repo: $BROKER_NAME_FILE"
log_message "Target ActiveMQ file: $DEST_FILE (AMQ Version: $AMQ_VERSION)"
log_message "Placeholders: '$START_PLACEHOLDER' to '$END_PLACEHOLDER'"
log_message "Check interval: $CHECK_INTERVAL seconds"

# Ensure the base temporary directory exists for the script's operation
mkdir -p "$TEMP_DIR_BASE"
if [ ! -d "$TEMP_DIR_BASE" ]; then
    log_message "FATAL: Could not create temporary directory $TEMP_DIR_BASE. Exiting."
    exit 1
fi

# Initial check and update, then loop
log_message "Performing initial check..."
if fetch_from_git; then
    if update_destination_file; then
        log_message "Initial update cycle complete."
    else
        log_message "Initial update cycle encountered an error during destination file update."
    fi
else
    log_message "Initial update cycle encountered an error during git fetch."
fi

while true; do
    log_message "Sleeping for $CHECK_INTERVAL seconds..."
    sleep "$CHECK_INTERVAL"
    log_message "----------------------------------------"
    log_message "Starting scheduled check..."
    if fetch_from_git; then
        if update_destination_file; then
            log_message "Update cycle complete."
        else
            log_message "Update cycle encountered an error during destination file update."
        fi
    else
        log_message "Update cycle encountered an error during git fetch."
    fi
done