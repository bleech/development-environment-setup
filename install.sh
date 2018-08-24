SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null && pwd )"

PREFIX=`brew --prefix`
HTTPD_CONF_BASEPATH=$PREFIX/etc/httpd
HTTPD_CONF_PATH=$HTTPD_CONF_BASEPATH/httpd.conf
HTTPD_SSL_CONF_PATH=$HTTPD_CONF_BASEPATH/extra/httpd-ssl.conf
MYSQL_CONF_BASEPATH=$PREFIX/etc/mysql
MYSQL_CONF_PATH=$PREFIX/etc/my.cnf


function enable_module() {
    MODULE=$1
    # VERSION=${2:-7.1}
    PREFIX=`brew --prefix`
    sed -i'' -e "s,^#[[:space:]]*\(LoadModule ${MODULE} .*\),\1,g" $HTTPD_CONF_PATH
}

function disable_module() {
    MODULE=$1
    # VERSION=${2:-7.1}
    sed -i'' -e "s,^\(LoadModule ${MODULE} .*\),# \1,g" $HTTPD_CONF_PATH
}

function enable_include() {
    INCLUDE_PATH=$1
    # VERSION=${2:-7.1}
    sed -i'' -e "s,^#[[:space:]]*\(Include ${INCLUDE_PATH} .*\),\1,g" $HTTPD_CONF_PATH
}

function set_directory_index() {
    sed -i'' -e "s,DirectoryIndex.*,DirectoryIndex index.php index.html,g" $HTTPD_CONF_PATH
}

function add_server_config() {
    read -r -d '' CONFIG << EOM
ServerName localhost\n
Protocols h2 http/1.1\n
<IfModule mod_rewrite.c>\n
    RewriteEngine On\n
    RewriteOptions Inherit\n
</IfModule>
EOM
    sed -i'' -e '/#ServerName/a\' -e "$CONFIG" $HTTPD_CONF_PATH
}

function add_includes() {
    grep -q -F 'Include /usr/local/etc/httpd/sites-enabled/*.conf' $HTTPD_CONF_PATH || echo 'Include /usr/local/etc/httpd/sites-enabled/*.conf' >> $HTTPD_CONF_PATH
    grep -q -F 'Include /usr/local/etc/httpd/custom/h5bp-performance.conf' $HTTPD_CONF_PATH || echo 'Include /usr/local/etc/httpd/custom/h5bp-performance.conf' >> $HTTPD_CONF_PATH
}

function comment_ssl_vhost() {
    START=`sed -n  '\|^<Virtual|=' $HTTPD_SSL_CONF_PATH`
    END=`sed -n  '\|^</Virtual|=' $HTTPD_SSL_CONF_PATH`
    if [ -z "$START" ] || [ -z "$END" ]; then
        return
    fi
    sed -i'' -e "$START,$END s/^/#/" $HTTPD_SSL_CONF_PATH
}

function add_mysql_config() {
    read -r -d '' CONFIG << EOM
max_connections       = 20\n
key_buffer_size       = 16K\n
max_allowed_packet    = 1M\n
table_open_cache      = 4\n
sort_buffer_size      = 64K\n
read_buffer_size      = 256K\n
read_rnd_buffer_size  = 256K\n
net_buffer_length     = 2K\n
thread_stack          = 128K\n
EOM
    grep -q -F 'max_connections' $MYSQL_CONF_PATH || echo $CONFIG >> $MYSQL_CONF_PATH
}

function set_php_configs() {
    sed -i'' -e "s,^listen =.*,listen = 127.0.0.1:9056,g" $PREFIX/etc/php/5.6/php-fpm.conf
    sed -i'' -e "s,^pm =.*,pm = ondemand,g" $PREFIX/etc/php/5.6/php-fpm.conf
    sed -i'' -e "s,^pm.max_children =.*,pm.max_children = 10,g" $PREFIX/etc/php/5.6/php-fpm.conf
    sed -i'' -e "s,^listen =.*,listen = 127.0.0.1:9070,g" $PREFIX/etc/php/7.0/php-fpm.d/www.conf
    sed -i'' -e "s,^pm =.*,pm = ondemand,g" $PREFIX/etc/php/7.0/php-fpm.d/www.conf
    sed -i'' -e "s,^pm.max_children =.*,pm.max_children = 10,g" $PREFIX/etc/php/7.0/php-fpm.d/www.conf
    sed -i'' -e "s,^listen =.*,listen = 127.0.0.1:9071,g" $PREFIX/etc/php/7.1/php-fpm.d/www.conf
    sed -i'' -e "s,^pm =.*,pm = ondemand,g" $PREFIX/etc/php/7.1/php-fpm.d/www.conf
    sed -i'' -e "s,^pm.max_children =.*,pm.max_children = 10,g" $PREFIX/etc/php/7.1/php-fpm.d/www.conf
    sed -i'' -e "s,^listen =.*,listen = 127.0.0.1:9072,g" $PREFIX/etc/php/7.2/php-fpm.d/www.conf
    sed -i'' -e "s,^pm =.*,pm = ondemand,g" $PREFIX/etc/php/7.2/php-fpm.d/www.conf
    sed -i'' -e "s,^pm.max_children =.*,pm.max_children = 10,g" $PREFIX/etc/php/7.2/php-fpm.d/www.conf

    
    if [ ! -f $PREFIX/etc/php/7.0/conf.d/ext-opcache.ini ]; then
        touch $PREFIX/etc/php/7.0/conf.d/ext-opcache.ini
    fi
    if [ ! -f $PREFIX/etc/php/7.1/conf.d/ext-opcache.ini ]; then
        touch $PREFIX/etc/php/7.1/conf.d/ext-opcache.ini
    fi
    if [ ! -f $PREFIX/etc/php/7.2/conf.d/ext-opcache.ini ]; then
        touch $PREFIX/etc/php/7.2/conf.d/ext-opcache.ini
    fi

    add_opcache_config 5.6
    add_opcache_config 7.0
    add_opcache_config 7.1
    add_opcache_config 7.2
}

function add_opcache_config() {
    VERSION=$1
    read -r -d '' CONFIG << EOM
opcache.revalidate_freq=0\n
opcache.max_accelerated_files=21001\n
opcache.memory_consumption=128\n
opcache.interned_strings_buffer=16\n
opcache.fast_shutdown=1\n
EOM

    CONF_PATH=$PREFIX/etc/php/$VERSION/conf.d/ext-opcache.ini
    if [ ! -f $CONF_PATH ]; then
        touch $CONF_PATH
    fi
    grep -q -F 'opcache.revalidate_freq' $CONF_PATH || echo $CONFIG >> $CONF_PATH
}

function setup_certs() {
    read -r -d '' CONFIG << EOM
SSLEngine On\n
SSLProtocol all -SSLv2 -SSLv3\n
SSLCipherSuite ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW\n
SSLCertificateFile /usr/local/etc/httpd/ssl/local.blee.ch_cert.pem\n
SSLCertificateKeyFile /usr/local/etc/httpd/ssl/local.blee.ch_privkey.pem\n
SSLCertificateChainFile /usr/local/etc/httpd/ssl/local.blee.ch_chain.pem\n
EOM

    CONF_PATH=$HTTPD_CONF_BASEPATH/ssl/ssl-shared-cert.inc
    if [ ! -f $CONF_PATH ]; then
        mkdir -p $HTTPD_CONF_BASEPATH/ssl
        touch $CONF_PATH
    fi
    grep -q -F 'SSLEngine' $CONF_PATH || echo $CONFIG >> $CONF_PATH
}

function set_dnsmasq_config() {
    read -r -d '' CONFIG << EOM
address=/.test/127.0.0.1\\n
address=/.local.blee.ch/127.0.0.1\\n
listen-address=127.0.0.1\\n
port=35353\\n
EOM
    CONF_PATH=$PREFIX/etc/dnsmasq.conf
    grep -q -F 'local.blee.ch' $CONF_PATH || sed -i'' -e "1s;^;$CONFIG;" $CONF_PATH

    sudo mkdir -p /etc/resolver
    sudo sh -c 'echo "nameserver 127.0.0.1\nport 35353" > /etc/resolver/test'
    sudo sh -c 'echo "nameserver 127.0.0.1\nport 35353" > /etc/resolver/local.blee.ch'
    brew services restart dnsmasq
}


enable_module mpm_event_module
disable_module mpm_worker_module
enable_module socache_shmcb_module
enable_module deflate_module
enable_module expires_module
enable_module proxy_module
enable_module proxy_fcgi_module
enable_module ssl_module
enable_module http2_module
enable_module vhost_alias_module
enable_module rewrite_module

set_directory_index

enable_include $HTTPD_CONF_BASEPATH/extra/httpd-mpm.conf
enable_include $HTTPD_CONF_BASEPATH/extra/httpd-ssl.conf

add_server_config
add_includes

mkdir -p $HTTPD_CONF_BASEPATH/custom/
cp $DIR/h5bp-performance.conf $HTTPD_CONF_BASEPATH/custom/
comment_ssl_vhost

setup_certs
mkdir $HTTPD_CONF_BASEPATH/sites-available
mkdir $HTTPD_CONF_BASEPATH/sites-enabled

/usr/local/opt/mysql@5.7/bin/mysql_secure_installation
brew link --force mysql@5.7

add_mysql_config

set_php_configs

sudo cp $DIR/it.bleech.httpdfwd.plist /Library/LaunchDaemons/
sudo launchctl load -Fw /Library/LaunchDaemons/it.bleech.httpdfwd.plist

set_dnsmasq_config