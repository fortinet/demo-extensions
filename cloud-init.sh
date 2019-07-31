#! /bin/bash
timeStart=`date "+%s"`
while true
    do
        responseCode=$(curl -s -o /dev/null -w "%%{http_code}" 'https://inspector-agent.amazonaws.com/linux/latest/install')
        if [ "$responseCode" = "200" ]
            then
                echo "200 response"
                break
        elif [ "$timeStart" => "$(($timeStart+300))" ]
            then
                echo "Response Timeout"
                break
        fi
done
sudo apt-get install boto --yes --force-yes
wget 'https://inspector-agent.amazonaws.com/linux/latest/install' -P /tmp/  --tries=20
sudo bash /tmp/install
sudo apt-get install python-pip --yes --force-yes
sudo pip install boto3
sudo pip install awscli
wget `aws --region "${region}" s3  presign "${s3_url}"` -O /tmp/runInspector.py
sudo python /tmp/runInspector.py
#Add the FortiGate as a route to show inspector CVE data in topology.
sudo route add default gw "${private_ip}" eth0
ping 8.8.8.8
EOF