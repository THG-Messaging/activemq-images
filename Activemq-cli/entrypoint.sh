#!/bin/bash
source /config/config.env
REPO_DIR="activemq-config-repo"
SOURCE_FILE_PATH="/bindings/bindings"
# Pull Request CLI tool: "gh" (GitHub CLI), "glab" (GitLab CLI), or "none"
PR_CLI_TOOL="gh" # Set to "gh" or "glab" to enable automatic PR creation
LAST_MOD_TIME=0

# Function to print messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

# Function to print error messages (does not exit in loop)
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

# Function to print debug messages if DEBUG_MODE is true
log_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $1"
    fi
}

# Function to print error messages and exit (for critical setup errors)
error_exit() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CRITICAL] $1" >&2
    # Optional: Clean up cloned repo if needed
    # rm -rf "$REPO_DIR"
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to decode common XML entities in a string
decode_xml_entities_for_value() {
    local value=$1
    # Order matters for &amp;
    value="${value//&amp;/&}" 
    value="${value//&gt;/>}"
    value="${value//&lt;/<}"
    value="${value//&quot;/'"'}"
    value="${value//&apos;/"'"}"
    echo "$value"
}

# Function to fix &gt; to > in queue/topic attributes using Awk
# This is run once at the end of all modifications.
fix_gt_in_xml_attributes_final() {
    local file_to_fix=$1
    local temp_file
    temp_file=$(mktemp) || { log_error "Failed to create temp file for XML fix."; return 1; } 

    log "Applying final &gt; to > conversion using awk..."
    # Use awk to process the file and fix only within queue/topic attributes
    awk -F'"' -v OFS='"' '{
        for (i=2; i<=NF; i+=2) { # Loop through attribute values (even indices)
            # Check if the preceding field is queue= or topic=
            if ($(i-1) ~ /(queue|topic)=$/) {
                gsub(/&gt;/, ">", $i); # Replace &gt; with > within the value $i
            }
        }
        print $0; # Print the (potentially modified) line
    }' "$file_to_fix" > "$temp_file"

    # Check if awk succeeded before replacing the original file
    if [[ $? -eq 0 ]]; then
        mv "$temp_file" "$file_to_fix" || { log_error "Failed to move temp file over original XML."; rm -f "$temp_file"; return 1; }
        log "Final &gt; to > conversion complete."
        return 0
    else
        log_error "CRITICAL: Failed during final &gt; to > conversion using awk. File may be inconsistent."
        rm -f "$temp_file" # Clean up temp file on error
        return 1
    fi
}

generate_branch_name() {
    local username_part=$1 
    local timestamp=$(date +%Y%m%d%H%M%S)

    if [[ -n "$username_part" ]]; then
        local sanitized_user=$(echo "$username_part" | sed 's/[^a-zA-Z0-9]/-/g' | cut -c1-30) 
        echo "auth/sync-mq-user-${sanitized_user}-${timestamp}"
    else
        echo "auth/auto-mq-sync-${timestamp}" 
    fi
}

fixed_branch_name() {
    local username_part=$1 

    if [[ -n "$username_part" ]]; then
        local sanitized_user=$(echo "$username_part" | sed 's/[^a-zA-Z0-9]/-/g' | cut -c1-30) 
        echo "auth/sync-mq-user-${sanitized_user}"
    else
        echo "auth/auto-mq-sync"
    fi
}

check_duplicate() {
    local file=$1
    local destination_name=$2 # Original name (may contain '>')
    local user=$3
    local destination_type=$4 # 'queue' or 'topic'

    local dest_attr_name="queue" 
    if [[ "$destination_type" == "topic" ]]; then
        dest_attr_name="topic"
    fi

    # XMLStarlet 'sel' decodes entities for predicate matching.
    local safe_destination_name=$(echo "$destination_name" | sed "s/'/&apos;/g; s/\"/&quot;/g") 
    local safe_user=$(echo "$user" | sed "s/'/&apos;/g; s/\"/&quot;/g")
    # Exact match for read, write, and admin attributes
    local query="//authorizationMap/authorizationEntries/authorizationEntry[@${dest_attr_name}='${safe_destination_name}' and @read='${safe_user}' and @write='${safe_user}' and @admin='${safe_user}']"
    
    xmlstarlet sel -Q -t -c "$query" "$file" 2>/dev/null 
    if [[ $? -eq 0 ]]; then
        return 0 # Duplicate found
    else
        return 1 # No duplicate / Error
    fi
}

add_authorization_entry() {
    local file=$1
    local destination_name=$2 # Original name (may contain '>')
    local user=$3
    local destination_type=$4 

    local dest_attr_name="queue"
    if [[ "$destination_type" == "topic" ]]; then
        dest_attr_name="topic"
    fi

    log "Adding $destination_type entry for user '$user' and destination '$destination_name' to $file"
    # Let xmlstarlet encode '>' to '&gt;' if needed
    xmlstarlet ed -L -O \
        -s "//authorizationMap/authorizationEntries" -t elem -n "authorizationEntryTMP" -v "" \
        -i "//authorizationMap/authorizationEntries/authorizationEntryTMP" -t attr -n "$dest_attr_name" -v "$destination_name" \
        -i "//authorizationMap/authorizationEntries/authorizationEntryTMP" -t attr -n "read" -v "$user" \
        -i "//authorizationMap/authorizationEntries/authorizationEntryTMP" -t attr -n "write" -v "$user" \
        -i "//authorizationMap/authorizationEntries/authorizationEntryTMP" -t attr -n "admin" -v "$user" \
        -r "//authorizationMap/authorizationEntries/authorizationEntryTMP" -v "authorizationEntry" \
        "$file"
    local status=$?

    if [[ $status -ne 0 ]]; then
        log_error "Failed to add $destination_type entry for user '$user', destination '$destination_name' using xmlstarlet."
        return 1
    fi
    return 0
}

remove_authorization_entry() {
    local file=$1
    local user=$2
    local destination_name=$3 # Original name (may contain '>')
    local destination_type=$4

    # Ensure destination name is not empty before attempting removal
    if [[ -z "$destination_name" ]]; then
        log_error "Attempted to remove entry with empty destination name for user '$user'. Skipping."
        return 1 # Indicate failure to remove
    fi

    local dest_attr_name="queue"
    if [[ "$destination_type" == "topic" ]]; then
        dest_attr_name="topic"
    fi
    
    log "Removing $destination_type entry for user '$user' and destination '$destination_name' from $file"
    local safe_destination_name_xpath=$(echo "$destination_name" | sed "s/'/&apos;/g; s/\"/&quot;/g")
    local safe_user_xpath=$(echo "$user" | sed "s/'/&apos;/g; s/\"/&quot;/g")
    local xpath_query="//authorizationMap/authorizationEntries/authorizationEntry[@${dest_attr_name}='${safe_destination_name_xpath}' and @read='${safe_user_xpath}' and @write='${safe_user_xpath}' and @admin='${safe_user_xpath}']"

    log_debug "[Remove] XPath for deletion: $xpath_query"
    if xmlstarlet sel -Q -t -c "$xpath_query" "$file"; then
        log_debug "[Remove] Entry EXISTS before attempting xmlstarlet ed -d."
    else
        log_debug "[Remove] Entry does NOT exist with XPath '$xpath_query' before attempting xmlstarlet ed -d. This might be okay if already removed or never existed according to this precise XPath."
        return 0 
    fi
    
    xmlstarlet ed -L -O -d "$xpath_query" "$file"
    local delete_status=$?

    if [[ $delete_status -ne 0 ]]; then
        log_error "xmlstarlet ed -d command failed with status $delete_status for user '$user', destination '$destination_name'."
        return 1 
    fi

    # Verify deletion
    log_debug "[Remove] After removal attempt, re-checking existence with XPath: $xpath_query"
    if xmlstarlet sel -Q -t -c "$xpath_query" "$file"; then
        log_error "VERIFICATION FAILED: [Remove] Entry for user '$user', $destination_type '$destination_name' still exists after attempting removal."
        return 1
    else
        log "VERIFICATION PASSED: [Remove] Entry for user '$user', $destination_type '$destination_name' successfully removed."
    fi
    return 0
}

get_existing_user_authorizations() {
    local file=$1
    local user=$2
    local -a combined_auths # Local indexed array

    local safe_user=$(echo "$user" | sed "s/'/&apos;/g; s/\"/&quot;/g")

    # Get queue authorizations where user is sole r/w/a
    mapfile -t user_queues_raw < <(xmlstarlet sel -t -m "//authorizationMap/authorizationEntries/authorizationEntry[@read='${safe_user}' and @write='${safe_user}' and @admin='${safe_user}'][@queue]" -v "@queue" -n "$file" 2>/dev/null | sed '/^\s*$/d')
    for q_item_raw in "${user_queues_raw[@]}"; do
        local q_item_decoded=$(decode_xml_entities_for_value "$q_item_raw")
        local q_item_trimmed=$(echo "$q_item_decoded" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$q_item_trimmed" ]]; then
             combined_auths+=("queue:$q_item_trimmed")
        fi
    done

    # Get topic authorizations where user is sole r/w/a
    mapfile -t user_topics_raw < <(xmlstarlet sel -t -m "//authorizationMap/authorizationEntries/authorizationEntry[@read='${safe_user}' and @write='${safe_user}' and @admin='${safe_user}'][@topic]" -v "@topic" -n "$file" 2>/dev/null | sed '/^\s*$/d')
    for t_item_raw in "${user_topics_raw[@]}"; do
        local t_item_decoded=$(decode_xml_entities_for_value "$t_item_raw")
        local t_item_trimmed=$(echo "$t_item_decoded" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$t_item_trimmed" ]]; then
            combined_auths+=("topic:$t_item_trimmed")
        fi
    done

    # Print unique entries, one per line
    if [[ ${#combined_auths[@]} -gt 0 ]]; then
        printf "%s\n" "${combined_auths[@]}" | sort -u
    fi
}


# Function to setup/update the local git repository
setup_repo() {
    log "Setting up Git repository..."
    gh auth login --with-token < /config/github_token.sec
    gh auth setup-git
    local target_dir_to_config_git="$REPO_DIR" 

    if [ -d "$REPO_DIR/.git" ]; then
        log "Repository directory '$REPO_DIR' exists. Updating."
        cd "$REPO_DIR" || { log_error "Could not change directory to $REPO_DIR"; return 1; }

        if [[ -n "$(git status --porcelain)" ]]; then
            log "Uncommitted changes or untracked files detected. Stashing them."
            git stash push -u -m "Auto-stash before repo update $(date +%Y%m%d%H%M%S)" || { log_error "Failed to stash local changes."; cd ..; return 1; }
            log "Local changes stashed."
        else
            log "Repository is clean. No stash needed."
        fi

        log "Checking out $GIT_BRANCH..."
        git checkout "$GIT_BRANCH" || { log_error "Could not checkout $GIT_BRANCH. Stashed changes might need manual recovery if any."; cd ..; return 1; }

        log "Fetching changes from origin for $GIT_BRANCH..."
        git fetch origin || { log_error "Could not fetch from origin"; cd ..; return 1; } 

        log "Resetting local $GIT_BRANCH to match origin/$GIT_BRANCH..."
        git reset --hard "origin/$GIT_BRANCH" || { log_error "Could not reset $GIT_BRANCH to origin/$GIT_BRANCH"; cd ..; return 1; }
        
        log "Local $GIT_BRANCH is now up-to-date with origin/$GIT_BRANCH."
        cd .. || { log_error "Could not change directory back from $REPO_DIR"; return 1; } 
    else
        log "Cloning repository $GIT_REPO_URL into '$REPO_DIR'..."
        rm -rf "$REPO_DIR" 
        git clone --branch "$GIT_BRANCH" "$GIT_REPO_URL" "$REPO_DIR" || { log_error "Could not clone repository."; return 1; }
    fi

    log "Configuring Git user for repository at '$target_dir_to_config_git'..."
    if [[ -n "$GIT_USER_NAME" && -n "$GIT_USER_EMAIL" ]]; then
        (cd "$target_dir_to_config_git" && \
         git config user.name "$GIT_USER_NAME" && \
         git config user.email "$GIT_USER_EMAIL") || \
         { log_error "Failed to configure git user name/email in $target_dir_to_config_git."; return 1; }
        log "Git user name and email configured locally for this repository."
    else
        log_error "GIT_USER_NAME or GIT_USER_EMAIL is not set in the script configuration. Commits will likely fail."
    fi
    return 0 
}

# Function to attempt automatic PR creation
create_pull_request() {
    local current_branch_name=$1
    local target_branch_name=$2
    local pr_title=$3
    local pr_body=$4

    if [[ "$PR_CLI_TOOL" == "none" ]]; then
        log "Automatic PR creation is disabled (PR_CLI_TOOL=none)."
        return 1
    fi

    if ! command_exists "$PR_CLI_TOOL"; then
        log_error "PR CLI tool '$PR_CLI_TOOL' not found. Please install it or set PR_CLI_TOOL to 'none'."
        return 1
    fi

    log "Attempting to create Pull Request using '$PR_CLI_TOOL'..."
    case "$PR_CLI_TOOL" in
        gh)
            if gh pr list --head $BRANCH_NAME | grep -q "."; then
               log "Pull Request already exists for branch ${BRANCH_NAME}. Nothing to do."
            else
                gh pr create --base "$target_branch_name" --head "$current_branch_name" --title "$pr_title" --body "$pr_body"
            fi
            ;;
        glab)
            glab mr create --base "$target_branch_name" --head "$current_branch_name" --title "$pr_title" --description "$pr_body" --yes 
            ;;
        *)
            log_error "Unsupported PR_CLI_TOOL: '$PR_CLI_TOOL'. Supported: gh, glab, none."
            return 1
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        log "Pull Request created successfully using $PR_CLI_TOOL."
        return 0
    else
        log_error "Failed to create Pull Request using $PR_CLI_TOOL."
        return 1
    fi
}

rollback_git_changes (){
    local error_message=$1
    local branch_name=$2
    log_error "$error_message"
    if [[ "$RUN_ONCE" != "true" ]]; then
        git checkout "$GIT_BRANCH"
        git branch -D "$branch_name"
        sleep "$SLEEP_INTERVAL"
        cd ..
    fi
}

# === Main Monitoring Loop ===
log "Starting ActiveMQ authorization sync script."
log "Watching source file: $SOURCE_FILE_PATH"
log "Repository: $GIT_REPO_URL"
log "XML Path: $BROKER_NAME"
log "Run once: $RUN_ONCE"
log "Check interval: $SLEEP_INTERVAL seconds"
log "Automatic PR creation tool: $PR_CLI_TOOL"
log "Debug mode: $DEBUG_MODE"

KEEP_RUNNING=true
while [ "$KEEP_RUNNING" == "true" ]; do
    # --- Runs once if requested by env variable ---
    if [[ "$RUN_ONCE" == "true" ]]; then
        KEEP_RUNNING=false
    fi

    # --- Check Target Username ENV Var ---
    if [[ -z "$TARGET_USERNAME" ]]; then
        log_error "TARGET_USERNAME environment variable is not set or empty. Skipping run."
        sleep "$SLEEP_INTERVAL"
        continue
    fi
    log "Processing for target user: '$TARGET_USERNAME'"

    # --- Check Source File ---
    if [ ! -f "$SOURCE_FILE_PATH" ]; then
        log_error "Source file '$SOURCE_FILE_PATH' not found. Skipping check."
        sleep "$SLEEP_INTERVAL"
        continue
    fi

    CURRENT_MOD_TIME=$(stat -c %Y "$SOURCE_FILE_PATH" 2>/dev/null || stat -f %m "$SOURCE_FILE_PATH" 2>/dev/null)
    if [[ -z "$CURRENT_MOD_TIME" ]]; then
         log_error "Could not get modification time for '$SOURCE_FILE_PATH'. Skipping check."
         sleep "$SLEEP_INTERVAL"
         continue
    fi

    if [[ "$CURRENT_MOD_TIME" -gt "$LAST_MOD_TIME" ]]; then
        log "Detected change in source file '$SOURCE_FILE_PATH' (Mod Time: $CURRENT_MOD_TIME)."

        if ! setup_repo; then
             log_error "Failed to setup/update repository. Skipping processing run."
             sleep "$SLEEP_INTERVAL"
             continue 
        fi

        cd "$REPO_DIR" || { log_error "Critical: Could not change directory to $REPO_DIR after setup. Stopping."; exit 1; }

        # --- Makeing new branch from $GIT_BRANCH, or fixed user branch (if it exists - previous PR not merged so updating) 
        BRANCH_NAME="TBD"
        if [[ "$RUN_ONCE" == "true" ]]; then
            BRANCH_NAME=$(fixed_branch_name "$TARGET_USERNAME")
            log "Creating and/or checking out fixed branch: $BRANCH_NAME for user $TARGET_USERNAME"
            if git ls-remote --exit-code --heads origin "$BRANCH_NAME"; then
                # --- BRANCH ALREADY EXISTS (PR is likely open) ---
                log "Branch '$BRANCH_NAME' already exists on remote. Checking it out."
                git checkout "$BRANCH_NAME" || { log_error "Could not create branch $BRANCH_NAME from $GIT_BRANCH."; continue; }
            else
                # --- BRANCH DOES NOT EXIST (First time or after a merge) ---
                log "Branch '$BRANCH_NAME' does not exist on remote. Creating new branch from main."
                git checkout -b "$BRANCH_NAME" || { log_error "Could not create branch $BRANCH_NAME from $GIT_BRANCH."; continue; }
            fi
        else
            BRANCH_NAME=$(generate_branch_name "$TARGET_USERNAME")
            log "Creating and checking out new branch: $BRANCH_NAME (from $GIT_BRANCH)"
            git checkout -b "$BRANCH_NAME" "$GIT_BRANCH" \
                || { log_error "Could not create branch $BRANCH_NAME from $GIT_BRANCH."; cd ..; sleep "$SLEEP_INTERVAL"; continue; }
        fi

        XML_FILE_FULL_PATH="$BROKER_NAME" 
        if [ ! -f "$XML_FILE_FULL_PATH" ]; then
            log_error "ActiveMQ XML file not found at '$XML_FILE_FULL_PATH'. Skipping processing."
            cd .. 
            sleep "$SLEEP_INTERVAL"
            continue
        fi

        # --- Phase 1: Collect Desired State from Source File for TARGET_USERNAME ---
        declare -A desired_auths_map_this_user # Associative array: desired_auths_map_this_user[type:dest]=1

        log "Phase 1: Parsing source file '$SOURCE_FILE_PATH' to determine desired state for user '$TARGET_USERNAME'..."
        while IFS= read -r line || [[ -n "$line" ]]; do
            log_debug "Read line from source: '$line'"
            line=$(echo "$line" | sed 's/,$//') 
            IFS=',' read -r -a fields <<< "$line"
            
            # Source file no longer contains username
            
            declare -a destination_names_arr
            destination_type_val="queue" 
            num_fields_val=${#fields[@]}

            if [[ $num_fields_val -lt 1 ]]; then # Need at least one destination field
                log_error "Skipping malformed line (num_fields: $num_fields_val < 1) for line: '$line'"
                continue
            fi

            last_field_val_lower_val=$(echo "${fields[$((num_fields_val - 1))]}" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            destinations_end_index_val=$((num_fields_val - 1)) 

            if [[ "$last_field_val_lower_val" == "topic" ]]; then
                destination_type_val="topic"
                destinations_end_index_val=$((num_fields_val - 2)) 
            elif [[ "$last_field_val_lower_val" == "queue" ]]; then
                destination_type_val="queue" 
                destinations_end_index_val=$((num_fields_val - 2)) 
            fi
            
            if [[ $destinations_end_index_val -lt 0 ]]; then # Check if index is valid
                 log_error "Skipping malformed line (dest_idx: $destinations_end_index_val < 0): '$line'"
                 continue
            fi

            for (( i=0; i<=destinations_end_index_val; i++ )); do # Index starts from 0 now
                dest_name_trimmed=$(echo "${fields[$i]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ -n "$dest_name_trimmed" ]]; then
                    entry_to_store="${destination_type_val}:${dest_name_trimmed}"
                    log_debug "    Dest name: '$dest_name_trimmed', Type: '$destination_type_val', Entry to store: '$entry_to_store'"
                    # Add to map if not already present
                    if [[ -z "${desired_auths_map_this_user[$entry_to_store]}" ]]; then
                        desired_auths_map_this_user["$entry_to_store"]=1
                        log_debug "      Added to desired_auths_map_this_user: ['$entry_to_store']=1. Current map keys: (${!desired_auths_map_this_user[@]})"
                    else
                        log_debug "      Entry '$entry_to_store' already in desired_auths_map_this_user"
                    fi
                fi
            done
        done < "../$SOURCE_FILE_PATH"
        log "Phase 1: Desired state collection complete for user '$TARGET_USERNAME'."
        log_debug "  Built desired_auths_map_this_user for '$TARGET_USERNAME' (keys count ${#desired_auths_map_this_user[@]}):"
        for key_debug in "${!desired_auths_map_this_user[@]}"; do log_debug "    - '$key_debug'"; done

        # --- Phase 2: Synchronize activemq.xml for TARGET_USERNAME ---
        log "Phase 2: Synchronizing activemq.xml for user '$TARGET_USERNAME'..."
        changes_made_in_batch=false

        # Get existing authorizations into an indexed array for the target user
        mapfile -t current_xml_auths_arr < <(get_existing_user_authorizations "$XML_FILE_FULL_PATH" "$TARGET_USERNAME")
        log_debug "  Existing XML auths for '$TARGET_USERNAME' (count ${#current_xml_auths_arr[@]}):"
        for existing_entry_debug in "${current_xml_auths_arr[@]}"; do log_debug "    - '$existing_entry_debug'"; done

        # Removals: Iterate existing XML entries and remove if not in desired map
        log_debug "Checking for removals for user '$TARGET_USERNAME'..."
        for existing_auth_entry in "${current_xml_auths_arr[@]}"; do
             log_debug "  Checking existing XML entry: '$existing_auth_entry'"
            if [[ -z "${desired_auths_map_this_user[$existing_auth_entry]}" ]]; then # Check if key exists in desired map
                log_debug "    '$existing_auth_entry' NOT in desired map. Preparing to remove."
                existing_type=$(echo "$existing_auth_entry" | cut -d: -f1)
                existing_name=$(echo "$existing_auth_entry" | cut -d: -f2-) 
                if [[ -n "$existing_name" ]]; then 
                    if remove_authorization_entry "$XML_FILE_FULL_PATH" "$TARGET_USERNAME" "$existing_name" "$existing_type"; then
                        changes_made_in_batch=true
                    else
                         log_error "  Failed to remove $existing_type '$existing_name' for user '$TARGET_USERNAME'."
                    fi
                else
                     log_error "  Skipping removal of entry with empty destination name: $existing_auth_entry"
                fi
            else
                 log_debug "    '$existing_auth_entry' IS in desired map. Keeping."
            fi
        done

        # Additions: Iterate desired entries and add if not in current XML array
        log_debug "Checking for additions for user '$TARGET_USERNAME'..."
        for desired_auth_entry in "${!desired_auths_map_this_user[@]}"; do
             log_debug "  Checking desired entry: '$desired_auth_entry'"
             is_existing_in_xml=false
             for current_entry_from_xml_arr in "${current_xml_auths_arr[@]}"; do # Iterate the original array from XML
                 if [[ "$desired_auth_entry" == "$current_entry_from_xml_arr" ]]; then
                     is_existing_in_xml=true
                     break
                 fi
             done

             if ! $is_existing_in_xml; then
                log_debug "    '$desired_auth_entry' NOT in current XML. Preparing to add."
                desired_type=$(echo "$desired_auth_entry" | cut -d: -f1)
                desired_name=$(echo "$desired_auth_entry" | cut -d: -f2-) 
                if [[ -z "$desired_name" ]]; then 
                   log_error "  Skipping add for entry with empty destination name: $desired_auth_entry"
                   continue
                fi
                if ! check_duplicate "$XML_FILE_FULL_PATH" "$desired_name" "$TARGET_USERNAME" "$desired_type"; then
                    if add_authorization_entry "$XML_FILE_FULL_PATH" "$desired_name" "$TARGET_USERNAME" "$desired_type"; then
                       changes_made_in_batch=true
                    else
                        log_error "  Failed to add $desired_type '$desired_name' for user '$TARGET_USERNAME'."
                    fi
                else
                    log "  Skipping add for '$desired_auth_entry' for user '$TARGET_USERNAME' - check_duplicate indicates it already exists."
                fi
             else
                 log_debug "    '$desired_auth_entry' IS in current XML. No action."
             fi
        done
        log "Phase 2: Synchronization complete for user '$TARGET_USERNAME'."
        
        if $changes_made_in_batch; then
            if ! fix_gt_in_xml_attributes_final "$XML_FILE_FULL_PATH"; then
                log_error "CRITICAL: Failed to apply final &gt; fix for $XML_FILE_FULL_PATH after all changes."
            fi
        fi
        
        if ! $changes_made_in_batch; then
            log "No changes were made to $BROKER_NAME for user '$TARGET_USERNAME'."
        else
            log "Changes detected. Proceeding with Git operations for user '$TARGET_USERNAME'."
            
            log "Staging changes..."
            if [ -f "$XML_FILE_FULL_PATH" ]; then
                git add "$XML_FILE_FULL_PATH" || { rollback_git_changes "Could not stage changes for $XML_FILE_FULL_PATH." "$BRANCH_NAME"; continue; }
            else
                rollback_git_changes "File $XML_FILE_FULL_PATH not found after processing. Cannot stage changes." "$BRANCH_NAME"
                continue;
            fi

            COMMIT_SUBJECT="feat: Sync ActiveMQ auth for $TARGET_USERNAME"
            COMMIT_BODY="Automated synchronization of ActiveMQ authorizations for user '$TARGET_USERNAME'.

Entries were added or removed to match the source file configuration."
            log "Committing changes..."
            git commit -m "$COMMIT_SUBJECT" -m "$COMMIT_BODY" || { rollback_git_changes "Could not commit changes." "$BRANCH_NAME"; continue; }

            log "Pushing branch '$BRANCH_NAME' to origin..."
            if [[ "$RUN_ONCE" == "true" ]]; then
                git push --force origin "$BRANCH_NAME" || { rollback_git_changes "Could not push branch $BRANCH_NAME to origin." "$BRANCH_NAME"; continue; }
            else
                git push -u origin "$BRANCH_NAME" || { rollback_git_changes "Could not push branch $BRANCH_NAME to origin." "$BRANCH_NAME"; continue; }
            fi

            log "Branch '$BRANCH_NAME' pushed successfully."
            
            if ! create_pull_request "$BRANCH_NAME" "$GIT_BRANCH" "$COMMIT_SUBJECT" "$COMMIT_BODY"; then
                log "Manual PR creation needed for branch '$BRANCH_NAME' to '$GIT_BRANCH'."
                log "Title: $COMMIT_SUBJECT"
                log "Body: $COMMIT_BODY"
            fi

            git checkout "$GIT_BRANCH" || log_error "Could not check out $GIT_BRANCH after push."
        fi

        LAST_MOD_TIME=$CURRENT_MOD_TIME
        log "Updated last processed modification time to $LAST_MOD_TIME."
        cd .. 
    else
        : 
    fi
    if [[ "$RUN_ONCE" != "true" ]]; then
        sleep "$SLEEP_INTERVAL"
    fi
done

log "Script finished (unexpectedly)."
exit 0
