# Ubuntu Autoinstall Generator
A script to generate a fully-automated ISO image for installing Ubuntu onto a machine without human interaction. This uses the new autoinstall method
for Ubuntu 20.04 and newer.


### Behavior
Check out the usage information below for arguments. The basic idea is to take an unmodified Ubuntu ISO image, extract it, add some kernel command line parameters, then repack the data into a new ISO. This is needed for a fully-automated install because the ```autoinstall``` parameter must be present on the kernel command line during unattended installation; otherwise the installer will wait for a human to confirm. This script automates the process of creating an ISO with this built-in.

Autoinstall configuration (disk layout, language etc) can be passed, along with cloud-init data, to the installer. Some minimal information is needed for
the installer to work - see the Ubuntu documentation for an example, which is also in the ```user-data``` file in this repository. This data can be passed over the network (not yet supported in this script), via an attached volume, or be baked into the ISO itself.

To attach via a volume, see the Ubuntu autoinstall quick start guide. It's really very easy! To bake everything into a single ISO instead, you can use the ```-a``` flag with this script and provide a user-data file (containing the autoinstall configuration and optionally cloud-init data too), plus a meta-data file if you choose. The meta-data file is optional and will be empty if it is not specified. With an 'all-in-one' ISO, you simply boot a machine using the ISO and the installer will do the rest. At the end, the machine will reboot into the new OS.

This script can use an existing ISO image or download the latest daily image from the Ubuntu project. Using a fresh ISO speeds up the installation because there won't be as many packages to update during the install.

By default, the source ISO image is checked for integrity and authenticity using GPG. This can be disabled with ```-k```.


### Usage
```
Usage: ubuntu-autoinstall-generator.sh [-h] [-v] [-a] [-u user-data-file] [-m meta-data-file]

💁 This script will create fully-automated Ubuntu 20.04 Focal Fossa installation media.

Available options:

-h, --help          Print this help and exit
-v, --verbose       Print script debug info
-a, --all-in-one    Bake user-data and meta-data into the generated ISO. By default you will
                    need to boot systems with a CIDATA volume attached containing your
                    autoinstall user-data and meta-data files.
                    For more information see: https://ubuntu.com/server/docs/install/autoinstall-quickstart
-u, --user-data     Path to user-data file. Required if using -a
-m, --meta-data     Path to meta-data file. Will be an empty file if not specified and using -a
-k, --no-verify     Disable GPG verification of the source ISO file. By default SHA256SUMS and
                    SHA256SUMS.gpg files in the script directory will be used to verify the authenticity and integrity
                    of the source ISO file. If they are not present the latest daily SHA256SUMS will be
                    downloaded and saved in the script directory. The Ubuntu signing key will be downloaded and
                    saved in a new keyring in the script directory.
-s, --source        Source ISO file. By default the latest daily ISO for Ubuntu 20.04 will be downloaded
                    and saved as <script directory>/ubuntu-original-<current date>.iso
                    That file will be used by default if it already exists.
-d, --destination   Destination ISO file. By default <script directory>/ubuntu-autoinstall-<current date>.iso will be
                    created, overwriting any existing file.
```


### Thanks
This script is based on [this](https://betterdev.blog/minimal-safe-bash-script-template/) minimal safe bash template, and steps found in [this](https://discourse.ubuntu.com/t/please-test-autoinstalls-for-20-04/15250) discussion thread (particularly [this](https://gist.github.com/s3rj1k/55b10cd20f31542046018fcce32f103e) script).
The somewhat outdated Ubuntu documentation [here](https://help.ubuntu.com/community/LiveCDCustomization#Assembling_the_file_system) was also useful.


### License
MIT license.
