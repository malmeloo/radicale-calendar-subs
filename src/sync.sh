#!/bin/bash

echo "----"

CONF_DIR="/config"
WEBDAV_PATCH='
<?xml version="1.0" encoding="UTF-8" ?>
<propertyupdate
	xmlns="DAV:"
	xmlns:C="urn:ietf:params:xml:ns:caldav"
	xmlns:CR="urn:ietf:params:xml:ns:carddav"
	xmlns:CS="http://calendarserver.org/ns/"
	xmlns:I="http://apple.com/ns/ical/"
	xmlns:INF="http://inf-it.com/ns/ab/">
	<set>
		<prop>
			<C:supported-calendar-component-set>
				<C:comp name="VEVENT" />
				<C:comp name="VJOURNAL" />
				<C:comp name="VTODO" />
			</C:supported-calendar-component-set>
			<displayname>DISP_NAME</displayname>
			<C:calendar-description>DESCRIPTION</C:calendar-description>
		</prop>
	</set>
	<remove>
		<prop>
			<INF:addressbook-color />
			<CR:addressbook-description />
		</prop>
	</remove>
</propertyupdate>
'

if [ ! -f "$CONF_DIR/config.txt" ]; then
  echo "No config file found at $CONF_DIR/config.txt!"
  exit 1
elif [ -z "$RADICALE_URL" ]; then
  echo "RADICALE_URL not set!"
  exit 1
fi


config=$(cat "$CONF_DIR/config.txt")

while IFS=, read -r usrname calhref calname calurl; do
    echo
    echo "Checking calendar '$calname' for user '$usrname'"

    cal_data=$(curl -s "$calurl")
    if [ "$?" -ne 0 ]; then
      echo "  Skipping update: curl error"
      continue;
    fi

    usr_dir="$CONF_DIR/cache/$usrname"
    cal_path="$usr_dir/$calname"
    hash=$(echo "$cal_data" | sha256sum | awk '{ print $1 }')
    if [ -f "$cal_path" ] && [ "$(cat "$cal_path")" = "$hash" ]; then
      echo "  Skipping update: no changes detected"
      continue
    fi

    usrpass_var="RADICALE_PASS_$usrname"
    usrpass="${!usrpass_var}"
    if [ -z "$usrpass" ]; then
      echo "  Skipping update: no password specified for user '$usrname'"
      continue
    fi

    echo "  Uploading calendar"
    curl -s --fail -X PUT -u "$usrname:$usrpass" "$RADICALE_URL/$usrname/$calhref" --data-binary "$cal_data"
    if [ "$?" -ne 0 ]; then
      echo "  Error while updating calendar"
      continue;
    fi

    echo "  Updating calendar details"
    description="Last sync at $(date)"
    payload=$(echo "$WEBDAV_PATCH" | tr -d '\n' | sed "s|DISP_NAME|$calname|" | sed "s|DESCRIPTION|$description|")
    curl -s --fail -X PROPPATCH -u "$usrname:$usrpass" "$RADICALE_URL/$usrname/$calhref" --data-binary "$payload" >/dev/null
    if [ "$?" -ne 0 ]; then
      echo "  Error while updating calendar details"
      continue;
    fi

    echo "  Success!"

    mkdir -p "$usr_dir"
    echo "$hash" > "$cal_path"
done <<< "$config"

echo "----"
