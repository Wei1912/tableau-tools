#########################
# Bash script for installing Tableau Server on Ubuntu, Debian, Redhat, CentOS, Amazon Linux, Oracle Linux
# Need bash 4 or above
#########################

# how to use
__usage="
Usage: sudo bash install.sh [Options]

Options:
  -h, --help                Print usage
  -v, --version <version>   Tableau Server version
  --no-update-os            Do not update OS
  --resume <n>              Resume installation after interruption
        n:
          1. Install TSM
          2. Initialize TSM
          3. Activate
          4. Register
          5. Configure and initialize initial node
          6. Add an administrator account
"

# read arguments
ts_version=""
run_step=0
update_os=1

args=("$@")
i=0
while [ "$i" -lt "${#args[@]}" ]; do
  arg=${args[$i]}
  if [ "$arg" == "-v" ] || [ "$arg" == "--version" ]; then
    ts_version="${args[$i+1]}"
    i=$(( $i + 1 ))
  elif [ "$arg" == "--no-update-os" ]; then
    update_os=0
  elif [ "$arg" == "--resume" ]; then
    step="${args[$i+1]}"
    if ! ([ "$step" -ge 1 ] && [ "$step" -le 6 ]); then
      echo "Please specify a number of 1-6 for --resume."
      exit 1
    fi
    run_step=$step
    i=$(( $i + 1 ))
  elif [ "$arg" == "-h" ] || [ "$arg" == "--help" ]; then
    echo "${__usage}"
    exit
  else
    echo "Unrecognized argument: $arg"
    exit 1
  fi
  i=$(( $i + 1 ))
done

# check user permission
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# find out distribution name
dist_name=""
if [ -f /etc/os-release ]; then
  dist_name=$(grep -Eo "^NAME=.*" /etc/os-release | cut -d '=' -f 2)
elif [ -f /etc/lsb-release ]; then
  dist_name=$(grep -Eo "^DISTRIB_ID=.*" /etc/os-release | cut -d '=' -f 2)
elif type lsb_release >/dev/null 2>&1; then
  dist_name=$(lsb_release -si)
elif [ -f /etc/debian_version ]; then
  # Older Debian/Ubuntu/etc.
  dist_name="Debian"
elif [ -f /etc/redhat-release ]; then
  # Older Red Hat, CentOS, etc.
  dist_name="Redhat"
fi
dist_name=${dist_name,,}
echo "OS distribution: $dist_name"

# decide which package tool to use
pkg_tool=""
if [ -n "$dist_name" ]; then
  if [[ "$dist_name" = *ubuntu* ]] || [[ "$dist_name" = *debian* ]]; then
    pkg_tool="apt"
  elif [[ "$dist_name" = *centos* ]] || \
       [[ "$dist_name" = *redhat* ]] || [[ "$dist_name" = *"red hat"* ]] || \
       [[ "$dist_name" = *amazon* ]] || [[ "$dist_name" = *oracle* ]]; then
    pkg_tool="yum"
  fi
fi
echo "Package tool: $pkg_tool"
if [ -z $pkg_tool ]; then
  echo "OS is not supported"
  exit 1
fi

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
if [ -n "$update_os" ] && [ "$update_os" -eq 1 ]; then
  echo "Updating system..."
  if [ "$pkg_tool" = "yum" ]; then
    yum update -q -y
  elif [ "$pkg_tool" = "apt" ]; then
    apt update && apt -y upgrade
  fi
  echo "Updating system finished"
else
  echo "Skip updating system"
fi

# create download folder
if ! [ -d "./download" ]; then
  mkdir ./download
fi

# install gdebi-core for Ubuntu, Debian
if [ "$pkg_tool" = "apt" ]; then
  apt -y install gdebi-core
fi

if [ "$run_step" -le 1 ]; then
  echo "1. Installing TSM ..."
  # download installer
  if [ "$pkg_tool" = "yum" ]; then
    url="https://downloads.tableau.com/esdalt/${ts_version}/tableau-server-${ts_version//./-}.x86_64.rpm"
  elif [ "$pkg_tool" = "apt" ]; then
    url="https://downloads.tableau.com/esdalt/${ts_version}/tableau-server-${ts_version//./-}_amd64.deb"
  fi
  
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
  if [ "$pkg_tool" = "yum" ]; then
    yum -y install $installer_file_path
  elif [ "$pkg_tool" = "apt" ]; then
    gdebi -n $installer_file_path
  fi
  echo "Installing TSM finished"
fi

set -e
if [ "$run_step" -le 2 ]; then
  echo "2. Initialize TSM ..."
  package_dir="/opt/tableau/tableau_server/packages"
  script_dir=$(ls -d ${package_dir}/*/ | grep "^${package_dir}/scripts\..*$")
  echo "${script_dir}/initialize-tsm --accepteula"
  ${script_dir}/initialize-tsm --accepteula -f
  echo "Initialize TSM finished"
fi

source /etc/profile.d/tableau_server.sh

# Activate Tableau Server
if [ "$run_step" -le 3 ]; then
  echo "3. Activating ..."
  tsm licenses activate -k ${product_key}
  echo "Activating finished"
fi

# Register Tableau Server
if [ "$run_step" -le 4 ]; then
  echo "4. Registering ..."
  tsm register --file ./ts_registration.json
  echo "Registering finished"
fi

# Configure Initial Node Settings
if [ "$run_step" -le 5 ]; then    
  echo "5. Configuring and initializing initial node ..."
  tsm settings import -f ./ts_settings.json
  tsm pending-changes apply
  tsm initialize --start-server --request-timeout 1800
  echo "Configuring and initializing initial node finished"
fi

if [ "$run_step" -le 6 ]; then
  echo "6. Add an Administrator Account"
  # download tabcmd installer
  if [ "$pkg_tool" = "yum" ]; then
    tabcmd_url="https://downloads.tableau.com/esdalt/${ts_version}/tableau-tabcmd-${ts_version//./-}.noarch.rpm"
  elif [ "$pkg_tool" = "apt" ]; then
    tabcmd_url="https://downloads.tableau.com/esdalt/${ts_version}/tableau-tabcmd-${ts_version//./-}_all.deb"
  fi
  
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
  if [ "$pkg_tool" = "yum" ]; then
    yum -y install $tabcmd_file_path
  elif [ "$pkg_tool" = "apt" ]; then
    gdebi -n $tabcmd_file_path
  fi
  echo "Installing tabcmd finished"
  
  source /etc/profile.d/tabcmd.sh

  # add admin user
  echo "Adding admin user ..."
  # find port
  port=$(cat ./ts_settings.json | sed -n -r 's/^.*\"port\" *: *([0-9]+).*$/\1/p')
  if [ -z $port ]; then
    port=80
  fi
  tabcmd initialuser --server http://localhost:${port} --username "${CONFIG['ts.admin.user']}" --password "${CONFIG['ts.admin.password']}"
  echo "Adding admin user finished"
fi

echo "Finished."
set +e
