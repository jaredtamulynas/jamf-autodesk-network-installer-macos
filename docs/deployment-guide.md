# Detailed Deployment Guide

This guide walks through the complete process of deploying Autodesk software with network licensing via Jamf Pro.

## Table of Contents

1. [Overview](#overview)
2. [Prepare the Installer Package](#prepare-the-installer-package)
3. [Upload to Jamf Pro](#upload-to-jamf-pro)
4. [Create the Policy](#create-the-policy)
5. [Testing](#testing)
6. [Troubleshooting](#troubleshooting)

---

## Overview

Deploying Autodesk software on macOS via MDM involves three main components:

1. **The Installer App** - Downloaded from Autodesk, needs to be repackaged
2. **The Installation Script** - Handles silent installation and license configuration
3. **The Jamf Policy** - Orchestrates the deployment

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Jamf Pro Server                          │
│  ┌─────────────────┐     ┌─────────────────────────────────┐    │
│  │  Package (PKG)  │     │  Script + Parameters            │    │
│  │  Stages         │     │  • License Server               │    │
│  │  installer to   │     │  • Product Key                  │    │
│  │  /private/tmp/  │     │  • Year                         │    │
│  └────────┬────────┘     └────────────────┬────────────────┘    │
│           │                               │                     │
│           └───────────────┬───────────────┘                     │
│                           ▼                                     │
│                    ┌─────────────┐                              │
│                    │   Policy    │                              │
│                    └──────┬──────┘                              │
└───────────────────────────┼─────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────┐
│                       Target Mac                              │
│                                                               │
│  1. Package runs → Installer.app copied to /private/tmp/      │
│  2. Script runs → Silent install + license configuration      │
│  3. Cleanup → Installer.app removed                           │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

## Prepare the Installer Package

### Step 1: Download the Installer

1. Log in to [Autodesk Account](https://manage.autodesk.com/)
2. Navigate to **Products & Services** → **All Products & Services**
3. Find your product and click **Download**
4. Download the macOS installer (DMG format)

### Step 2: Mount and Locate the Installer App

```bash
# Mount the DMG
hdiutil attach ~/Downloads/Autodesk_AutoCAD_2026_macOS.dmg

# The installer app will be at:
# /Volumes/Install Autodesk AutoCAD 2026/Install Autodesk AutoCAD 2026 for Mac.app
```

### Step 3: Create the Package

1. Open Composer
2. Choose **Monitor Installation** or **Quick Add Package**
3. Drag the installer app to the package
4. Set the destination to `/private/tmp/`
5. Build the package


#### Option C: munkipkg

Create a munkipkg project:

```bash
munkipkg --create AutoCAD2026-Installer

# Add the installer app to:
# AutoCAD2026-Installer/payload/private/tmp/Install Autodesk AutoCAD 2026 for Mac.app

munkipkg AutoCAD2026-Installer
```

### Important Notes

- The installer app is large (typically 2-5 GB)
- `/private/tmp/` is cleared on reboot, which is ideal for cleanup
- Ensure the app name matches what the script expects

---

## Upload to Jamf Pro

### Upload the Package

1. Navigate to **Settings** → **Computer Management** → **Packages**
2. Click **New**
3. Upload your package
4. Configure settings:
   - **Display Name:** `AutoCAD 2026 Installer`
   - **Category:** Software Installers (or your preferred category)
   - **Priority:** 10 (or appropriate for your environment)

### Upload the Script

1. Navigate to **Settings** → **Computer Management** → **Scripts**
2. Click **New**
3. Configure the script:
   - **Display Name:** `Install AutoCAD - Network License`
   - **Category:** Installers
4. Paste the script content
5. Configure **Options** tab:
   - Parameter 4 Label: `License Server`
   - Parameter 5 Label: `Product Key`
   - Parameter 6 Label: `Year`

---

## Create the Policy

### Basic Policy Configuration

1. Navigate to **Computers** → **Policies** → **New**
2. Configure **General**:
   - **Display Name:** `Install AutoCAD 2026`
   - **Enabled:** Yes
   - **Trigger:** (choose based on your workflow)
   - **Execution Frequency:** Once per computer

### Add Package Payload

1. Click **Packages** in the left sidebar
2. Click **Configure**
3. Add your installer package
4. Set **Action:** Install

### Add Script

1. Click **Scripts** in the left sidebar
2. Click **Configure**
3. Add your installation script
4. Set **Priority:** After (to run after the package)
5. Configure parameters:
   - **Parameter 4:** `license.yourcompany.com` (your license server)
   - **Parameter 5:** `777R1` (product key for AutoCAD 2026)
   - **Parameter 6:** `2026`

### Configure Scope

1. Click **Scope** in the left sidebar
2. Add target computers or groups
3. Consider using a test group first

### Self Service (Optional)

1. Click **Self Service** in the left sidebar
2. Enable **Make the policy available in Self Service**
3. Configure button text and description
4. Add an icon (Autodesk logo or custom)

---

## Testing

### Test Machine Preparation

1. Ensure the test Mac has network access to your license server
2. Remove any existing Autodesk installations
3. Enable verbose logging if needed

### Run the Policy

1. On the test Mac, run:
   ```bash
   sudo jamf policy -event <your-trigger>
   ```
   Or use Self Service

2. Monitor the installation:
   ```bash
   tail -f /var/log/autocad_install.log
   ```

### Verify Installation

1. Check the application installed:
   ```bash
   ls -la "/Applications/Autodesk/AutoCAD 2026"
   ```

2. Verify license registration:
   ```bash
   "/Library/Application Support/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper" list
   ```

3. Launch the application and verify it connects to the license server

---

## Troubleshooting

### Script Didn't Run

Check the Jamf Pro logs:
1. **Computers** → [select computer] → **History** → **Policy Logs**
2. Look for errors in the script execution

### Installer Not Found

The script couldn't find the installer app at the expected path.

**Solutions:**
- Verify the package copies to `/private/tmp/`
- Check the installer app name matches the script's `appPath` variable
- Ensure the package ran before the script

### License Registration Failed

The application installed but prompts for license information.

**Check:**
1. Is the licensing service running?
   ```bash
   launchctl list | grep autodesk
   ```

2. Can you reach the license server?
   ```bash
   nc -zv license.yourcompany.com 27000
   ```

3. Is the product key correct for the year?

**Manual fix:**
```bash
"/Library/Application Support/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper" change \
    --pk "777R1" \
    --pv "2026.0.0.F" \
    --lm NETWORK \
    --ls "license.yourcompany.com"
```

### Permission Issues

If the application works for admin users but not standard users:

1. Check Application Support folder ownership:
   ```bash
   ls -la "/Users/username/Library/Application Support/Autodesk"
   ```

2. The script should fix this automatically, but you can manually run:
   ```bash
   chown -R username:staff "/Users/username/Library/Application Support/Autodesk"
   ```

