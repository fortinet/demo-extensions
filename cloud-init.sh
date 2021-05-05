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
echo ==========================================================
echo sudo apt-get install python3-pip --yes
sudo apt-get install python3-pip --yes
echo pip3 install boto3
pip3 install boto3
echo wget 'https://inspector-agent.amazonaws.com/linux/latest/install' -P /tmp/  --tries=20
wget 'https://inspector-agent.amazonaws.com/linux/latest/install' -P /tmp/  --tries=20
echo sudo bash /tmp/install
sudo bash /tmp/install
echo sudo apt-get install python3-pip --yes
sudo apt-get install python3-pip --yes
echo pip3 install boto3
pip3 install boto3
echo sudo apt-get install awscli --yes
sudo apt-get install awscli --yes
echo pip3 install --upgrade awscli
pip3 install --upgrade awscli
echo aws s3 --region "${region}" cp "${s3_url}" /tmp/
aws s3 --region "${region}" cp "${s3_url}" /tmp/
echo sudo python3 /tmp/runInspectsor.py
sudo python3 /tmp/runInspectsor.py
#Add the FortiGate as a route to show inspector CVE data in topology.
echo sudo route add default gw "${private_ip}" eth0
sudo route add default gw "${private_ip}" eth0
ping 8.8.8.8
EOF