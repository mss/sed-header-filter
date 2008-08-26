#!/bin/bash
#
# This script can be used by cpanel to filter email headers through sed.
# Actually, it can be used by any exim pipe filter, but don't tell anybody.
#
# Usage: header-filter.sh [ -f from ] [ -t to ] [ -s path-to-sendmail ] [ filter-file ]
#
#  All sed-commands in filter-file (default: header-filter.sed) will be 
#  applied to the header lines on stdin.  Better don't alter the hold space!
#
# Options:
#  -f  the envelope sender address (default: $SENDER)
#  -t  the envelope recipient address (default: $RECIPIENT)
#  -s  path to sendmail (default: /usr/sbin/sendmail)
#
# See also:
#  http://wiki.list.org/display/DOC/From+field+displayed+by+Microsoft+Outlook
#  http://sourceforge.net/tracker/?func=detail&atid=350103&aid=1460796&group_id=103
#  http://mail.python.org/pipermail/mailman-developers/2006-April/018715.html
#  http://mail.python.org/pipermail/mailman-developers/2006-July/019040.html
#  http://www.exim.org/exim-html-4.69/doc/html/filter.html#SECTpipe
#  ~/.cpanel/filter.yaml
#  /etc/vfilter/$DOMAIN
#######################################################################

# Redirect stdout to stderr.
exec 1>&2

# Some defaults.
file="${0%.*}.sed"
from="$SENDER"
rcpt="$RECIPIENT"
send=$(which sendmail || echo /usr/sbin/sendmail)

# Get options.
while getopts ":f:t:s:h" OPTNAM; do
  case "$OPTNAM" in
    f) from=$OPTARG ;;
    t) rcpt=$OPTARG ;;
    s) send=$(which $OPTARG) ;;
    h) sed -e '/^# Usage:/,/^$/!d;s/^#*//' $0; exit ;;
  esac
done
if [ "${@:$OPTIND:1}" ]; then
  file="${@:$OPTIND:1}"
fi
if [ ! -r "$file" ]; then
  file=/dev/null
fi

# Check setup.
if [ -z "$from" -o -z "$rcpt" -o ! -x "$send" ]; then
  echo "Wrong or missing parameters."
  exit 254
fi

sendmail() {
  $send -oi -oee -oMr localhost -f "$from" "$rcpt"
  #cat -
}

# Pass stdin through the sed script below and send out the result with sendmail.
sed -f <(sed -e '0,/^#!.*sed/d' $0) -f "$file" | sendmail
exit $?

#!/bin/sed -f
# Header:
0,/^$/{
 # Continued header line:
 /^[ \t]/{
  # Append to hold space.
  H;
  # Continue with next line.
  d;
 }
 # Start of message:
 1{
  # Store first line in hold space.
  h;
  # Continue with next line.
  d;
 }
 # Swap previous line(s) out of hold space, store current.
 x;
 # Branch to filter.
 b filter;
}
# Body:
{
 # Swap hold and pattern space.
 x;
 # Print pattern space.
 p;
 # Last line:
 ${
  # Swap out.
  x;
  # Print as well.
  p;
 }
 # Stop here.
 d;
}
# Process filters:
: filter
