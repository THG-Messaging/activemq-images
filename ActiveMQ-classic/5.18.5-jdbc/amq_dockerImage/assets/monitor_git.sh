#!/bin/bash
set -u
AUTH_DEST_FILE="/opt/apache-activemq-${AMQ_VERSION}/conf/authorization-rules-git.xml"
BRIDGES_DEST_FILE="/opt/apache-activemq-${AMQ_VERSION}/conf/bridges-git.xml"
USERS_PROPERTIES="/opt/apache-activemq-${AMQ_VERSION}/conf/users.properties"

# Temporary location for script operations
TEMP_DIR_BASE="/tmp/activemq_config_updater_$(date +%s%N)" # Unique temp base to allow parallel runs if ever needed for other purposes
GIT_CHECKOUT_DIR="${TEMP_DIR_BASE}/git_checkout"
AUTH_FILE_FROM_REPO="${GIT_CHECKOUT_DIR}/${BROKER_NAME_FILE}"
BRIDGES_FILE_FROM_REPO="${GIT_CHECKOUT_DIR}/${BROKER_NAME_FILE}.bridges"

exec &> >(sed "s/^/GIT Monitor - /")

# Git auth
gh auth login --with-token < /config/github_token.sec
gh auth setup-git

# Function to log messages with a timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to fetch the latest file from Git
fetch_from_git() {
    log_message "Fetching latest files '$BROKER_NAME_FILE' and '$BRIDGES_DEST_FILE' from Git repository '$GIT_REPO_URL' (branch '$GIT_BRANCH')..."

    if ! gh auth status > /dev/null 2>&1; then
        log_message "GitHub CLI not authenticated. Attempting login..."
        if [ ! -f "/config/github_token.sec" ]; then
            log_message "Error: GitHub token file /config/github_token.sec not found."
            rm -rf "$TEMP_DIR_BASE" # Clean up
            exit 1
        fi
        if ! gh auth login --with-token < /config/github_token.sec; then
            log_message "Error: GitHub CLI login failed."
            rm -rf "$TEMP_DIR_BASE" # Clean up
            exit 1
        fi
        log_message "GitHub CLI login successful."
    else
        log_message "GitHub CLI already authenticated."
    fi

    if [[ -d "$GIT_CHECKOUT_DIR" && -d "$GIT_CHECKOUT_DIR/.git" ]]; then
        log_message "Repository exists $GIT_CHECKOUT_DIR. Checking for remote changes..."
        
        LOCAL_HASH=$(git -C "$GIT_CHECKOUT_DIR" rev-parse HEAD)
        REMOTE_HASH=$(git -C "$GIT_CHECKOUT_DIR" ls-remote origin -h "refs/heads/$GIT_BRANCH" | awk '{print $1}')
        
        if [[ "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
            log_message "   ... local repository is already up-to-date. Nothing to do."
            return 1 # Skip processing
        else
            log_message "    ... new commits detected. Updating local repository..."
            git -C "$GIT_REPO_DIR" fetch origin
            git -C "$GIT_REPO_DIR" reset --hard "origin/$GIT_BRANCH"
            return 0 # Success - start processing
        fi
    fi 

    rm -rf "$GIT_CHECKOUT_DIR" # Clean up
    # Using a shallow clone for efficiency
    if ! git clone --quiet --depth 1 --branch "$GIT_BRANCH" --no-tags --single-branch "$GIT_REPO_URL" "$GIT_CHECKOUT_DIR"; then
        log_message "Error: Failed to clone repository from '$GIT_REPO_URL'."
        rm -rf "$TEMP_DIR_BASE" # Clean up
        exit 1
    fi
    return 0 # Success
}

# Function to update the destination file if changes are detected
update_destination_file() {
    if [ ! -f "$AUTH_FILE_FROM_REPO" ]; then
        log_message "Error: Source file from repo '$AUTH_FILE_FROM_REPO' not found. Skipping update."
        return 1
    fi
    if [ ! -f "$BRIDGES_FILE_FROM_REPO" ]; then
        log_message "Error: Source file from repo '$BRIDGES_FILE_FROM_REPO' not found. Skipping update."
        return 1
    fi

    if [ ! -f "$AUTH_DEST_FILE" ] || [ ! -w "$AUTH_DEST_FILE" ]; then
        log_message "Error: Destination file '$AUTH_DEST_FILE' not found or not writable. Skipping update."
        return 1
    fi
    if [ ! -f "$BRIDGES_DEST_FILE" ] || [ ! -w "$BRIDGES_DEST_FILE" ] ; then
        log_message "Error: Destination file '$BRIDGES_DEST_FILE' not found or not writable. Skipping update."
        return 1
    fi
    
    if [ ! -f "$USERS_PROPERTIES" ]; then
        log_message "Error: Users configuration file '$USERS_PROPERTIES' not found. Skipping update."
        return 1
    fi

    # Compare new auth data from git with current auth data in dest
    if diff -q <(xmlstarlet fo "$AUTH_FILE_FROM_REPO") \
                 <(xmlstarlet fo "$AUTH_DEST_FILE")
    then
        log_message "No changes detected between '$BROKER_NAME_FILE' from git and content in '$AUTH_DEST_FILE'. No update needed."
    else
        log_message "Files '$AUTH_FILE_FROM_REPO' and '$AUTH_DEST_FILE' are different. Copying new version..."
        cp -f $AUTH_FILE_FROM_REPO $AUTH_DEST_FILE
    fi

    # Compare new bridges data from git with current bridges data in dest, ignoring password and uri attributes
    if diff -q \
           <(xmlstarlet ed -d "//networkConnector/@password" -d "//networkConnector/@uri" "$BRIDGES_FILE_FROM_REPO" | xmlstarlet fo) \
           <(xmlstarlet ed -d "//networkConnector/@password" -d "//networkConnector/@uri" "$BRIDGES_DEST_FILE" | xmlstarlet fo)
    then
        log_message "No changes detected between '$BROKER_NAME_FILE.bridges' from git and content in '$BRIDGES_DEST_FILE'. No update needed."
    else
        log_message "Files '$BRIDGES_FILE_FROM_REPO' and '$BRIDGES_DEST_FILE' are different. Preparing new version..."
        local tmp_file=$(mktemp)
        cp -f $BRIDGES_FILE_FROM_REPO $tmp_file

        log_message "Adding URI and Password fields to copy of $BRIDGES_FILE_FROM_REPO ($tmp_file)"
        for user in $(xmlstarlet sel -t -v "//networkConnectors/networkConnector/@userName" -n "$tmp_file"); do
            log_message "--> Processing bridge with user: $user"
            local password="$user"
            password=$(awk -F'=' -v user="$user" '$1 == user {print $2}' $USERS_PROPERTIES)
            xmlstarlet ed -L -O \
                -u "//networkConnectors/networkConnector[@userName='$user']/@uri" -v "$BRIDGE_CONNECTION_STRING" \
                -s "//networkConnectors/networkConnector[@userName='$user' and not(@uri)]" -t attr -n "uri" -v "$BRIDGE_CONNECTION_STRING" \
                -u "//networkConnectors/networkConnector[@userName='$user']/@password" -v "$password" \
                -s "//networkConnectors/networkConnector[@userName='$user' and not(@password)]" -t attr -n "password" -v "$password" \
            "$tmp_file"
            local status=$?
            if [[ $status -ne 0 ]]; then
               log_message "Failed to update uri and password attribute for bridge of user '$user' using xmlstarlet. Printing file and aborting..."
               cat $tmp_file
               rm -rf $tmp_file
               return 1
            fi
        done

        # Final &gt; to > in queue/topic/physicalName attributes
        sed -i -E '/(queue|topic|physicalName)="/s/&gt;/>/g' "$tmp_file"

        if ! xmlstarlet val "$tmp_file"; then
            log_message "Error: XML validation of new bridges file failed. Printing file and aborting..."
            cat $tmp_file
            rm -rf $tmp_file
            return 1
        fi
        log_message "Deploying new bridge configuration..."
        mv "$tmp_file" "$BRIDGES_DEST_FILE"
    fi
    return 0
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
: "${BRIDGE_CONNECTION_STRING:?Error: BRIDGE_CONNECTION_STRING environment variable is not set.}"
# REPO_FILE_PATH was used in logs but BROKER_NAME_FILE is used for operations. Standardized to BROKER_NAME_FILE.

log_message "Monitoring Git repo: $GIT_REPO_URL, branch: $GIT_BRANCH, file in repo: $BROKER_NAME_FILE"
log_message "Target Auth config file: $AUTH_DEST_FILE (AMQ Version: $AMQ_VERSION)"
log_message "Target Bridges config file: $BRIDGES_DEST_FILE (AMQ Version: $AMQ_VERSION)"
log_message "Check interval: $CHECK_INTERVAL seconds"

# Ensure the base temporary directory exists for the script's operation
mkdir -p "$TEMP_DIR_BASE"
if [ ! -d "$TEMP_DIR_BASE" ]; then
    log_message "FATAL: Could not create temporary directory $TEMP_DIR_BASE. Exiting."
    exit 1
fi

# Initial check and update, then loop
log_message "Performing initial check..."
if ! fetch_from_git; then
    log_message "Initial update cycle encountered an error during git fetch - most probably exists old directory."
    cleanup
    exit 1
fi
if ! update_destination_file; then
    log_message "Initial update cycle encountered an error during destination file update."
    cleanup
    exit 1
fi
log_message "Initial update cycle complete."

while true; do
    log_message "Sleeping for $CHECK_INTERVAL seconds..."
    sleep "$CHECK_INTERVAL"
    log_message "----------------------------------------"
    log_message "Starting scheduled check..."
    if fetch_from_git; then
        if ! update_destination_file; then
            log_message "Update cycle encountered an error during destination file update."
            cleanup
            exit 1
        fi
        log_message "Update cycle complete."
    else
        log_message "Update cycle no updates found from previous git fetch."
    fi
done
