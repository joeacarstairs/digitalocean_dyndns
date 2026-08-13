# digitalocean_dyndns

Moved! See: https://git.joeac.net/digitalocean_dyndns.git

Forked from [dc25/digitalocean_dyndns](https://github.com/dc25/digitalocean_dyndns).

This script automatically keeps your DNS records for a HTTPS website working
when you're hosting from a network with a dynamically allocated IP address, such
as a typical home network.

To use this script, first mark the shell files as runnable:

```sh
chmod +x ./dyndns.sh
chmod +x ./get_ip_addr.sh
```

Then to set things up, first write your domain name, e.g. `example.com`, to
`DIGITALOCEAN_DOMAIN`. Secondly, go to your DigitalOcean account and generate a
Personal Access Token with scopes for creating, reading, and deleting domains.
Write this to `DIGITALOCEAN_TOKEN`.

The script should now run. Try it out:

```sh
./dyndns.sh 4 # for IPv$
./dyndns.sh 6 # for IPv$
```

Go to the control panel in DigitalOcean for your domain, and check the A and
AAAA records are what you expect. If they are, the next step is to get this
script to run regularly.

You could do this in a number of ways. Probably the easiest is with crontab.
Run `crontab -e` to open your crontab for editing, and add these two lines:

```cron
* *  * * *   /home/.../dyndns.sh 4 > /tmp/dyndns.sh.4.log 2>&1
* *  * * *   /home/.../dyndns.sh 6 > /tmp/dyndns.sh.6.log 2>&1
```

Wait one minute, and check the logs. If you want to see that it works, delete
the REPEAT_CHECK_A and REPEAT_CHECK_AAAA files and wait for the script to run
again. You may also want to have an MTA set up, as cron will try to send any
unhandled output to your inbox.

If you want to use this script for more than one domain, you can supply a domain
name as a second argument. For example:

```sh
./dyndns.sh 4 example.com
```
