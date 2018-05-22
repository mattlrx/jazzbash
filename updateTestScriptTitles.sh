#!/bin/sh

#*******************************************************************************
#  Instructions:
#  To use this script you must have CURL installed on you client system.
#  The CURL local variable should be set to the location of the curl
#  executable if curl is not on your path.
#
#  On AIX, the ksh93 shell should be used.  It can be found in /usr/bin.  
#  You must run this script by specifying ksh93 ...normal command line... 
#*******************************************************************************

CURL=curl
INT_SVC="/secure/service/com.ibm.rqm.integration.service.IIntegrationService"
COOKIE_JAR="/tmp/curl.cookie.jar.$$.txt"
#PARSE_FILE="/tmp/rqm_settings.$$.txt"
LOG_FILE="/tmp/rqm_settings.$$.log"
DEFAULT_CONTEXT="qm"
S_USER="MYUSERNAME"
S_PASSWORD="MYPASSWORD"

#root uri for example: https://myserver.test.com:9443/
S_SERVER="https://myserver.test.com:9443/"
PROJECTALIAS="PROJECT"

#to scope for a given project, remove the project alias to apply to the whole repository
#for example: /service/com.ibm.rqm.integration.service.IIntegrationService/resources/testscript
FEED="/service/com.ibm.rqm.integration.service.IIntegrationService/resources/${PROJECTALIAS}/testscript"
FILENAME="testscript"

#when script completes, cookies and log file are removed.
ExitRmFiles()
{
    EXIT_CODE=$?
    rm -f $COOKIE_JAR
    #rm -f $SETTINGS_FILE
    rm -f $LOG_FILE
    exit $EXIT_CODE
}

ExitKeepFiles()
{
    EXIT_CODE=$?
    exit $EXIT_CODE
}



S_SERVER="$S_SERVER$DEFAULT_CONTEXT"
URLFEED="${S_SERVER}${FEED}"

##############  Form login to source server
touch $COOKIE_JAR
chmod og-rwx $COOKIE_JAR

$CURL -k --cookie-jar $COOKIE_JAR ${S_SERVER}${INT_SVC}
if [ $? != 0 ]; then
	echo "connecting to source server failed"
	ExitKeepFiles
fi

JSESSIONID=`cat $COOKIE_JAR | grep -P -o "JSESSIONID[\t](.*?)[\n]" | grep -P -o "[\t](.*?)[\n]" | grep -P -o "[A-Z0-9]+"`
CSRF_HEADER="$CSRF_HEADER_ID: $JSESSIONID"

$CURL -k --location --cookie $COOKIE_JAR --cookie-jar $COOKIE_JAR -D headerLogin.txt --data j_username=${S_USER} --data j_password=${S_PASSWORD} ${S_SERVER}/j_security_check >/${LOG_FILE}
if [ $? != 0 ]; then
	echo "login to source server failed"
	ExitKeepFiles
fi

echo "login to source server succeeded"



# run though the test script feed, 
# get the url for each test script, 
# get the xml representation of the test script through the REST API, 
# update the title, 
# upload the xml
# iterate through all pages in the feed.

CONTINUE=true
COUNT=0

while ${CONTINUE}
do
	RES=$($CURL -k --request GET --cookie $COOKIE_JAR  --user $USER:$PASSWORD --header "accept:text/xml" "$URLFEED")

	URLLIST=$(echo -e $RES | grep -o '<\/summary><link href=\"[^\"]\+')
    re="<\/summary><link href=\"([^\"]+)"

	while read -r line
	do	
		if [[ $line =~ $re ]]
			then URL=${BASH_REMATCH[1]}
			echo $URL

            #perform a HTTP GET on the testscript URL and save the response xml to a variable.		
			ARTIFACTXML=$($CURL -k --request GET --cookie $COOKIE_JAR  --user $USER:$PASSWORD --header "accept:text/xml" "$URL")
			
            #take the response, search for the string "ns3:title>" and replace it with "ns3:title>PREFIX_"
            ARTIFACTXML=${ARTIFACTXML//ns3:title>PREFIX_/ns3:title>}
            
            #perform a HTTP PUT to update the test script with the modified XML
			$CURL -k --request PUT --cookie $COOKIE_JAR  --user $USER:$PASSWORD --data "$ARTIFACTXML" "$URL"
		fi
	done <<< "$URLLIST" 

    #if the testscript feed contains multiple pages, get the url for the next page and loop. otherwise exit.
	HASNEXT=$(echo -e $RES | grep -o 'rel=\"next\" href=\"[^\"]\+')
	echo $HASNEXT
	reg='rel=\"next\" href=\"([^\";]+)(amp;)([^\"]+)'
	if [[ $RES =~ $reg ]]
		then URLFEED=${BASH_REMATCH[1]}${BASH_REMATCH[3]}
		echo "############################\n\nnext url was found\n\n###########################"
	else
		CONTINUE=false	
		echo "false has been set"
	fi
done

ExitRmFiles
