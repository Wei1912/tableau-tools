# Tableau Server Installation Automation
## How to use
### Supported OS: 
1. Windows server 2016 or later.
2. Ubuntu, Debian, CentOS, Red Hat, Amazon Linux2, Oracle Linux

### Settings before installing

1. Edit file "ts_registration.json" with your registration information.
2. (Optional) Edit Tableau Server config settings "ts_registration.json".
3. Edit file settings.properties, following items are necessary.
  * ts.product.key
  * ts.admin.user
  * ts.admin.password

### Windows
1. Run PowerShell as administrator.
2. cd to "ts-install" folder.
3. Run command
    ```
    .\InstallTableauServer.ps1 [Options]
    ```
    e.g.
    ```
    .\InstallTableauServer.ps1 -v 2020.2.4
    ```
    will install Tableau Server 2020.2.4<br />
    Run InstallTableauServer.ps1 with -h or --help for detailed usage.

### Linux
1. cd to "ts-install" directory.
   
2. Run command
    ```bash
    sudo bash linux_install.sh [Options]
    ```
    e.g.
    ```bash
    sudo bash linux_install.sh -v 2020.2.4
    ```
    will update OS and install Tableau Server 2020.2.4
    ```bash
    sudo bash linux_install.sh -v 2020.2.4 --no-update-os
    ```
    will install Tableau Server 2020.2.4 without updating OS.<br />
    Run linux_install.sh with -h or --help for detailed usage.
