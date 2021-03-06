#!/bin/bash

ckan_log () {
    echo "ckan: " $1
}

ckan_set_log_file_permissions () {
    local INSTANCE
    INSTANCE=$1
    chown apache:ckan${INSTANCE} /var/log/ckan/${INSTANCE}
    chmod g+w /var/log/ckan/${INSTANCE}
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}1.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}2.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}3.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}4.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}5.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}6.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}7.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}8.log
    touch /var/log/ckan/${INSTANCE}/${INSTANCE}9.log
    chmod g+w /var/log/ckan/${INSTANCE}/${INSTANCE}*.log
    chown apache:ckan${INSTANCE} /var/log/ckan/${INSTANCE}/${INSTANCE}*.log
}

ckan_ensure_users_and_groups () {
    local INSTANCE CKAN_USER
    INSTANCE=$1
    CKAN_USER=$2

    if [ "X$1" = "X" ] || [ "X$2" = "X" ] ; then
      echo "ERROR: call the ckan_ensure_users_and_groups function with and instance and a user name, e.g."
      echo "  std ecportal"
      exit 1
    fi

    COMMAND_OUTPUT=`cat /etc/group | grep "ckan${INSTANCE}:"`
    if ! [[ "$COMMAND_OUTPUT" =~ "ckan${INSTANCE}:" ]] ; then
        echo "Creating the 'ckan${INSTANCE}' group ..." 
        groupadd --system "ckan${INSTANCE}"
        echo "Adding the $CKAN_USER user to it..."
        usermod --append --groups "ckan${INSTANCE}" $CKAN_USER
    fi
    COMMAND_OUTPUT=`cat /etc/passwd | grep "ckan${INSTANCE}:"`
    if ! [[ "$COMMAND_OUTPUT" =~ "ckan${INSTANCE}:" ]] ; then
        echo "Creating the 'ckan${INSTANCE}' user ..." 
        useradd --system  --gid "ckan${INSTANCE}" --home $CKAN_LIB/${INSTANCE} -M  --shell /usr/sbin/nologin ckan${INSTANCE}
    fi
}

ckan_make_ckan_directories () {
    local INSTANCE
    if [ "X$1" = "X" ] ; then
        echo "ERROR: call the function make_ckan_directories with an INSTANCE name, e.g." 
        echo "       std"
        exit 1
    else
        INSTANCE=$1
        mkdir -p -m 0755 $CKAN_ETC/${INSTANCE}
        mkdir -p -m 0750 $CKAN_LIB/${INSTANCE}{,/static}
        mkdir -p -m 0770 /var/{backup,log}/ckan/${INSTANCE} $CKAN_LIB/${INSTANCE}/{data,sstore,static/dump}
        chown ckan${INSTANCE}:ckan${INSTANCE} $CKAN_ETC/${INSTANCE}
        chown apache:ckan${INSTANCE} /var/{backup,log}/ckan/${INSTANCE} $CKAN_LIB/${INSTANCE} $CKAN_LIB/${INSTANCE}/{data,sstore,static/dump}
        chmod g+w /var/log/ckan/${INSTANCE} $CKAN_LIB/${INSTANCE}/{data,sstore,static/dump}
    fi
}

ckan_create_who_ini () {
    local INSTANCE
    if [ "X$1" = "X" ] ; then
        echo "ERROR: call the function create_who_ini function with an INSTANCE name, e.g." 
        echo "       std"
        exit 1
    else
        INSTANCE=$1
        local PYENV=$CKAN_LIB/${INSTANCE}/pyenv
        local AUTH_TKT_SECRET=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10`
        if ! [ -f $CKAN_ETC/${INSTANCE}/who.ini ] ; then
            cp -n $PYENV/src/ckan/ckan/config/who.ini $CKAN_ETC/${INSTANCE}/who.ini
            sed -e "s,%(here)s,$CKAN_LIB/${INSTANCE}," \
                -e "s/^secret = somesecret/secret = $AUTH_TKT_SECRET/" \
                -i $CKAN_ETC/${INSTANCE}/who.ini

            # Set permissions and ownership so that only members of the
            # ${INSTANCE} group can read the who.ini file.
            chown ckan${INSTANCE}:ckan${INSTANCE} $CKAN_ETC/${INSTANCE}/who.ini
            chmod 640 "$CKAN_ETC/${INSTANCE}/who.ini"
        fi
    fi
}

ckan_create_config_file () {
    local INSTANCE password LOCAL_DB
    if [ "X$1" = "X" ] || [ "X$2" = "X" ] ; then
        echo "ERROR: call the function create_config_file function with an INSTANCE name, and a password for postgresql e.g."
        echo " std 1U923hjkh8"
        exit 1
    else
        INSTANCE=$1
        password=$2
        LOCAL_DB=$3
        # Create an install settings file if it doesn't exist
        if [ -f $CKAN_ETC/${INSTANCE}/${INSTANCE}.ini ] ; then
            mv $CKAN_ETC/${INSTANCE}/${INSTANCE}.ini "$CKAN_ETC/${INSTANCE}/${INSTANCE}.ini.`date +%F_%T`.bak"
        fi
        echo "Paster Used: `which paster`"
        paster make-config ckan $CKAN_ETC/${INSTANCE}/${INSTANCE}.ini

        if [[ ( "$LOCAL_DB" == "yes" ) ]]
        then
            sed -e "s,^\(sqlalchemy.url\)[ =].*,\1 = postgresql://${INSTANCE}:${password}@localhost/${INSTANCE}," \
                -i $CKAN_ETC/${INSTANCE}/${INSTANCE}.ini
        fi
        sed -e "s,^\(email_to\)[ =].*,\1 = root," \
            -e "s,^\(error_email_from\)[ =].*,\1 = ckan-${INSTANCE}@`hostname`," \
            -e "s,# ckan\.site_id = ckan.net,ckan.site_id = ${INSTANCE}," \
            -e "s,^\(cache_dir\)[ =].*,\1 = $CKAN_LIB/${INSTANCE}/data," \
            -e "s,^\(who\.config_file\)[ =].*,\1 = $CKAN_ETC/${INSTANCE}/who.ini," \
            -e "s,\"ckan\.log\",\"/var/log/ckan/${INSTANCE}/${INSTANCE}.log\"," \
            -e "s,#solr_url = http://127.0.0.1:8983/solr,solr_url = http://127.0.0.1:8983/solr," \
            -i $CKAN_ETC/${INSTANCE}/${INSTANCE}.ini
        # Set permissions and ownership so that only members of the
        # ${INSTANCE} group can read the .ini file.
        chown ckan${INSTANCE}:ckan${INSTANCE} $CKAN_ETC/${INSTANCE}/${INSTANCE}.ini
        chmod 640 "$CKAN_ETC/${INSTANCE}/${INSTANCE}.ini"
    fi
}

ckan_add_or_replace_database_user () {
    local INSTANCE password
    if [ "X$1" = "X" ] || [ "X$2" = "X" ] ; then
        echo "ERROR: call the function ckan_add_or_replace_database_user function with an INSTANCE name, and a password for postgresql e.g." 
        echo "       std 1U923hjkh8"
        echo "       You can generate a password like this: "
        echo "           < /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c10"
        exit 1
    else
        INSTANCE=$1
        password=$2
        COMMAND_OUTPUT=`su - postgres -c "psql -c \"SELECT 'True' FROM pg_user WHERE usename='${INSTANCE}'\""`
        if ! [[ "$COMMAND_OUTPUT" =~ True ]] ; then
            echo "Creating the ${INSTANCE} user ..."
            su - postgres -c "createuser -S -D -R ${INSTANCE}"
        else
            echo "Setting the ${INSTANCE} user password ..."
            su - postgres -c "psql -c \"ALTER USER \\\"${INSTANCE}\\\" WITH PASSWORD '${password}'\""
        fi
    fi
}

ckan_ensure_db_exists () {
    local INSTANCE
    if [ "X$1" = "X" ] ; then
        echo "ERROR: call the function ensure_db_exists function with an INSTANCE name, e.g." 
        echo "       std"
        exit 1
    else
        INSTANCE=$1
        COMMAND_OUTPUT=`su - postgres -c "psql -c \"select datname from pg_database where datname='$INSTANCE'\""`
        if ! [[ "$COMMAND_OUTPUT" =~ ${INSTANCE} ]] ; then
            echo "Creating the database ..."
            su - postgres -c "createdb -O ${INSTANCE} ${INSTANCE}"
        fi
    fi
}

ckan_create_wsgi_handler () {
    local INSTANCE
    if [ "X$1" = "X" ] ; then
        echo "ERROR: call the function create_wsgi_handler function with an INSTANCE name, e.g." 
        echo "       std"
        exit 1
    else
        INSTANCE=$1

        mkdir -p /var/www/drupal

        if [ ! -f "$CKAN_LIB/${INSTANCE}/wsgi.py" ]
        then
            cat <<- EOF > $CKAN_LIB/${INSTANCE}/packaging_version.txt
                1.7
            EOF
            cat <<- EOF > $CKAN_LIB/${INSTANCE}/wsgi.py
                import os
                instance_dir = '$CKAN_LIB/${INSTANCE}'
                config_dir = '$CKAN_ETC/${INSTANCE}'
                config_file = '${INSTANCE}.ini'
                pyenv_bin_dir = os.path.join(instance_dir, 'pyenv', 'bin')
                activate_this = os.path.join(pyenv_bin_dir, 'activate_this.py')
                execfile(activate_this, dict(__file__=activate_this))
                # this is werid but without importing ckanext first import of paste.deploy will fail
                #import ckanext
                config_filepath = os.path.join(config_dir, config_file)
                if not os.path.exists(config_filepath):
                    raise Exception('No such file %r'%config_filepath)
                from paste.deploy import loadapp
                from paste.script.util.logging_config import fileConfig
                fileConfig(config_filepath)
                application = loadapp('config:%s' % config_filepath)
                from apachemiddleware import MaintenanceResponse
                application = MaintenanceResponse(application)
            EOF
        chmod +x $CKAN_LIB/${INSTANCE}/wsgi.py
        fi
   fi
}

ckan_overwrite_apache_config () {
    local INSTANCE ServerName CKAN_USER
    if [ "X$1" = "X" ] || [ "X$2" = "X" ] || [ "X$3" = "X" ] || [ "X$4" = "X" ] ; then
        echo "ERROR: call the function overwrite_apache_config function with an INSTANCE name, the server name, the ckan username, and the ckan application directory e.g." 
        echo "       std uat.ec.ckan.org ecportal /applications/ecodp/users/ecodp"
        exit 1
    else
        local INSTANCE=$1
        local ServerName=$2
        local CKAN_USER=$3
        local CKAN_APPLICATION=$4

        if [ -f /etc/httpd/conf.d/${INSTANCE}.conf ]
        then
            echo "Backing-up existing httpd configuration file for instance ${INSTANCE}"
            cp "/etc/httpd/conf.d/${INSTANCE}.conf" "/etc/httpd/conf.d/${INSTANCE}.conf.`date +%F_%T`.bak"
        fi

        echo "Creating httpd configuration file for instance ${INSTANCE}"
        cat <<- EOF > /etc/httpd/conf.d/${INSTANCE}.conf

            <VirtualHost *:8008>

                DocumentRoot ${CKAN_APPLICATION}/www/drupal
                ServerName ${ServerName}
                ServerAlias ${ServerName} localhost
                DirectoryIndex index.phtml index.html index.php index.htm

                ## Re-write urls with a 2 character locale to a form supported by CKAN.
                ## ECODP locale urls are of the form: <domain>/??/data/<rest of url>
                ## Whereas CKAN requires:             <domain>/data/??/<rest of url>
                ##
                ## This is because CKAN is mounted at /data, so the locale must come
                ## after the mount point in order that CKAN can see it.
                RewriteEngine on
                RewriteRule ^/(..)/data($|/(.*))$ /data/\$1/\$3 [L,QSA,PT]

                # Open up the action and data apis as they are required
                # for the ckanext-qa and ckanext-datastorer extensions,
                # both of which don't allow access to resources requiring
                # authentication.
                <Location /data/api/action>
                    allow from all
                    Order allow,deny
                    Satisfy Any
                </Location>

                <Location /data/api/data>
                    allow from all
                    Order allow,deny
                    Satisfy Any
                </Location>

                # this is CKAN app
                WSGIScriptAlias /data $CKAN_LIB/${INSTANCE}/wsgi.py
                WSGIDaemonProcess ${INSTANCE} display-name=${INSTANCE} processes=4 threads=15 maximum-requests=2000
                WSGIProcessGroup ${INSTANCE}

                # pass authorization info on (needed for rest api)
                WSGIPassAuthorization On

                # Added by 10F
                <Directory ${CKAN_APPLICATION}/www/drupal>
                    Options Indexes FollowSymLinks MultiViews
                    AllowOverride All
                    Order allow,deny
                    allow from all
                </Directory>

                <Directory ${CKAN_APPLICATION}/www/uploads>
                    Options Indexes FollowSymLinks MultiViews
                    IndexOptions SuppressIcon
                    AllowOverride All
                    Order allow,deny
                    allow from all
                </Directory>

                Alias /data/uploads ${CKAN_APPLICATION}/www/uploads

                # Added by InfAI
                <Directory ${CKAN_APPLICATION}/www/cubeviz>
                    Options Indexes FollowSymLinks MultiViews
                    AllowOverride All
                    Order allow,deny
                    Allow from all
                </Directory>
                Alias /apps/cubeviz ${CKAN_APPLICATION}/www/cubeviz
                Alias /apps/semmap ${CKAN_APPLICATION}/www/semmap

                <Proxy *>
                    Order allow,deny
                    allow from all
                </Proxy>

                ErrorLog /var/log/httpd/${INSTANCE}.error.log
                CustomLog /var/log/httpd/${INSTANCE}.custom.log combined

            </VirtualHost>

        EOF
    fi
}
