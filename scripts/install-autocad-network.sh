#!/bin/bash

# Jamf script parameters:
# $4 = License Server
# $5 = Product Key (e.g. 777R1)
# $6 = Year (e.g. 2026)

networkServer="$4"
pKey="$5"
year="$6"

if [[ -z "$networkServer" || -z "$pKey" || -z "$year" ]]; then
  echo "ERROR: Missing required Jamf parameters." >&2
  echo "Parameter 4 = License Server" >&2
  echo "Parameter 5 = Product Key" >&2
  echo "Parameter 6 = Year" >&2
  exit 1
fi

appPath="/private/tmp/Install Autodesk AutoCAD ${year} for Mac.app"
LOG="/var/log/autocad_install.log"

echo "=== AutoCAD 2026 Installation Started: $(date) ===" >> "$LOG"

# Step 1: Install licensing package FIRST
echo "Installing Licensing Service..." >> "$LOG"
licensingPkg=$(find "$appPath/Contents/Helper/Packages/Licensing" -name "AdskLicensing*.pkg" -print -quit)
if [[ -f "$licensingPkg" ]]; then
    /usr/sbin/installer -pkg "$licensingPkg" -target / >> "$LOG" 2>&1
    echo "Licensing package installed: $licensingPkg" >> "$LOG"
else
    echo "WARNING: Licensing package not found" >> "$LOG"
fi

sleep 30

# Step 2: Run silent installer for AutoCAD
echo "Installing AutoCAD via silent installer..." >> "$LOG"
"$appPath/Contents/Helper/Setup.app/Contents/MacOS/Setup" --silent >> "$LOG" 2>&1

sleep 30

# Step 3: Ensure licensing service is running
echo "Starting Licensing Service..." >> "$LOG"
/bin/launchctl unload /Library/LaunchDaemons/com.autodesk.AdskLicensingService.plist 2>/dev/null
sleep 5
/bin/launchctl load -w /Library/LaunchDaemons/com.autodesk.AdskLicensingService.plist 2>/dev/null
sleep 15

# Step 4: Create license directory and files
licPath="/Library/Application Support/Autodesk/AdskLicensingService/${pKey}_${year}.0.0.F"
/bin/mkdir -p "$licPath"

echo "SERVER ${networkServer} 000000000000" > "$licPath/LICPATH.lic"
echo "USE_SERVER" >> "$licPath/LICPATH.lic"
echo "_NETWORK" > "$licPath/LGS.data"

echo "License files created at: $licPath" >> "$LOG"

# Step 5: Register license
echo "Registering network license..." >> "$LOG"
"/Library/Application Support/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper" change \
    --pk "$pKey" \
    --pv "${year}.0.0.F" \
    --lm NETWORK \
    --ls "$networkServer" >> "$LOG" 2>&1

# Step 6: Verify
echo "Verifying registration..." >> "$LOG"
"/Library/Application Support/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper" list >> "$LOG" 2>&1

# Cleanup
rm -rf "$appPath"

echo "=== AutoCAD 2026 Installation Complete: $(date) ===" >> "$LOG"

# Step 7: Change the owner of Autodesk folder in Users Application Support folder
# Assumes there is a console user
consoleUser="$(stat -f "%Su" /dev/console)"

if [[ "$consoleUser" != "root" ]] && id "$consoleUser" >/dev/null 2>&1; then
  /usr/sbin/chown -R "$consoleUser":staff "/Users/$consoleUser/Library/Application Support/Autodesk" 2>/dev/null
fi

exit 0