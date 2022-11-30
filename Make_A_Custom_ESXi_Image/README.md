# PowerCLI
# VMware PowerCLI Scripts Created by Russell Hamker
## These Scripts allow you to generate a Custom ESXi Depot/ISO based on a Vendor's Depot + updates from VMware, + updates from the Vendor + removal of unused VIBs from the Depot/Image

## Steps:
### 1.Download my PowerCLI utility to automate this process
### 2.Download the VMware ESXi Vendor Bundle
### 3.Verify what the current build of ESXi is
### 4.Download updated VMware Tools.
### 5.Download ESXi Patches
### 6.Reference your Hardware Vendor’s support Matrix
### 7.Download updated VMware hardware drivers per your vendor’s Matrix
### 8.Run the PowerCLI Script and follow the instructions

## Validate Prior to First use
### Use the Validate_VMware_PowerCLI_and_Python_Before_First_Use.ps1 script to validate that PowerCLI and Python have been installed and configured correctly