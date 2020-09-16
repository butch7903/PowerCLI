# PowerCLI
# VMware PowerCLI Scripts Created by Russell Hamker
## These Scripts allow you create a VMware Host Profile, enforce good configuration best practices, and apply the Modified Host Profile to the cluster of the VMHost. Script is 100% automated. Simply run it, answer the questions, and it will generate a Host Profile from a Host of your choosing. Script will then modify the Host Profile based on your best practices (in memory), save the updated config back to the original Host Profile, after this it will apply this Host Profile to the Parent Cluster of the Host you exported the Host Profile from.
## After this is completed, the script will also backup the Host Profile to a file so you can then use as a restore option should a Host Profile get changed or corrupted in some way.
