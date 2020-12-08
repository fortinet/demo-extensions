 #!/bin/bash
curldata=`curl https://ifconfig.co/`
echo "{\"ipAddress\":\"${curldata}\"}"