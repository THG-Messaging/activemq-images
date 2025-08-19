#!/bin/bash

# Source file to monitor
SOURCE_FILE="/opt/apache-activemq-${AMQ_VERSION}/conf/bridges.xml"

# Destination file with placeholders
DEST_FILE="/opt/apache-activemq-${AMQ_VERSION}/conf/activemq.xml"

# Start and end placeholders
START_PLACEHOLDER="<!--BeginBridges-->"
END_PLACEHOLDER="<!--EndBridges-->"

# Function to update the destination file
update_destination_file() {
    local new_data
    new_data=$(<"$SOURCE_FILE") # Read the content of the source file

    # Check if both placeholders exist in the destination file
    if grep -q "$START_PLACEHOLDER" "$DEST_FILE" && grep -q "$END_PLACEHOLDER" "$DEST_FILE"; then
        # Replace the content between the placeholders with the new data
        awk -v start="$START_PLACEHOLDER" -v end="$END_PLACEHOLDER" -v new_data="$new_data" \
            '{
                if ($0 ~ start) {
                    print
                    print new_data
                    inside = 1
                } else if ($0 ~ end) {
                    inside = 0
                }
                if (!inside) {
                    print
                }
            }' "$DEST_FILE" > "${DEST_FILE}.tmp" \
            && mv "${DEST_FILE}.tmp" "$DEST_FILE"
    else
        echo "Error: One or both placeholders are missing in $DEST_FILE. Please ensure both $START_PLACEHOLDER and $END_PLACEHOLDER exist."
        exit 1
    fi

    echo "Updated content for bridges in $DEST_FILE with new data from $SOURCE_FILE"
}

# Monitor changes in the source file
last_checksum=""
while true; do
    # Calculate the checksum of the source file
    current_checksum=$(md5sum "$SOURCE_FILE" | awk '{print $1}')

    # Check if the checksum has changed
    if [[ "$current_checksum" != "$last_checksum" ]]; then
        update_destination_file
        last_checksum="$current_checksum"
    fi

    # Sleep for a short period before checking again
    sleep 5
done
