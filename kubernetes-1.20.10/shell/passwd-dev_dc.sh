#!/usr/bin/expect
##设置dev_dc的密码##

spawn passwd dev_dc
expect "*password:"
send "dc2016\r"
expect "*password:"
send "dc2016\r"
expect "*#"
