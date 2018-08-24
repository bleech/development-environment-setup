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
    PREFIX=`brew --prefix`
    gsed -i "s,^#\s*\(LoadModule ${MODULE} .*\),\1,g" $HTTPD_CONF_PATH
}

function disable_module() {
    MODULE=$1
    gsed -i "s,^\(LoadModule ${MODULE} .*\),# \1,g" $HTTPD_CONF_PATH
}

function enable_include() {
    INCLUDE_PATH=$1
    gsed -i "s,^#\s*\(Include ${INCLUDE_PATH}\),\1,g" $HTTPD_CONF_PATH
}

function set_directory_index() {
    gsed -i "s,DirectoryIndex.*,DirectoryIndex index.php index.html,g" $HTTPD_CONF_PATH
}

function add_server_config() {
    CONFIG='ServerName localhost\nProtocols h2 http\/1.1\n<IfModule mod_rewrite.c>\nRewriteEngine On\nRewriteOptions Inherit\n<\/IfModule>\n'
    gsed -i "/^#ServerName/a $CONFIG" $HTTPD_CONF_PATH
}

function add_includes() {
    grep -q -F 'Include /usr/local/etc/httpd/sites-enabled/*.conf' $HTTPD_CONF_PATH || echo 'Include /usr/local/etc/httpd/sites-enabled/*.conf' >> $HTTPD_CONF_PATH
    grep -q -F 'Include /usr/local/etc/httpd/custom/h5bp-performance.conf' $HTTPD_CONF_PATH || echo 'Include /usr/local/etc/httpd/custom/h5bp-performance.conf' >> $HTTPD_CONF_PATH
}

function comment_ssl_vhost() {
    START=`gsed -n  '\|^<Virtual|=' $HTTPD_SSL_CONF_PATH`
    END=`gsed -n  '\|^</Virtual|=' $HTTPD_SSL_CONF_PATH`
    if [ -z "$START" ] || [ -z "$END" ]; then
        return
    fi
    gsed -i "$START,$END s/^/#/" $HTTPD_SSL_CONF_PATH
}

function add_mysql_config() {
    CONFIG='max_connections       = 20\nkey_buffer_size       = 16K\nmax_allowed_packet    = 1M\ntable_open_cache      = 4\nsort_buffer_size      = 64K\nread_buffer_size      = 256K\nread_rnd_buffer_size  = 256K\nnet_buffer_length     = 2K\nthread_stack          = 128K\n'
    grep -q -F 'max_connections' $MYSQL_CONF_PATH || echo $CONFIG >> $MYSQL_CONF_PATH
}

function set_php_configs() {
    gsed -i "s,^listen =.*,listen = 127.0.0.1:9056,g" $PREFIX/etc/php/5.6/php-fpm.conf
    gsed -i "s,^pm =.*,pm = ondemand,g" $PREFIX/etc/php/5.6/php-fpm.conf
    gsed -i "s,^pm.max_children =.*,pm.max_children = 10,g" $PREFIX/etc/php/5.6/php-fpm.conf
    gsed -i "s,^listen =.*,listen = 127.0.0.1:9070,g" $PREFIX/etc/php/7.0/php-fpm.d/www.conf
    gsed -i "s,^pm =.*,pm = ondemand,g" $PREFIX/etc/php/7.0/php-fpm.d/www.conf
    gsed -i "s,^pm.max_children =.*,pm.max_children = 10,g" $PREFIX/etc/php/7.0/php-fpm.d/www.conf
    gsed -i "s,^listen =.*,listen = 127.0.0.1:9071,g" $PREFIX/etc/php/7.1/php-fpm.d/www.conf
    gsed -i "s,^pm =.*,pm = ondemand,g" $PREFIX/etc/php/7.1/php-fpm.d/www.conf
    gsed -i "s,^pm.max_children =.*,pm.max_children = 10,g" $PREFIX/etc/php/7.1/php-fpm.d/www.conf
    gsed -i "s,^listen =.*,listen = 127.0.0.1:9072,g" $PREFIX/etc/php/7.2/php-fpm.d/www.conf
    gsed -i "s,^pm =.*,pm = ondemand,g" $PREFIX/etc/php/7.2/php-fpm.d/www.conf
    gsed -i "s,^pm.max_children =.*,pm.max_children = 10,g" $PREFIX/etc/php/7.2/php-fpm.d/www.conf

    
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
    CONFIG='opcache.revalidate_freq=0\nopcache.max_accelerated_files=21001\nopcache.memory_consumption=128\nopcache.interned_strings_buffer=16\nopcache.fast_shutdown=1\n'
    CONF_PATH=$PREFIX/etc/php/$VERSION/conf.d/ext-opcache.ini
    if [ ! -f $CONF_PATH ]; then
        touch $CONF_PATH
    fi
    grep -q -F 'opcache.revalidate_freq' $CONF_PATH || echo $CONFIG >> $CONF_PATH
}

function setup_certs() {
    CONFIG='SSLEngine On\nSSLProtocol all -SSLv2 -SSLv3\nSSLCipherSuite ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW\nSSLCertificateFile /usr/local/etc/httpd/ssl/local.blee.ch_cert.pem\nSSLCertificateKeyFile /usr/local/etc/httpd/ssl/local.blee.ch_privkey.pem\nSSLCertificateChainFile /usr/local/etc/httpd/ssl/local.blee.ch_chain.pem\n'
    CONF_PATH=$HTTPD_CONF_BASEPATH/ssl/ssl-shared-cert.inc
    if [ ! -f $CONF_PATH ]; then
        mkdir -p $HTTPD_CONF_BASEPATH/ssl
        touch $CONF_PATH
    fi
    grep -q -F 'SSLEngine' $CONF_PATH || echo $CONFIG >> $CONF_PATH
}

function set_dnsmasq_config() {
    CONFIG='address=/.test/127.0.0.1\naddress=/.local.blee.ch/127.0.0.1\nlisten-address=127.0.0.1\nport=35353\n'
    CONF_PATH=$PREFIX/etc/dnsmasq.conf
    grep -q -F 'local.blee.ch' $CONF_PATH || echo $CONFIG >> $CONF_PATH

    sudo mkdir -p /etc/resolver
    sudo sh -c 'echo "nameserver 127.0.0.1\nport 35353" > /etc/resolver/test'
    sudo sh -c 'echo "nameserver 127.0.0.1\nport 35353" > /etc/resolver/local.blee.ch'
    brew services restart dnsmasq
}

brew bundle
# set -x
enable_module mpm_event_module
disable_module mpm_worker_module
disable_module mpm_prefork_module
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