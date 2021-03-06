#!/bin/sh

# Travis doesn't provide FreeBSD machines, so we just take a Linux one and run
# FreeBSD in qemu virtual machine. qemu is being ran in curses mode inside a
# screen session, because screen allows to easily send input and read output.
# The input is sent using `screen -S session-name -X stuff ...` and the output
# is read from the screen's log file. Note that for some reason you can't send
# long input lines on Travis (it works just fine when I do it on my machine...),
# but that limitation is not an issue, as we don't really need to send long
# lines of input anyway. Also, note that since we run qemu in curses mode, the
# output contains control characters intended for a terminal emulator telling
# how to position and color the text, so it might be a little tricky to read it
# sometimes. The only time when this script has to send input to and read the
# output from the screen session is during the initial setup when we setup the
# network, install and configure the ssh server, and update the system. After
# this initial setup, ssh is used to communicate with the FreeBSD running in the
# VM, which is a lot friendlier way of communication. Please note that Travis
# doesn't seem to allow KVM passthrough, so qemu has to emulate all the
# hardware, which makes it quite slow compared to the host machine. We cache
# the qemu image since it takes a long time to run the initial system and
# package updates, and we do incremental system and package updates on every
# change to the list of git tags (i.e. on every toxcore release, presumably).

sudo apt-get update
sudo apt-get install -y qemu

OLD_PWD="$PWD"

mkdir -p /opt/freebsd/cache
cd /opt/freebsd/cache

# Make sure to update DL_SHA512 when bumping the version
FREEBSD_VERSION="11.2"
IMAGE_NAME=FreeBSD-${FREEBSD_VERSION}-RELEASE-amd64.raw

# Sends keys to the VM as they are
send_keys()
{
  screen -S $SCREEN_SESSION -X stuff "$1"
}

# Blocks until a specific text appears on VM's screen
wait_for()
{
  while ! grep -q "$1" screenlog.0
  do
    sleep 1
  done
}

# Starts VM and waits until it's fully running (until a login prompt is shown)
start_vm()
{
  rm -f screenlog.0

  # Start emulator. 2000mb RAM should be enough, right? The build machine has over 7gb.
  screen -L -S $SCREEN_SESSION -d -m \
    qemu-system-x86_64 -curses -m 2000 -smp $NPROC \
    -net user,hostfwd=tcp::${SSH_PORT}-:22 -net nic "$IMAGE_NAME"

  # Wait for the boot screen options
  wait_for "Autoboot in"

  # Select the 1st option
  send_keys '
'

  # Wait for the system to boot and present the login prompt
  wait_for "FreeBSD/amd64 ("
}

# Shuts VM down and waits until its process finishes
stop_vm()
{
  # Turn it off
  send_keys 'poweroff
'

  # Wait for qemu process to terminate
  while ps aux | grep qemu | grep -vq grep
  do
    sleep 1
  done
}

# Let's see what's in the cache directory
ls -lh

cd "$OLD_PWD"
