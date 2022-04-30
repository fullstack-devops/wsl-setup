# Develope an WSL

First of all, it should be ensured that the distro is sourced from a trustworthy environment. then the distro must be installed on the computer and filled with the basic setup, as shown below.
The finished distro is then uploaded to the somewhere so that all interested users can download it.

Download a raw distro releases from:
- [Ubuntu](https://cloud-images.ubuntu.com/releases) (.rootfs.tar.gz)
- [Windows Store](https://docs.microsoft.com/en-us/windows/wsl/install-manual#downloading-distributions) (.appx)

### .rootfs.tar.gz

The universal registration pattern is as follows:

```powershell
wsl --import <Distribution Name> <Installation Folder> <Ubuntu WSL2 Image Tarball path>
```

> Hint: you can freely choose the distro name

We will use an Ubuntu distro in version 20.04 for this example setup.

1. Download the Ubuntu 20.04 Release from the official [Source](https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz)
2. Open a Powershell (next to the Downloaded File)
3. If not already done, make new directory `C:\wsl-distros`
4. Import/Register the Distro with the command:
   ```powershell
   wsl --import new-ubuntu-20.04 "C:\wsl-distros\new-ubuntu-20.04" .\ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz
   ```
5. Check your distro by `wsl -l -v`. The output should be like:
   ```powershell
     NAME                STATE           VERSION
   * new-ubuntu-20.04    Stopped         2
   ```
   If the Version not set to 2, you need to migrate your distro! For solution run `wsl --set-version ubuntu-20.04 2`
6. Login to the distro

### .appx

1. Download the Ubuntu 20.04 version next to the Windows Store https://aka.ms/wslubuntu2004. Eg. via `curl.exe -L -o ubuntu-2004.appx https://aka.ms/wslubuntu2004`
2. Add the downloaded package Add-AppxPackage .\ubuntu-2004.appx

tbd



Now we have a blank wsl that doesn't have a standard user yet. We will set this up now and then we will download the `maintain.sh` for ubuntu into the WSL and run it to install all the tools required for the development environment.

The new Windows Terminal is recommended for further progress and future tasks. This is open source and you can install it from [here (GitHub)](https://github.com/microsoft/terminal)

1. Open the newly installed distro with powershell `wsl -d ubuntu-20.04`
2. Setup a non-root user (replace <username> with your UserId) and make it as standard user. We also set a custom `wsl.conf`
   ```bash
   export NEW_USER="<username>"
   useradd -m -G sudo -s /bin/bash "$NEW_USER"
   passwd "$NEW_USER"

   tee /etc/wsl.conf <<_EOF
   # Enable extra metadata options by default
   [automount]
   enabled = true
   options = "metadata,umask=22,fmask=11"
   
   # Enable DNS – even though these are turned on by default, we'll specify here just to be explicit.
   [network]
   generateHosts = true
   generateResolvConf = false

   [user]
   default=${NEW_USER}
   _EOF
   ```
3. Exit and shut down the WSL. Shutdown the WSL in Powershell via:
   ```bash
   wsl -t ubuntu-20.04
   ```
   We can check the successful shutdown with `wsl -l -v`. The STATE shoult be `Stopped`.
4. Now log back into the WSL. We have to delete the resolv.conf and enter our own name servers.
   > Note: Now that we have a user, we need to become root first
   ```bash
   rm /etc/resolv.conf
   tee /etc/resolv.conf <<_EOF
   nameserver 1.1.1.1
   _EOF
   ```
5. Exit and shut down the WSL. Shutdown the WSL again.
6. Export the WSL with `wsl --export new-ubuntu-20.04 C:\wsl-distros\ubuntu-20.04.tar`
7. Gzip the tar file `gzip C:\wsl-distros\ubuntu-20.04.tar` or in linux `gzip /mnt/c/wsl-distros/ubuntu-20.04.tar`
8. upload the `ubuntu-20.04.tar.gz` to some dest
   ```bash
   curl -u <LOGIN> --upload-file /mnt/c/wsl-distros/ubuntu-20.04.tar.gz https://somewhere/repository/wsl-distros/ubuntu-20.04.rootfs.tar.gz
   ```

more tbd ...