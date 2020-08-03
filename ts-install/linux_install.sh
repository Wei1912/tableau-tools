#########################
# Bash script for installing Tableau Server on CentOS
# Need bash 4 or above
# Usage
#    sudo bash install.sh <update OS?> <TS version>
#########################

# check user permission
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "Select a step to resume the process, or press enter to install TS from scratch."
echo "  1. Install TSM"
echo "  2. Initialize TSM"
echo "  3. Activate"
echo "  4. Register"
echo "  5. Configure and initialize initial node"
echo "  6. Add an administrator account"
printf '...'
read run_step
echo "$run_step"
if ! ([ -n "$run_step" ] && [ "$run_step" -ge 1 ] && [ "$run_step" -le 6 ]); then
    run_step=0
fi
echo "run_step=${run_step}"

# cd to the directory where this script file is.
current_path=$(dirname "$0")
cd $current_path
echo "Current directory: $(realpath $current_path)"

# read configurations
echo "Reading configurations"
declare -A CONFIG
config_file="./settings.properties"
while IFS= read -r line; do
  # remove leading whitespaces
  line=$(sed -e 's/^[[:space:]]*//' <<< $line)
  # remove carriage return
  line=$(sed -e 's/\r$//' <<< $line)
  # skip empty or comment lines
  if ! ([ -z "$line" ] || [ "${line:0:1}" = "#" ]); then
    IFS="=" read -r key value <<< "$line"
    CONFIG[$key]=$value
  fi
done < "$config_file"
unset IFS

# check config
# check license
product_key=${CONFIG['ts.product.key']}
if [ -z $product_key ]; then
  echo 'Error: No product key of Tableau Server.'
  exit 1
fi

# check Tableau Server version
ts_version=$2
if [ -z $ts_version ]; then
  echo 'No version given by argument. Will read version from config file.'
  ts_version=${CONFIG['ts.version']}
fi
if [ -z $ts_version ]; then
  echo 'Error: No version of Tableau Server.'
  exit 1
fi
IFS='.' read -ra version_array <<< "$ts_version"
if [ ${#version_array[@]} -ne 3 ]; then
  echo "Error: $ts_version is not a valid version number."
  exit 1
fi
echo "Tableau Server version: ${ts_version}"
echo "Will install Tableau Server ${ts_version}"

# update OS
update_os_flag=$1
if [ -n "$update_os_flag" ] && [ "$update_os_flag" -eq 1 ]; then
    echo "Updating system..."
    yum update -q -y
else
    echo "Skip updating system"
fi

# create download folder
if ! [ -d "./download" ]; then
  mkdir ./download
fi

if [ "$run_step" -le 1 ]; then
    echo "1. Installing TSM ..."
    # download installer
    url="https://downloads.tableau.com/esdalt/${ts_version}/tableau-server-${ts_version//./-}.x86_64.rpm"
    installer_file_path="./download/${url##*/}"
    if [ -f "${installer_file_path}" ]; then
        echo "${installer_file_path} exists"
    else
        echo "Downloading installer from $url"
        curl --fail -o "${installer_file_path}" "$url"
        retVal=$?
        if [ $retVal -gt 0 ]; then
            echo "Downloading installer failed. error code: $retVal"
            exit 1
        fi
        echo "Downloading installer finished"
    fi

    set -e
    echo "Installing ..."
    yum -y install $installer_file_path
fi

set -e
if [ "$run_step" -le 2 ]; then
    echo "2. Initialize TSM ..."
    package_dir="/opt/tableau/tableau_server/packages"
    script_dir=$(ls -d ${package_dir}/*/ | grep "^${package_dir}/scripts\..*$")
    echo "${script_dir}/initialize-tsm --accepteula"
    ${script_dir}/initialize-tsm --accepteula

    source /etc/profile.d/tableau_server.sh
fi

# Activate Tableau Server
if [ "$run_step" -le 3 ]; then
    echo "3. Activating ..."
    tsm licenses activate -k ${product_key}
fi

# Register Tableau Server
if [ "$run_step" -le 4 ]; then
    echo "4. Registering ..."
    tsm register --file ./ts_registration.json
fi

# Configure Initial Node Settings
if [ "$run_step" -le 5 ]; then    
    echo "5. Configuring and initializing initial node ..."
    tsm settings import -f ./ts_settings.json
    tsm pending-changes apply
    tsm initialize --start-server --request-timeout 1800
fi

if [ "$run_step" -le 6 ]; then
    echo "6. Add an Administrator Account"
    # download tabcmd installer
    tabcmd_url="https://downloads.tableau.com/esdalt/${ts_version}/tableau-tabcmd-${ts_version//./-}.noarch.rpm"
    tabcmd_file_path="./download/${tabcmd_url##*/}"
    if [ -f "${tabcmd_file_path}" ]; then
        echo "${tabcmd_file_path} exists"
    else
        echo "Downloading tabcmd installer from $tabcmd_url"
        curl --fail -o "${tabcmd_file_path}" "$tabcmd_url"
        retVal=$?
        if [ $retVal -gt 0 ]; then
            echo "Downloading tabcmd installer failed. error code: $retVal"
            exit 1
        fi
        echo "Downloading tabcmd installer finished"
    fi

    # install tabcmd
    echo "Installing tabcmd ..."
    yum -y install $tabcmd_file_path
    source /etc/profile.d/tabcmd.sh

    # add admin user
    echo "Adding admin user ..."
    # find port
    port=$(cat ./ts_settings.json | sed -n -r 's/^.*\"port\" *: *([0-9]+).*$/\1/p')
    if [ -z $port ]; then
        port=80
    fi
    tabcmd initialuser --server http://localhost:${port} --username "${CONFIG['ts.admin.user']}" --password "${CONFIG['ts.admin.password']}"
fi

echo "Finished."
set +e
