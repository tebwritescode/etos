#!/bin/bash
# Create a function for logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/etos.log
}

log "#######################################################################################" || echo "#######################################################################################"
log "Starting ETOS Importer" || echo "Starting ETOS Importer"
log "Step 1: Check for and download attachments from email" || echo "Step 1: Check for and download attachments from email"

# Download attachments and rename them to avoid overwriting
attachment-downloader --host <EMAIL_SMTP_HOST> --username <EMAIL_ADDRESS> --password <EMAIL_PASSWORD> --imap-folder <EMAIL_FOLDER> --output <EMAIL_OUTPUT_LOCATION> --delete --subject-regex=<EMAIL_SUBJECT_FILTER> --filename-template="{{date.strftime('%Y-%m-%d-%H-%M-%S-%f')}}_{{ attachment_name }}"

log "Step 2: Declare file array" || echo "Step 2: Declare variables"
declare -a filenames
declare -a basenames
index=0

log "Step 3: Change working directory." || echo "Step 3: Change working directory."
cd /opt/etos/tmp

log "Step 4: Find all files in working directory" || echo "Step 4: Find all files in working directory"
for file in *.pdf; do
    if [[ -f "$file" ]]; then
        fullpath=$(realpath "$file")
	filebase=$(basename "$file" .${file##*.})
        filenames[index]="$fullpath"
	basenames[index]="$filebase"
        log "Found file: $filebase"
        index=$((index + 1))
    fi
done

log "Step 5: Exit if no files found" || echo "Step 5: Exit if no files found"
if [ ${#filenames[@]} -eq 0 ]; then
    echo "Exit: No eligible imports found" || log "Exit: No eligible imports found"
    exit 1
fi

log "Files found: ${filenames[*]}" || echo "Files found: ${filenames[*]}"
log "Step 6: Loop through all files found" || echo "Step 6: Loop through all files found"
log "Changing working directory to <LOCATION_OF_OBSIDIAN_VAULT>" || echo "Changing working directory to <LOCATION_OF_OBSIDIAN_VAULT>"
cd <LOCATION_OF_OBSIDIAN_VAULT>
for ((i=0; i < ${#filenames[@]}; i++)); do
    fullpath="${filenames[$i]}"
    basename="${basenames[$i]}"
    log "Processing: $fullpath" || echo "Processing: $fullpath"
    log "Converting $fullpath to txt" || echo "Converting $fullpath to txt"
    pdftotext "$fullpath" >> /var/log/etos.log
    textfile="${basename}.txt"
    log "Txt file is: $textfile" || echo "Txt file is: $textfile"
    log "Send /opt/etos/tmp/$textfile to ollama for summarizing" || echo "Send /opt/etos/tmp/$textfile to ollama for summarizing"
    log "Ollama output>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" || echo "Ollama output>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    cat "/opt/etos/tmp/$textfile" | fabric --model llama3:latest --temp 0 --pattern write_code --remoteOllamaServer <REMOTE_OLLAMA_SERVER>:11434 | save New >> /var/log/etos.log
    log "Removing temporary files" || echo "Removing temporary files"
    rm "/opt/etos/tmp/$textfile" >> /var/log/etos.log
    rm "$fullpath" >> /var/log/etos.log
done

log "Cleaning up" || echo "Cleaning up"
rm -f /opt/etos/tmp/*.txt >> /var/log/etos.log
rm -f /opt/etos/tmp/*.pdf >> /var/log/etos.log
# Stop logging
log "#######################################################################################" | echo "#######################################################################################"
