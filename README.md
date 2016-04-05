# docker-freepbx

## FreePBX Docker.io setup for astcore.bonline.com


1. Create an Ubuntu 14.04 instance on Digital Ocean (or VPS of choice) & connect via ssh

2. `sudo apt-get update && sudo apt-get install git docker.io`

3. `git clone https://github.com/torrange/pbxdocker

4. `cd pbxdocker && sudo docker build .`

5. `sudo docker run --net=host -d -t <image_build_id>`

6. Open [http://{{digital_ocean_ip}}/](http://127.0.0.1) in a browser.

7. Create admin user when prompted

8. In the FreePBX control panel,  open “Settings” => “Advanced Settings”
    1. switch “SIP Channel Driver” to ‘chan_sip’
    2. submit changes

9. In the FreePBX control panel, open `Settings` => `Asterisk SIP Settings`, change `RTP Port Ranges` to:  
    1. start=`6000`
    2. end=`40000`
    3. submit changes
    
10. In the FreePBX control panel, open `Settings` => `Asterisk SIP Settings`
    1. click the `Detect External IP` button; subnets + external IP should auto-populate
    2. submit changes

11. In the FreePBX control panel, open `Settings` =>`chan_sip` link (right panel): 
    1. change `Bind Port` to `5060`
    2. submit changes.

12. Ssh into Ubuntu instance: `ssh root@<digital_ocean_ip>` and run:
    1. `docker exec -i -t <container_id> bash`
    2. `killall asterisk`
    3. `exit`
    4. optional `astcore/scripts/./whitelist.sh`

Asterisk will now automatically restart using the chan_sip.c driver listening on port 5060. 

Before running `pbxdocker/scripts/./whitelist.sh`, add your public static IP's to `pbxdocker/scripts/./whitelist.sh`  

For example,  for a public IP of 42.24.12.34:  `echo "iptables -I INPUT -s 42.24.12.34 -j ACCEPT" >> pbxdocker/scripts/./whitelist.sh`

This will block all connecting traffic except from IP's: `42.24.12.34`.  TCP ports `80` and `22` will remain open after running this script.

These steps can be followed verbatim on [http://localhost/] (http://localhost/) running an instance of the docker.io daemon

