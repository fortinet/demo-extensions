 #!/bin/bash
curldata=`curl -s ifconfig.co | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'`
echo "{\"ipAddress\":\"${curldata}\"}"