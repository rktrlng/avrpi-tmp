#!/usr/bin/perl -w

# Use some black art knowledge of the /dev files and lsusb entries that the
# Arduinos create to guess some attribute of the connected arduino that we
# need to know.  We can guess the following things:
#
#   * What device file (of the form /dev/ttyWHATEVER) we should use (--device
#     option).
#
#   * What baud rate we should use to program the device (--baud option)
#
#   * What bootloader .hex file we should use in case we need to replace the
#     bootloader (--bootloader option).
#
# Note that this works only if we can find exactly one candidate device.
# If we can't find anything that looks like an Arduino, or we think we find
# more than one, print an informative error message with suggestions for
# which Make variables in the cduino build system should be set, and exit
# with a non-zero exit code.

# vim: foldmethod=marker

use strict;
use warnings FATAL => 'all';

use Data::Dumper;
use Getopt::Long;

# We require an option saying what attribute we're guessing.
my ($model, $device, $baud, $bootloader) = (0, 0, 0, 0);

GetOptions(
    "model" => \$model,
    "device" => \$device,
    "baud" => \$baud,
    "bootloader" => \$bootloader )
    or die "option parsing error";

($model xor $device xor $baud xor $bootloader)
    or die ("didn't get exactly one of --model, --device, --baud or ".
            "--bootloader options");

sub find_usb_tty_devices # {{{1
{
    # Given a USB vendor ID and product ID as arguments, return a list
    # of device tty files (e.g. /dev/ttyACM0) found on the USB.  Blows up
    # somewhere ugly for non-tty things, though that could be fixed maybe.

    @_ == 2 or die "wrong number of arguments";

    my ($vid, $pid) = @_;   # Vendor and product IDs

    my $finder_command
        = 'find -H /sys -name "idProduct" -exec '.
              'bash -c '.
                  '"grep --quiet -e '.$pid.' {} && '.
                       'echo {}" \;';

    my $id_files = `$finder_command`;
    $? == 0 or die "find command failed";

    my @ifl = split("\n", $id_files);   # ID file lines

    if ( @ifl == 0 ) {
        return ();
    }

    my @results = ();

    foreach ( @ifl ) {

        my $dpd = `dirname $_`;   # Device path directory.
        $? == 0 or die "dirname command failed";
        chomp($dpd);

        # Discovered vendor ID for this device
        my $dvid = `cat $dpd/idVendor`;
        $? == 0 or die "cat command failed";
        chomp($dvid);
        $dvid eq $vid
            or (print "unexpected vendor ID '$dvid' (expected '$vid')\n"
                and next);

        # We expect to find exactly one directory called 'tty' under $dpd
        my $ttydfc = "find $dpd -name tty -type d";   # TTY dir finder command
        my $ttyd = `$ttydfc`;
        $? == 0 or die "command '$ttydfc' failed";
        my @fol = split("\n", $ttyd);
        @fol == 1 or die "didn't find exactly one 'tty' dir under '$dpd'";
        chomp($ttyd);

        # TTY device name finder command.  The device name is something like
        # 'ttyACM0' or 'ttyUSB0' under $ttyd.
        my $ttydnfc = 'basename $(find '.$ttyd.' -name "tty?*" -type d -print)';
        my $ttydn = `$ttydnfc`;   # TTY device name (without full path)
        $? == 0 or die "command '$ttydnfc' failed";
        chomp($ttydn);

        my $ttydp = "/dev/$ttydn";   # TTY device path

        -e $ttydp
            or die "we though device file  '$ttydp', but it doesn't exist";

        push(@results, "/dev/$ttydn");
    }

    # Cross-check the number of Unos we found with what lsusb shows.  It would
    # be nice if we could just use lsusb for all this, but so far as I can
    # tell it doesn't give us any way to figure out which /dev file we want.
    # The udevinfo program doesn't quite do it either, so we end up groping
    # around in /dev ourselves.
    my $le = `lsusb -d $vid:$pid`;   # lsusb entries
    my @lel = split("\n", $le);   # lsusb entry lines
    scalar(@lel) == scalar(@results)
        or die "unexpected number of Uno entries in lsusb output";

    return @results;
} # }}}1

sub find_uno_rev3_devices # {{{1
{
    # Search for any Arduino Uno rev.3 devices and return list of device
    # file names (which can be empty) under /dev that refer to the devices.
    # This hopefully finds other Uno devices besides rev. 3 as well, but I
    # haven't had a chance to test it.

    my ($ur3vid, $ur3pid) = ('2341', '0043');   # Uno vendor and product IDs

    return find_usb_tty_devices($ur3vid, $ur3pid);
} # }}}1

sub find_duemilanove_devices # {{{1
{
    # Search for any Arduino Uno rev.3 devices and return list of device
    # file names (which can be empty) under /dev that refer to the devices.
    # This hopefully finds other Uno devices besides rev. 3 as well, but I
    # haven't had a chance to test it.

    # Duemilanove vendor and product IDs
    my ($duevid, $duepid) = ('0403', '6001');

    return find_usb_tty_devices($duevid, $duepid);
} # }}}1

my @uno_rev3_devs = find_uno_rev3_devices();
my @duemilanove_devs = find_duemilanove_devices();

# For some messages we have strings with one discovered device per line.
my $uno_rev3_devs_multiline = join("\n", @uno_rev3_devs);
my $duemilanove_devs_multiline = join("\n", @duemilanove_devs);

# Print results to stdout and/or diagnostics to stderr {{{1

# The speeds that we believe are used by some different Arduino versions.
my ($uno_rev3_baud, $duemilanove_baud) = (115200, 57600);

# The bootloaders that we believe are used by some different Arduino versions.
my ($uno_rev3_bootloader, $duemilanove_bootloader) = (
    'optiboot_atmega328.hex', 'ATmegaBOOT_168_atmega328.hex' );

if ( @uno_rev3_devs == 1 and @duemilanove_devs == 0 ) {
    if ( $model ) {
        print "Uno Rev3\n";
    }
    elsif ( $device ) {
        print $uno_rev3_devs[0]."\n";
    }
    elsif ( $baud ) {
        print $uno_rev3_baud."\n";
    }
    elsif ( $bootloader ) {
        print $uno_rev3_bootloader."\n";
    }
    else {
        die "shouldn't be here";
    }
}
elsif ( @uno_rev3_devs == 0 and @duemilanove_devs == 1 ) {
    if ( $model ) {
        print "Duemilanove\n";
    }
    elsif ( $device ) {
        print $duemilanove_devs[0]."\n";
    }
    elsif ( $baud ) {
        print $duemilanove_baud."\n";
    }
    elsif ( $bootloader ) {
        print $duemilanove_bootloader."\n";
    }
    else {
        die "shouldn't be here";
    }
}
elsif ( @uno_rev3_devs == 0 and @duemilanove_devs == 0 ) {
    die <<END_DID_NOT_DETECT_ARDUINOS_MESSAGE;

$0 failed: Didn't detect any Arduinos on USB :(.
Is the Arduino plugged in?  It's quite possible that automatic detection has
failed somehow even though the Arduino is there.  Another thing to try is to
unplug the Arduino and do 'ls /dev/tty*', then plug it back in and try
'ls /dev/tty*' again and see if a file like /dev/ttyUSB0 or /dev/ttyACM0 has
appeared.  If so, the Make variable ARDUINO_PORT can be set to the file in
question.  The ARDUINO_BAUD Make variable will also need to be set: for an
Arduino Uno rev.3 (and probably other Unos) it should be set to $uno_rev3_baud,
for an Arduino Duemilanove it should be set to $duemilanove_baud.

END_DID_NOT_DETECT_ARDUINOS_MESSAGE
}
else {
    die <<END_DETECTED_MULTIPLE_ARDUINOS_MESSAGE;

$0 failed: Mutiple things that look like Arduinos
were detected, including:

$uno_rev3_devs_multiline
$duemilanove_devs_multiline

It's possible that other devices that use the FTDI FT232R chip are on the
USB bus, and are indistinguishable from older Arduinos which also use
this chip (e.g. the Duemilanove).

It's also possible that you're a gadget-happy nut who connects and programs
multiple Arduinos at the same time :)

Either way, the thing to do is to set the Make variables ARDUINO_PORT,
ARDUINO_BAUD, and ARDUINO_BOOTLOADER to the correct values.  You can do this by adding lines something like this to the Makefile for the module you are working on.  If you'retrying to program an Arduino Uno Rev. 3, you likely want these
values:

   ARDUINO_PORT = /dev/ttyACM0
   ARDUINO_BAUD = $uno_rev3_baud
   ARDUINO_BOOTLOADER = $uno_rev3_bootloader

But the ARDUINO_PORT should be the one from the above list that corresponds
to the Arduino device you want to program.  If you aren't sure which you
want, try unplugging the device and re-running the command that produced
this message to see which one dissapears from the list :).

The ARDUINO_BAUD should probably be $uno_rev3_baud for an Uno rev.3,
or $duemilanove_baud for a Duemilanove.

The ARDUINO_BOOTLOADER should probably be $uno_rev3_bootloader for an
Uno rev.3, or $duemilanove_bootloader for a Duemilanove.  Note that the
bootloader file is not used for most Make targets, but this build system
likes to know about it anyway.  Sorry.

These Make variables can be set from the command line as well, e.g.:

   make -rR writeflash \\
     ARDUINO_PORT=/dev/ttyACM0 \\
     ARDUINO_BAUD=$uno_rev3_baud \\
     ARDUINO_BOOTLOADER=$uno_rev3_bootloader

In case you want to use custom shell commands to quickly flip back and
forth between programming two different Arduinos.

END_DETECTED_MULTIPLE_ARDUINOS_MESSAGE
}

# }}}1

exit 0;
