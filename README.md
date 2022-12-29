# iwd-archlinux-eduroam

**A POSIX shell assistant to configure eduroam with iwd.**

**Note this is a fork from Groctel/iwd-eduroam. Modified for the University of Edinburgh.**

## Description

`iwd-eduroam` is a small assistant that helps you configure eduroam for iwd.
It creates and populates `/var/lib/iwd/eduroam.8021x` with the connection you provide it about your eduroam configuration.

> **WARNING !!!**
> This program requires 'sudo' privileges to write files into their destination.
> It won't ask for them anywhere else and uses the minimum viable number of superuser commands.

## Usage

Ensure you have network configurations enabled for iwd. From https://wiki.archlinux.org/title/Iwd - "To activate iwd's network configuration feature, create/edit /etc/iwd/main.conf and add the following section to it: "

```
/etc/iwd/main.conf

[General]
EnableNetworkConfiguration=true
```


Call eduroam-config.sh: .`/eduroam-config.sh` and enter your credentials:
 - e.g s1234567@ed.ac.uk and password

This will create the '/var/lib/iwd/eduroam.8021x' iwd configuration file.
Now your should be able to connect to eduroam running `iwctl station wlan0 connect "eduroam"`.

