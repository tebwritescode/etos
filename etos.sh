#!/bin/bash
#Create a function for logging
log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/etos.log
}
log "#######################################################################################" || echo "#######################################################################################"
log "Starting ETOS Importer" || echo "Starting ETOS Importer"
log "Step 1: Check for and download attachments from email" || echo "Step 1: Check for and download attachments from email"
attachment-downloader --host <EMAIL_SMTP_HOST> --username <EMAIL_ADDRESS> --password <EMAIL_PASSWORD> --imap-folder <EMAIL_FOLDER> --output <EMAIL_OUTPUT_LOCATION> --delete --subject-regex=<EMAIL_SUBJECT_FILTER>
log "Step 2: Declare file array" || echo "Step 2: Declare variables"
declare -a filenames >> /var/log/etos.log
index=0
log "Step 3: Change working directory." || echo "Step 3: Change working directory."
cd <EMAIL_OUTPUT_LOCATION>
log "Step 4: Find all files in working directory" || echo "Step 4: Find all files in working directory"
for file in *; do
        if [[ -f "$file" && "$file" == *.pdf ]]; then
                filenames[index]=$(realpath "$file") >> /var/log/etos.log
                index=$((index + 1)) >> /var/log/etos.log
        fi
done
log "Step 5: Exit if no files found" || echo "Step 5: Exit if no files found"
if [ ${#filenames[@]} -eq 0 ]; then
        echo "Exit: No eligible imports found" || log "Exit: No eligible imports found"
        exit 1
fi
log "Step 6: Loop through all files found" || echo "Step 6: Loop through all files found"
for ((i=0; i < ${#filenames[@]}; i++)); do
	log "Processing: ${filenames[$i]}" || echo "Processing: ${filenames[$i]}"
        log "Converting ${filenames[$i]} to txt" || echo "Converting ${filenames[$i]} to txt"
	pdftotext "${filenames[$i]}" >> /var/log/etos.log
	textfile="${filenames[${i}]%.pdf}.txt"
        log "Txt file is: ${textfile}" || echo "Txt file is: ${textfile}"
	log "Change working directory" || echo "Change working directory"
	cd <LOCATION_OF_OBSIDIAN_VAULT>
        log "Send ${textfile} to ollama for summarizing" || echo "Send ${textfile} to ollama for summarizing"
	log "Ollama output>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" || echo "Ollama output>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	cat "${textfile}" | fabric --model llama3:latest --temp 0 --pattern write_code --remoteOllamaServer <REMOTE_OLLAMA_SERVER> | save New >> /var/log/etos.log
	log "Removing temporary files" || echo "Removing temporary files"
	rm "${filenames[$i]}" >> /var/log/etos.log
        rm "${textfile}" >> /var/log/etos.log
done
log "Cleaning up" || echo "Cleaning up"
rm <EMAIL_OUTPUT_LOCATION>/*.txt >> /var/log/etos.log
rm <EMAIL_OUTPUT_LOCATION>/*.pdf >> /var/log/etos.log
#Stop logging
log "#######################################################################################" | echo "#######################################################################################"
