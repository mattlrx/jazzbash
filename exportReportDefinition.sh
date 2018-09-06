#!/bin/bash

cleanup(){
    #clean up
    rm $HEADER
    rm $COOKIE_JAR
}

USER="<userName>"
PASSWORD="<password>"

RSHOST="https://<server:port>/rs"
JTSHOST="https://<server:port>/jts"
REPORTNUMBER="<reportNumber>"
REPORTFILE="reportArchive_${REPORTNUMBER}.zip"

COOKIE_JAR="cookies.txt"
HEADER="headerLogin.txt"


# curl options:
# -b Pass the data to the HTTP server as a cookie. It is supposedly the data previously received from the server in a "Set-Cookie:" line.  
# -c Specify to which file you want curl to write all cookies after a completed operation.  
# -d Sends the specified data in a POST request to the HTTP server
# -D Write the protocol headers to the specified file.
# -i Include the HTTP-header in the output.
# -k This option explicitly allows curl to perform "insecure" SSL connections and transfers.
# -L If  the  server  reports  that  the  requested  page has moved to a different location 
# -v verbose
# -H add the specified header to the request

curl -k -L -D $HEADER -c $COOKIE_JAR "${RSHOST}/reportdefinition?action=export&selections=${REPORTNUMBER}"

# cat $HEADER : displays the content of headerLogin.txt
# grep -E "X-JSA-AUTHORIZATION-REDIRECT: (.*)" : captures the line where this pattern is recognised
# cut -d ":" -f 2,3 : cuts the line in bits using ":" as the delimiter and then extracts the 2nd and 3rd elements
# cut -c2- : extract from the 2nd character to the end of the line (the previous line started with a space)

REDIRECT_URL=$(cat $HEADER | grep -E "Location: (.*)" | cut -d ":" -f 2,3,4 | cut -c2-)

# REDIRECT_URL contains a \r (CR) at the end (0d). 
# to see the character you can run the following command: 
# printf %s "$REDIRECT_URL" | xxd
# we remove it with the following command: 
REDIRECT_URL=${REDIRECT_URL%$'\r'}

curl -k -L -D $HEADER -b $COOKIE_JAR -c $COOKIE_JAR "$REDIRECT_URL"
# since we are not interested in the output, sending it to /dev/null
# if needed to troubleshoot, remove > /dev/null and add -v for verbose output
curl -kL -b $COOKIE_JAR -c $COOKIE_JAR -d j_username=${USER} -d j_password=${PASSWORD} "${JTSHOST}/auth/j_security_check" > /dev/null

curl -kL -b $COOKIE_JAR -c $COOKIE_JAR -H "accept:application/xml" "${RSHOST}/reportdefinition?action=export&selections=${REPORTNUMBER}" --output $REPORTFILE

cleanup
