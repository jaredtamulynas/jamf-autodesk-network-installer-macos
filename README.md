# Jamf Autodesk Network License Deployment for macOS

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)](https://www.apple.com/macos)
[![Jamf Pro](https://img.shields.io/badge/Jamf%20Pro-10.0%2B-purple.svg)](https://www.jamf.com/products/jamf-pro/)

Deployment scripts for silently installing Autodesk software with network licensing via Jamf Pro on macOS. These scripts solve the common pain point of deploying Autodesk products (AutoCAD, Maya, etc.) in enterprise/education environments where network license servers are used.

## The Problem

Autodesk's macOS installers are notoriously difficult to deploy via MDM:

- No native `.pkg` format — uses custom installer apps
- Silent install options are inconsistent across versions
- Network licensing requires manual configuration post-install
- The `AdskLicensingService` must be running before license registration
- Installer apps must be staged to a temporary directory before execution

These scripts handle all of these challenges automatically.

## Supported Products

| Product | Tested Versions | Script |
|---------|-----------------|--------|
| AutoCAD | 2026 | `install-autocad-network.sh` |
| Maya    | 2026 | `install-maya-network.sh` |

## Quick Start

### Deployment Steps

#### Step 1: Package the Installer

Create a package (using Composer) that copies the Autodesk installer app to `/private/tmp/`:

```
/private/tmp/Install Autodesk AutoCAD 2026 for Mac.app
```

or for Maya:

```
/private/tmp/Install Maya 2026.app
```

#### Step 2: Upload Script to Jamf Pro

1. Navigate to **Settings → Computer Management → Scripts**
2. Click **New** and paste the appropriate script
3. Configure the parameter labels:
   - Parameter 4: `License Server (hostname or IP)`
   - Parameter 5: `Product Key (e.g., 777R1)`
   - Parameter 6: `Year (e.g., 2026)`

#### Step 3: Create the Policy

1. Create a new policy in Jamf Pro
2. Add the **package** (installer staging) as a payload
3. Add the **script** with the following parameters:
   - Parameter 4: Your license server (e.g., `license.example.com` or `27000@license.example.com`)
   - Parameter 5: Product key (see [Product Keys](#product-keys))
   - Parameter 6: Year (e.g., `2026`)
4. Set execution order: Package first, then Script
5. Scope to your target computers

## Product Keys

| Product | 2026  |
|---------|-------|
| AutoCAD | 777R1 |
| Maya    | 657R1 |

> Find your product key at [Autodesk Product Keys](https://knowledge.autodesk.com/customer-service/download-install/activate/find-serial-number-product-key/product-key-look)

## How It Works

The scripts perform the following operations in sequence:

```
┌─────────────────────────────────────────────────────────────┐
│  1. Install Licensing Package                                │
│     └─ Extracts and installs AdskLicensing*.pkg             │
├─────────────────────────────────────────────────────────────┤
│  2. Run Silent Installer                                     │
│     └─ Executes Setup.app with --silent flag                │
├─────────────────────────────────────────────────────────────┤
│  3. Start Licensing Service                                  │
│     └─ Loads AdskLicensingService LaunchDaemon              │
├─────────────────────────────────────────────────────────────┤
│  4. Create License Files                                     │
│     └─ Writes LICPATH.lic and LGS.data                      │
├─────────────────────────────────────────────────────────────┤
│  5. Register Network License                                 │
│     └─ Calls AdskLicensingInstHelper with server info       │
├─────────────────────────────────────────────────────────────┤
│  6. Verify & Cleanup                                         │
│     └─ Lists registration, removes installer app            │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Check Installation Logs

```bash
# AutoCAD
cat /var/log/autocad_install.log

# Maya
cat /var/log/maya_install.log
```

### Verify License Registration

```bash
"/Library/Application Support/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper" list
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Licensing service not running" | Service didn't start | Manually load: `launchctl load -w /Library/LaunchDaemons/com.autodesk.AdskLicensingService.plist` |
| "License registration failed" | Wrong product key or version | Verify product key matches year |
| "Setup.app not found" | Installer not staged | Ensure package caches to correct `/private/tmp/` path |
| App prompts for license | Registration didn't complete | Re-run the AdskLicensingInstHelper command manually |

### Manual License Registration

If automatic registration fails, run manually as root:

```bash
"/Library/Application Support/Autodesk/AdskLicensingService/Current/helper/AdskLicensingInstHelper" change \
    --pk "777R1" \
    --pv "2026.0.0.F" \
    --lm NETWORK \
    --ls "your-license-server.com"
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Autodesk, Inc. or Jamf. Autodesk, AutoCAD, Maya, and related marks are trademarks of Autodesk, Inc. Jamf and Jamf Pro are trademarks of Jamf Software, LLC.

---
