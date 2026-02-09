#!/bin/sh

# Work with DigitalOcean api to update "A" and "AAAA" records for a domain.
# Store DigitalOcean API token in file : DIGITALOCEAN_TOKEN 
# Store domain to be updated in file : DIGITALOCEAN_DOMAIN 

ip_version="$1"
if [ -z "${ip_version:-}" ] || ([ "$ip_version" != 4 ] && [ "$ip_version" != 6 ]); then
    echo "Error: no valid IP version provided" >&2
    echo "Usage: dyndns.bash <4|6> [domain]" >&2
    exit 1
fi

SCRIPT="$0"
SCRIPT_DIR=$(cd "${SCRIPT%/*}" && pwd )
SCRIPT_NAME=${SCRIPT##*/}

IP="$($SCRIPT_DIR/get_ip_addr.sh $ip_version)"
if [ -z "$IP" ]; then
    echo "Error: could not find IP address" >&2
    exit 1
fi

REPEAT_CHECK_DIR=$SCRIPT_DIR
REPEAT_CHECK_A=$REPEAT_CHECK_DIR/REPEAT_CHECK_A
REPEAT_CHECK_AAAA=$REPEAT_CHECK_DIR/REPEAT_CHECK_AAAA
REPEAT_CHECK="$([ $ip_version = 4 ] && echo $REPEAT_CHECK_A || echo $REPEAT_CHECK_AAAA)"

DIGITALOCEAN_DOMAIN=${2:-`cat $SCRIPT_DIR/DIGITALOCEAN_DOMAIN`}
DIGITALOCEAN_TOKEN=`cat $SCRIPT_DIR/DIGITALOCEAN_TOKEN`

get_a_record_ids() {
    curl -X GET \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
      "https://api.digitalocean.com/v2/domains/$DIGITALOCEAN_DOMAIN/records" 2> /dev/null | jq '.domain_records |  map(select(.type == "A" and .name == "@")) | map(.id) | .[]'
}

get_aaaa_record_ids() {
    curl -X GET \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
      "https://api.digitalocean.com/v2/domains/$DIGITALOCEAN_DOMAIN/records" 2> /dev/null | jq '.domain_records |  map(select(.type == "AAAA" and .name == "@")) | map(.id) | .[]'
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

add_aaaa_record() {
    curl -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
      -d "{\"type\":\"AAAA\"         \
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
    echo deleting existing A/AAAA record for $DIGITALOCEAN_DOMAIN
    curl -X DELETE \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
      "https://api.digitalocean.com/v2/domains/$DIGITALOCEAN_DOMAIN/records/$1" > /dev/null 2>&1
}

replace_a_records() {
    for id in `get_a_record_ids`; do
        delete_record_by_id $id
    done

    new_record_id=`add_a_record`
    if [ "$new_record_id" = "null" ] ; then
        echo unable to add new A record for $DIGITALOCEAN_DOMAIN with value: $IP
        return 1
    fi
    echo added new A record for $DIGITALOCEAN_DOMAIN with value: $IP
}


replace_aaaa_records() {
    for id in `get_aaaa_record_ids`; do
        delete_record_by_id $id
    done

    new_record_id=`add_aaaa_record`
    if [ "$new_record_id" = "null" ] ; then
        echo unable to add new AAAA record for $DIGITALOCEAN_DOMAIN with value: $IP
        return 1
    fi
    echo added new AAAA record for $DIGITALOCEAN_DOMAIN with value: $IP
}

replace_records() {
    [ $ip_version = 4 ] && replace_a_records || replace_aaaa_records
}

# exit if previous successful call was with same argument
if [ -e $REPEAT_CHECK ]; then
    PREVIOUS_IP=`cat $REPEAT_CHECK`
    if [ "$IP" =  "$PREVIOUS_IP" ]; then
        echo previous update was also with argument: \"$IP\"  so exiting now to avoid duplicate work.
        exit
    fi
fi

# attempt to replace records and, if successful, save arguments to check against next time
if replace_records $IP; then
    # if successful then save arguments.
    echo update worked so saving arguments \"$IP\" in $REPEAT_CHECK
    mkdir -p $REPEAT_CHECK_DIR
    echo "$IP" > $REPEAT_CHECK
fi
