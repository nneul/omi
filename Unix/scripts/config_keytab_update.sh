#!/bin/sh
#
# usage: update_keytab.sh

SCRIPTNAME=$0
OMI_HOME=/opt/omi

syskeytab="/etc/krb5.keytab"
omikeytab="/etc/opt/omi/creds/omi.keytab"
ktstrip="$OMI_HOME/bin/support/ktstrip"
tmpfile=$(mktemp)

checkConfiguration()
{
    if ! crontab -l 2> /dev/null | grep -q "$ktstrip" ; then
        return 1
    fi

    return 0
}

cleanTempFile()
{
    # clean temp file
    rm -f $tmpfile > /dev/null 2>&1
}

purgeforever()
{
    # call unconfigure function
    unconfigure

    # create maker file to purge the keytab cron forever
    if [ ! -f /etc/.omi_keytabcron_purge_forever ]; then
        printf "create maker file to purge the keytab cron forever...\n"
        touch /etc/.omi_keytabcron_purge_forever
    fi
}

undopurgeforever()
{
    # just remove the maker file
    printf "undo the purgeforever and remove the maker file\n"
    rm -f /etc/.omi_keytabcron_purge_forever
}

configure()
{
    if checkConfiguration; then
       timestamp=$(date +%F\ %T)
       printf "$timestamp System already configured to run $SCRIPTNAME automatically\n"
       return 0
    fi

    # if the maker exist, then we will ignore configure
    if [ -f /etc/.omi_keytabcron_purge_forever ]; then
       printf "The maker file /etc/.omi_keytabcron_purge_forever exist, so we ignore configure keytab cron.\n"
       return 0
    fi


    which ktutil >/dev/null 2>&1

    if [ $? -eq 0 ]; then
       # prime the omi keytab
       [ -f $syskeytab ] && [ \( ! -f $omikeytab \) -o \( $syskeytab -nt $omikeytab \) ] && sleep 5 && $ktstrip $syskeytab $omikeytab >/dev/null 2>&1 || true

       crontab -l > $tmpfile 2> /dev/null || true

       # We don't worry about log rotate
       # execute the check every minute.

       echo "* * * * * [ -f $syskeytab ] && [ \( ! -f $omikeytab \) -o \( $syskeytab -nt $omikeytab \) ] && sleep 5 && $ktstrip $syskeytab $omikeytab >/dev/null 2>&1 || true" >>$tmpfile

       crontab $tmpfile

       timestamp=$(date +%F\ %T)
       printf "$timestamp : Crontab configured to update omi keytab automatically\n"
    else
       printf "ktutil not found\n"
    fi
}

unconfigure()
{
    if ! checkConfiguration; then
        timestamp=$(date +%F\ %T)
        printf "$timestamp : Crontab not configured to update omi keytab automatically. Skip unconfigure\n"
        return 0
    fi

    crontab -l > $tmpfile 2> /dev/null || true

    tmpfile2=$(mktemp)
    grep -v "$omikeytab" $tmpfile >$tmpfile2 
    crontab $tmpfile2

    # clean temp file
    rm -f $tmpfile2 > /dev/null 2>&1

    timestamp=$(date +%F\ %T)
    printf "$timestamp : Crontab no longer configured to update omi keytab.\n"
}



while [ $# -ne 0 ]
do
    case "$1" in
	--configure)
        configure
	    shift 1
	    ;;

	--unconfigure)
        unconfigure
	    shift 1
	    ;;

        --purgeforever)
        purgeforever
            shift 1
            ;;

        --undopurgeforever)
        undopurgeforever
            shift 1
            ;;

    *)
        printf "$0 unknown option\n"
        shift 1
        ;;
    esac
done

cleanTempFile
