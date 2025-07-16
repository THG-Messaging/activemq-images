#!/bin/bash
set -u
AUTH_DEST_FILE="/opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml"
BRIDGES_DEST_FILE="/opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml"
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
    log_message "Fetching latest files '$AUTH_FILE_FROM_REPO' and '$BRIDGES_FILE_FROM_REPO' from Git repository '$GIT_REPO_URL' (branch '$GIT_BRANCH')..."

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
    XPATH_FOR_AUTH_PLUGIN="//*[local-name()='broker']/*[local-name()='plugins']/*[local-name()='authorizationPlugin']"
    CURRENT_MAP=$(xmlstarlet sel -t -c "$XPATH_FOR_AUTH_PLUGIN/*[local-name()='map']" $AUTH_DEST_FILE | sed -e '/<map/c\<map>')
    if diff -q <(xmlstarlet fo "$AUTH_FILE_FROM_REPO") \
                 <(xmlstarlet fo <<< "$CURRENT_MAP")
    then
        log_message "No changes detected between '$AUTH_FILE_FROM_REPO' from git and content in '$AUTH_DEST_FILE'. No update needed."
    else
        log_message "AuthorizationPlugin setup in files '$AUTH_FILE_FROM_REPO' and '$AUTH_DEST_FILE' are different. Preparing new activemq.xml version..."
        local tmp_file=$(mktemp)
        local placeholder="AUTH-MAP-PLACEHOLDER-$(uuid)"
        cp -f $AUTH_DEST_FILE $tmp_file
        xmlstarlet ed -L \
           -d "$XPATH_FOR_AUTH_PLUGIN/*[local-name()='map']" \
           -s "$XPATH_FOR_AUTH_PLUGIN" -t elem -n "" -v "$placeholder" \
           "$tmp_file"
        local status=$?
        if [[ $status -ne 0 ]]; then
            log_message "Failed to update authorization plugin map with xmlstarlet. Aborting..."
            rm -rf $tmp_file
            return 1
        fi
        sed -i -e "/${placeholder}/r ${AUTH_FILE_FROM_REPO}" -e "/${placeholder}/d" "$tmp_file"

        # Final &gt; to > in queue/topic/physicalName attributes
        sed -i -E '/(queue|topic|physicalName)="/s/&gt;/>/g' "$tmp_file"
        if ! xmlstarlet val "$tmp_file"; then
            log_message "Error: XML validation of new activemq.xml file failed. Aborting..."
            # cat $tmp_file
            rm -rf $tmp_file
            return 1
        fi
        log_message "Deploying new activemq.xml configuration (diff bellow)..."
        diff -u <(xmlstarlet fo $AUTH_DEST_FILE) <(xmlstarlet fo $tmp_file)
        mv $tmp_file $AUTH_DEST_FILE
    fi

    # Compare new bridges data from git with current bridges data in dest, ignoring password and uri attributes
    XPATH_FOR_BROKER="//*[local-name()='broker']"
    CURRENT_BRIDGES=$(xmlstarlet sel -t -c "$XPATH_FOR_BROKER/*[local-name()='networkConnectors']" $BRIDGES_DEST_FILE \
                         | sed -e '/<networkConnectors/c\<networkConnectors>')
    if diff -q \
           <(xmlstarlet ed -d "//networkConnector/@password" -d "//networkConnector/@uri" "$BRIDGES_FILE_FROM_REPO" | xmlstarlet fo) \
           <(xmlstarlet ed -d "//networkConnector/@password" -d "//networkConnector/@uri" <<<"$CURRENT_BRIDGES" | xmlstarlet fo)
    then
        log_message "No changes detected between '$BRIDGES_FILE_FROM_REPO' from git and content in '$BRIDGES_DEST_FILE'. No update needed."
    else
        log_message "Files '$BRIDGES_FILE_FROM_REPO' and '$BRIDGES_DEST_FILE' are different. Preparing new version..."
        local src_tmp_file=$(mktemp)
        cp -f $BRIDGES_FILE_FROM_REPO $src_tmp_file

        log_message "Adding URI and Password fields to copy of $BRIDGES_FILE_FROM_REPO ($src_tmp_file)"
        for user in $(xmlstarlet sel -t -v "//networkConnectors/networkConnector/@userName" -n "$src_tmp_file"); do
            log_message "--> Processing bridge with user: $user"
            local password="$user"
            password=$(awk -F'=' -v user="$user" '$1 == user {print $2}' $USERS_PROPERTIES)
            xmlstarlet ed -L -O \
                -u "//networkConnectors/networkConnector[@userName='$user']/@uri" -v "$BRIDGE_CONNECTION_STRING" \
                -s "//networkConnectors/networkConnector[@userName='$user' and not(@uri)]" -t attr -n "uri" -v "$BRIDGE_CONNECTION_STRING" \
                -u "//networkConnectors/networkConnector[@userName='$user']/@password" -v "$password" \
                -s "//networkConnectors/networkConnector[@userName='$user' and not(@password)]" -t attr -n "password" -v "$password" \
            "$src_tmp_file"
            local status=$?
            if [[ $status -ne 0 ]]; then
               log_message "Failed to update uri and password attribute for bridge of user '$user' using xmlstarlet. Printing file and aborting..."
               cat $src_tmp_file
               rm -rf $src_tmp_file
               return 1
            fi
        done

        local dest_tmp_file=$(mktemp)
        local bridges_placeholder="NETWORKCONNECTORS-PLACEHOLDER-$(uuid)"
        cp -f $BRIDGES_DEST_FILE $dest_tmp_file

        xmlstarlet ed -L \
           -d "$XPATH_FOR_BROKER/*[local-name()='networkConnectors']" \
           -s "$XPATH_FOR_BROKER" -t elem -n "" -v "$bridges_placeholder" \
           "$dest_tmp_file"
        local status=$?
        if [[ $status -ne 0 ]]; then
            log_message "Failed to update networkConnectors with xmlstarlet. Aborting..."
            rm -rf $src_tmp_file $dest_tmp_file
            return 1
        fi
        sed -i -e "/${bridges_placeholder}/r ${src_tmp_file}" -e "/${bridges_placeholder}/d" "$dest_tmp_file"

        # Final &gt; to > in queue/topic/physicalName attributes
        sed -i -E '/(queue|topic|physicalName)="/s/&gt;/>/g' "$dest_tmp_file"

        if ! xmlstarlet val "$dest_tmp_file"; then
            log_message "Error: XML validation of new activemq.xml failed. Printing file and aborting..."
            cat $dest_tmp_file
            rm -rf $src_tmp_file $dest_tmp_file
            return 1
        fi
        log_message "Deploying new activemq.xml configuration (diff bellow)..."
        diff -u <(xmlstarlet fo $BRIDGES_DEST_FILE) <(xmlstarlet fo $dest_tmp_file)
        mv "$dest_tmp_file" "$BRIDGES_DEST_FILE"
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
