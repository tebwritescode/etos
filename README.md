# etos
The script checks an email for emails with a specific subject, downloads pdf attachments from that email to a temporary folder, converts that PDF to a TXT file, pipes that text file through Fabric to ollama, and saves the reply from ollama/fabric to a locally mounted obsidian directory.

# Usage Example
I use this to email pdf files of step by step instructions to be added to my Obsidian vault. The fabric pattern is designed to extract ONLY the step by step instructions from the PDF and save those to Obsidian. I would love to see the fabric pattern improved.

So for anyone looking for something like this, I wrote a bash script that uses Ollama, Fabric, attachment-downloader, and pdftotext. 

Introducing Email-to-obsidian-sync, or ETOS. 

The script checks an email for emails with a specific subject, downloads pdf attachments from that email to a temporary folder, converts that PDF to a TXT file, pipes that text file through Fabric to ollama, and saves the reply from ollama/fabric to a locally mounted obsidian directory. I am not an expert programmer but it seems to work. See instructions below:

These instructions do not cover installing a custom pattern for fabric, there are tutorials out there for how to do this. My pattern is in the write_code folder. The fabric documentation is great so I recommend studying that.
https://github.com/danielmiessler/fabric/blob/main/README.md#create-your-own-fabric-mill

Basic concept:
1. Use attachment downloader to get pdf from email
2. Use pdftotext(part of poppler-utils) to convert pdf to text
3. Pipe text into fabric saving to obsidian directory

In the below steps you must replace:
```
<EMAIL_SMTP_HOST> - The smtp server of your email host
<EMAIL_ADDRESS> - The email used for logging in to that email host
<EMAIL_PASSWORD> - Tha password used for logging into the email
<EMAIL_FOLDER> - The folder where we want to download messages on the email server most likely Inbox
<EMAIL_OUTPUT_LOCATION> - The local directory where we want to save the downloaded PDF file
<EMAIL_SUBJECT_FILTER> - The filter that will be at the beginning of the subject of every email we want to download PDF files from, I used etos
<PDF_DOWNLOADED> - This is only used during setup to verify that attachment-downloader and pdftotext are installed and working before running the script
<REMOTE_OLLAMA_SERVER> - This is only needed if you are using a remote ollama server, if ollama is running on localhost remove the tag along with the configuration option in the script. I.E. remove everything after write_code and before | " --remoteOllamaServer <REMOTE_OLLAMA_SERVER>"
```

Make sure to add your custom pattern, I have added my pattern as write_code, if you name your pattern something else make sure to replace write_code in the below script

Actual Steps
1. Update and Upgrade ubuntu
```bash
sudo apt update && sudo apt upgrade -y
```
2. Install needed packages
```bash
sudo apt install wget curl git nano ufw pip pipx poppler-utils ffmpeg cron
```
3. Install attachment-downloader
```bash
pipx install attachment-downloader
```
4. Ensure pipx path
```bash
pipx ensurepath
```
5. Copy attachment downloader bin to $PATH
```bash
cp /root/.local/share/pipx/venvs/attachment-downloader/bin/attachment-downloader /usr/local/sbin/attachment-downloader
```
6. Setup email account where files will be sent
7. Test attachment-downloader works
```bash
attachment-downloader --host <EMAIL_SMTP_HOST> --username <EMAIL_ADDRESS> --password <EMAIL_PASSWORD> --imap-folder <EMAIL_FOLDER> --output <EMAIL_OUTPUT_LOCATION> --delete --subject-regex=<EMAIL_SUBJECT_FILTER>
```
8. Test pdftotext and open the generated text file(placed next to the PDF by default)
```bash
pdftotext <PDF_DOWNLOADED>
```
9. Copy fabric repository
```bash
git clone https://github.com/danielmiessler/fabric.git
```
10. Change into fabric directory
```bash
cd ./fabric
```
11. Install fabric
```bash
pipx install .
```
12.  Ensure pipx path
```bash
pipx ensurepath
```
13. Run fabric setup
```bash
fabric --setup
```
15. Reload your shell
```bash
source ~/.bashrc
```
15. Test if fabric installed properly by running
```bash
fabric --help
```
16. Download file from email server
```bash
attachment-downloader --host <SMTP_HOST> --username <EMAIL_ADDRESS> --password <EMAIL_PASSWORD> --imap-folder <EMAIL_FOLDER> --output <EMAIL_OUTPUT_LOCATION> --delete --subject-regex=<EMAIL_SUBJECT_FILTER> --filename-template="{{date.strftime('%Y-%m-%d')}} - {{ subject }}.pdf"
```
17. Convert pdf to text
```bash
pdftotext '<EMAIL_OUTPUT_LOCATION>.pdf'
```
18. Test if we can use fabric to call ollama
```bash
cat '<EMAIL_OUTPUT_LOCATION>.pdf' | fabric --model llama3:latest --pattern write_code --remoteOllamaServer <REMOTE_OLLAMA_SERVER> | save NewTo-Do
```
19. Setup the smb mount for obsidian folder, there are tons of tutorials out there for how to mount a SMB share, at the end of the day the files from this directory just need to go to your obsidian library, you can do that with Syncthing, an SMB share, or your choice of getting it there.
20. Create a bash script to perform tasks
```bash
mkdir /opt/etos
mkdir /opt/etos/tmp
touch /var/log/etos.log
nano /opt/etos/etos.sh
```

```bash
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

```
21. Make script executable
```bash
chmod +x /opt/etos/etos.sh
```
22. Schedule a crontask to pull emails, pipe into fabric and save to obsidian folder
```bash
crontab -e
```

```bash
0 * * * * /usr/bin/bash /opt/etos/etos.sh
15 * * * * /usr/bin/bash /opt/etos/etos.sh
30 * * * * /usr/bin/bash /opt/etos/etos.sh
45 * * * * /usr/bin/bash /opt/etos/etos.sh
```
