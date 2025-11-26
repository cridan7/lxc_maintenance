## Step 1
run and ./push-update-scripts-to-lxc.sh to push system distribution based upgrade script to the LXCs
upgrade script located in /opt/update/upgrade_system_release.sh"
>> check log at /opt/scripts/update/log/lxc_system_summary_log
## Step 2
run ./pull-all-lxc-update-commands to pull update command and to get /bin/update to /opt/scripts/update/bin
>> check log at /opt/scripts/update/log/lxc_pull_log
## Step 3
change the update commands and comment existing line/lines and add bash -c /opt/update/update-menu.sh >> script is missing for this
## Step 4
run ./push-update-command.sh to push new update commands to LXCs. This will also backup inside the LXC the existing /bin/update to /opte/update/backup
>> check log at /opt/scripts/update/log/lxc_push_log
## Step 5 
run ./generate-update-menus to generate the update-menu dynamically for each LXC
This is base on /opt/scripts/update/installed_services.md which is a summary of installed services in your LXCs
run ./generate_community_services to generate the installed_services.md >> file needs to manually updated and checked script is not 100% reliable
./generate_community_services is based on community_services list of CT services plus additonal addons >> process needs to be automated and made more reliable
>> check log at /opt/scripts/update/log/generate_update_menu_log
## Step 6 
run ./push-update-menu.sh to push the dynamically generated update menus into the LXCs
>> check log at /opt/scripts/update/log/generate_update_menu_log
## Step 7 
run ./push-additional-files.sh to push additional script files to the LXCs /opt/update folder
This will push clean.sh, fstrim.sh, update_system.sh
The scripts are based on community 
https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/clean-lxcs.sh
https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/fstrim.sh
https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/update-lxcs.sh
but modified to be run from inside the container not from the host
>> check log at /opt/scripts/update/log/lxc_push_log
## Step 8 
run update command inside LXC and enjoy.
either log into the lxc cli or from host use 
pct exec <CTID> update
LXC services that reside inside the container and use community scripts will pull the install script and update just like before 
LXC services that run docker will update docker service by pulling the latest container based on the docker.io tag
## Additional info 
scripts are made to run by default on all LXC from host but do accept cutom flags 
-c CTID1, CTID2 >> container specific only 
-s CTID1, CTID2 >> skip specific containers from the host pool