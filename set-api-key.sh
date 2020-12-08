spawn ssh admin@${fortigate_Ip}
expect "? "
send "yes\r"
expect "# "

send "execute api-user generate-key root \r"
expect "New API key:"
