#! /bin/bash  

# Work with DigitalOcean api to update "A" record for a domain.
# Store DigitalOcean API token in file : DIGITALOCEAN_TOKEN 
# Store domain to be updated in file : DIGITALOCEAN_DOMAIN 

SCRIPT="${BASH_SOURCE[0]}"
SCRIPT_DIR=$(builtin cd "${SCRIPT%/*}" && pwd )
SCRIPT_NAME=${SCRIPT##*/}

REPEAT_CHECK_DIR=$SCRIPT_DIR
REPEAT_CHECK=$REPEAT_CHECK_DIR/REPEAT_CHECK # file to save argument in if successful

DIGITALOCEAN_DOMAIN=`cat $SCRIPT_DIR/DIGITALOCEAN_DOMAIN`
DIGITALOCEAN_TOKEN=`cat $SCRIPT_DIR/DIGITALOCEAN_TOKEN`

# Get IP from command line if available.  Otherwise use curl to get public IP.
IP=""
if [ "$#" == "1" ]; then
    IP=$1
else
    IP=`curl -4 icanhazip.com 2> /dev/null`
fi

# If $IP does not look like a valid address then complain and exit.
# For regular expression, thank you to : https://tecadmin.net/shell-script-validate-ipv4-addresses/
if ! [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo Invalid IP address format: $IP
    exit
fi

get_a_record_ids() {
    curl -X GET \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
      "https://api.digitalocean.com/v2/domains/$DIGITALOCEAN_DOMAIN/records" 2> /dev/null | jq '.domain_records |  map(select(.type == "A" and .name == "@")) | map(.id) | .[]'
}

add_a_record() {
    curl -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
      -d "{\"type\":\"A\"         \
          ,\"name\":\"@\"         \
          ,\"data\":\"$IP\"       \
          ,\"priority\":null      \
          ,\"port\":null          \
          ,\"ttl\":1800           \
          ,\"weight\":null        \
          ,\"flags\":null         \
          ,\"tag\":null           \
          }"                      \
      "https://api.digitalocean.com/v2/domains/$DIGITALOCEAN_DOMAIN/records" 2> /dev/null | jq '.domain_record.id'
}

delete_record_by_id() {
    echo deleting existing A record for $DIGITALOCEAN_DOMAIN
    curl -X DELETE \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
      "https://api.digitalocean.com/v2/domains/$DIGITALOCEAN_DOMAIN/records/$1" > /dev/null 2>&1
}

replace_a_record() {
    for id in `get_a_record_ids`; do
        delete_record_by_id $id
    done

    new_record_id=`add_a_record`
    if [ "$new_record_id" == "null" ] ; then
        echo unable to add new A record for $DIGITALOCEAN_DOMAIN with value : $1
        return 1
    fi
    echo added new A record for $DIGITALOCEAN_DOMAIN with value : $1
}


# exit if previous successful call was with same argument
if [[ -e $REPEAT_CHECK ]]; then
    PREVIOUS_IP=`cat $REPEAT_CHECK`
    if [[ "$IP" ==  "$PREVIOUS_IP" ]]; then
        echo previous update was also with argument: \"$IP\"  so exiting now to avoid duplicate work.
        exit
    fi
fi

# attempt to replace A record and, if successful, save arguments to check against next time
if replace_a_record $IP; then
    # if successful then save arguments.
    echo update worked so saving arguments \"$IP\" in $REPEAT_CHECK
    mkdir -p $REPEAT_CHECK_DIR
    echo "$IP" > $REPEAT_CHECK
fi
