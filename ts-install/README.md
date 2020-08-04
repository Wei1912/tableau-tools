# Tableau Server Installation Automation
## How to use

### Settings before installing

1. Edit file "ts_registration.json" with your registration information.
2. (Optional) Edit Tableau Server config settings "ts_registration.json".
3. Edit file settings.properties, following items are necessary.
  * ts.product.key
  * ts.admin.user
  * ts.admin.password

### Windows
1. Run PowerShell as administrator and cd to "ts-install" folder
2. Run command
    ```
    .\InstallTableauServer.ps1 <version>
    ```
    e.g.
    ```
    .\InstallTableauServer.ps1 2020.2.4
    ```

### Linux
1. cd to "ts-install" directory
2. Run command
    ```bash
    sudo bash install.sh <update OS?> <version>
    ```
    Options:<br />

    update OS?<br />
        0: do not update OS<br />
        1: update OS<br />
    e.g.
    ```bash
    sudo bash install.sh 1 2020.2.4
    ```
3. Press enter key when following message shows up.<br />
If the script stopped because of some issue, you can resume it by typing a number of 1~6.
    ```
    [wcheng@cc58580b96c7484 ts-install]$ sudo bash linux_install.sh 0 2020.2.4
    [sudo] password for wcheng:
    Select a step to resume the process, or press enter to install TS from scratch.
    1. Install TSM
    2. Initialize TSM
    3. Activate
    4. Register
    5. Configure and initialize initial node
    6. Add an administrator account
    ...
    ```