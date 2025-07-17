#!/bin/bash
# Define log levels and output functions
LOG_LEVEL=INFO
MAX_LOG_LINES=1000
log_debug() { [ "$LOG_LEVEL" = "DEBUG" ] && echo "$(date +"%Y%m%d_%H%M%S") - DEBUG: $@"; }
log_info() { echo "$(date +"%Y%m%d_%H%M%S") - INFO: $@"; }
log_warn() { echo "$(date +"%Y%m%d_%H%M%S") - WARN: $@" >&2; }
log_error() { echo "$(date +"%Y%m%d_%H%M%S") - ERROR: $@" >&2; }

# Configuration for Obsidian REST API
OBSIDIAN_API_URL="http://127.0.0.1:27123"
OBSIDIAN_API_KEY="APIKEY"  # Replace with your actual API key

# Step 1: Add date and time stamp to the fetched email file name
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FETCHED_EMAIL_FILE="/home/etos/fetched_email_${TIMESTAMP}.txt"
LOG_FILE="/var/log/etos_cron.log"
touch $FETCHED_EMAIL_FILE

# Add a visual separator
log_info "-------------------------- $(date) --------------------------"

# Log FETCH operation
log_info "Fetching emails..."
if [ "$LOG_LEVEL" = "DEBUG" ]; then
    fetchmail -v --mda "cat > $FETCHED_EMAIL_FILE" --keep --fetchlimit 1 # add --fetchall to get emails that have been fetched before
else
    fetchmail -s --mda "cat > $FETCHED_EMAIL_FILE" --keep --fetchlimit 1 # add --fetchall to get emails that have been fetched before
fi

# Step 2: Extract the first URL from the email body
EMAIL_URL=$(sed -n 's/.*\(http[s]:\/\/[^ ]*\).*/\1/p' "$FETCHED_EMAIL_FILE" | head -n 1)
if [ "$LOG_LEVEL" = "DEBUG" ]; then
    log_debug "Extracted URL: $EMAIL_URL"
fi

# Step 3: Verify that the URL is not empty and is a valid URL format
if [[ "$EMAIL_URL" =~ ^http[s]?:\/\/[a-zA-Z0-9.-]+\/?.*$ ]]; then
    # Log successful extraction
    log_info "Extracted URL: $EMAIL_URL"

    # Step 4: Use fabric to process the URL
    FABRIC_OUTPUT=$(mktemp)

    # Run the fabric command with the extracted URL
    /usr/local/bin/fabric --pattern explain_docs --output="$FABRIC_OUTPUT" --scrape_url="$EMAIL_URL"

    if [ $? -ne 0 ]; then
        log_error "Fabric execution failed!"
        rm "$FABRIC_OUTPUT"
        exit 1
    else
        log_info "Fabric execution successful!"
    fi

    # Step 5: Extract the title for naming the note - only get the first line matching title pattern
    TITLE=$(head -n 10 "$FABRIC_OUTPUT" | grep -E '^(# |Title: )' | head -n 1 | sed -E 's/^# //;s/^Title: //')

    if [ -z "$TITLE" ]; then
        # If no title found, use a default name with timestamp
        TITLE="New_${TIMESTAMP}"
        log_debug "No title found in the first 10 lines of the file, using default: $TITLE"
    else
        # Clean up the title by removing unwanted characters
        TITLE=$(echo "$TITLE" | sed -E 's/^(# |Title: )//; s/[ ]+/_/g; s/[^[:alnum:]_.-]//g; s/__+/_/g')
        log_debug "Using extracted title: $TITLE"
    fi

    # Step 6: Prepare content for API
    TEMP_CONTENT_FILE=$(mktemp)
    echo -e "URL: $EMAIL_URL\n\n$(cat "$FABRIC_OUTPUT")" > "$TEMP_CONTENT_FILE"

    # Test API connectivity before making the call
    log_debug "Testing Obsidian API connectivity..."
    test_response=$(curl -s -o /dev/null -w "%{http_code}" "${OBSIDIAN_API_URL}/")
    if [ "$test_response" = "200" ]; then
        log_debug "Obsidian API is accessible"
    else
        log_error "Obsidian API is not accessible, received code: $test_response"
    fi

    # URL encode the title for the API path
    ENCODED_TITLE=$(echo "$TITLE" | sed 's/ /%20/g')

    # Step 7: Send the content to Obsidian via REST API
    log_info "Sending content to Obsidian via REST API..."

    curl_output=$(curl -s -X PUT \
      "${OBSIDIAN_API_URL}/vault/New/${ENCODED_TITLE}.md" \
      -H "Authorization: Bearer ${OBSIDIAN_API_KEY}" \
      -H "Content-Type: text/markdown" \
      --data-binary @"$TEMP_CONTENT_FILE" \
      --write-out "%{http_code}" \
      -o /dev/null)

    CURL_EXIT_CODE=$?
    HTTP_CODE=$curl_output

    if [ $CURL_EXIT_CODE -ne 0 ]; then
        log_error "Failed to send content to Obsidian API. CURL exit code: $CURL_EXIT_CODE"
    elif [ "$HTTP_CODE" -ge 400 ]; then
        log_error "Obsidian API returned error code: $HTTP_CODE"
    else
        log_info "Successfully sent content to Obsidian API. Note created: $TITLE.md"
    fi

    # Clean up temporary files
    rm "$TEMP_CONTENT_FILE"
    rm "$FABRIC_OUTPUT"
else
    # Log invalid URL
    log_info "No valid URL found in the email: $EMAIL_URL or no new email."
fi

# Cleanup Home Directory
log_info "Cleaning Home Directory"
rm -rf /home/etos/fetched_email_*.txt
log_info "Finished"
