# Dev environments <!-- omit in toc -->
Developer Environments based on Windows WSL 2

- [Provided tools/ softwaren](#provided-tools-softwaren)
- [Tips and Tricks](#tips-and-tricks)
  - [new commands](#new-commands)
- [Enabling WSL on Windows](#enabling-wsl-on-windows)
  - [Ordering via IT-Shop](#ordering-via-it-shop)
  - [Manual Setup](#manual-setup)
- [Install/Register and setup a distro](#installregister-and-setup-a-distro)
- [IDE`s](#ides)
  - [VS Code - Visual Studio Code](#vs-code---visual-studio-code)
    - [What is VS Code](#what-is-vs-code)
    - [Installation](#installation)
    - [Useful extensions](#useful-extensions)


## Provided tools/ softwaren

- `systemd`
- `python3` and `pip`
- `ansible`
- `podamn`
- `kubectl`
- `kubectx`/`kubens`
- `kind`
- `helm`
- `golang`
- `nodejs`
- `maven`
- `jq`

## Tips and Tricks

### new commands

- kubemerge
  kubemerge will update your standard `~/.kube/config` file.
  You can place all needed k8s clusters in the folder `~/.kube/configs` and by running `kubemerge` all the clusters will be combined to one!
  

## Enabling WSL on Windows

> Note: This step requires a reboot at the end.


### Manual Setup

1. Open Powershell as Administrator and enter the following commands
    ```powershell
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    ```
    ```powershell
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    ```
2. Download and install the [updatepaket for WSL2-Linux-Kernel](https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi)
3. Reboot your system
4. Open your Powershell again (as user or admin)
    ```powershell
    wsl --set-default-version 2
    ```

## Install/Register and setup a distro

Luckily for you, we already have ready-made distros that are prepared for our use case. Here is the table which distros are currently available:

| Name         | `maintain.sh` Support | Status    | Download Link |
|--------------|-----------------------|-----------|---------------|
| Ubuntu 20.04 | yes                   | available | comming soon  |
| Ubuntu 22.04 | yes                   | planned   | comming soon  |
| Kali Linux   | no                    | planned   | comming soon  |

As an example we perform an import the `ubuntu 20.04` if you are using an another distro, you should change the name.

1. Download one of the available distros
2. Open a Powershell (next to the Downloaded File)
3. If not already done, make new directory `C:\wsl-distros`
4. Import/Register the Distro with the command:
   ```powershell
   wsl --import ubuntu-20.04 "C:\wsl-distros\ubuntu-20.04" .\ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz
   ```
5. Check your distro by `wsl -l -v`. The output should be like:
   ```powershell
     NAME            STATE           VERSION
   * ubuntu-20.04    Stopped         2
   ```
   If the Version not set to 2, you need to migrate your distro! For solution run `wsl --set-version ubuntu-20.04 2`
6. Login to the distro `wsl -d ubuntu-20.04`
7. Download the `maintain.sh` from this repo with wget into your home directory.
   ```bash
   wget https://raw.githubusercontent.com/fullstack-devops/wsl-setup/main/ubuntu/maintain.sh -O maintain.sh
   chmod +x maintain.sh
   ```
8. run the sctipt with `sudo ./maintain.sh $USER`
9.  include the new bash file (.wsl-distrosrc) in your .profile
   ```bash
   tee ~/.profile <<_EOF
   # include .wsl-distrosrc if it exists
   if [ -f "\$HOME/.wsl-distrosrc" ]; then
       . "\$HOME/.wsl-distrosrc"
   fi
   _EOF
   ```
11. Shutdown your WSL again (`wsl -t ubunut-20.04`) and open a new session. Now your good to go.

You can download and run the maintain.sh again at any time, it checks whether an update of the individual tools is necessary and keeps you up to date.

#### Useful extensions

Useful extensions are automatically installed via "extension.json".
When you start Visual Studio Code for the first time, VSC asks whether the "Recommended Extensions" should be installed - confirm with Yes.
