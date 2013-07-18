#!/usr/bin/perl

# Load data into popcon-historical
# --------------------------------
#
# Uses DBD:MySQL to talk to Drizzle running on localhost.
#
# Example:
#  $ ./load-popcon.pl --distro=Ubuntu --date=20130701 --file=popcon-ubuntu-2013-07-01.txt.gz
#
# Known bugs:
# 	- we should do better things for inserting into package table so
# 	  that we don't do locks
# 	- About zero error reporting, although we do run in a transaction,
# 	  so you'll just get ROLLBACK in event of error.

use strict;
use autodie;

use Getopt::Long;
my $data = "file.dat";
my $distro = "Debian";
my $verbose;
my $date="";

GetOptions ("distro=s" => \$distro,
	    "date=s" => \$date,
	    "file=s" => \$data, # string
	    "verbose" => \$verbose) # flag
    or die("Error in command line arguments\n");


use DBI;

my $dsn= "DBI:mysql:database=popcon;host=127.0.0.1;port=3306";
my $user= "root";
my $password= undef;
my $dbh = DBI->connect($dsn, $user, $password);

my $popcon_id;

$dbh->begin_work;

use IO::Zlib;

my $fh= new IO::Zlib;
print STDERR "Importing from $data\n";
$fh->open($data, "r");

my $rollback= 1;

my $release_sth= $dbh->prepare("INSERT INTO `popcon_release` (popcon_id, popcon_release, nr) VALUES (?,?,?)");
my $arch_sth= $dbh->prepare("INSERT INTO `popcon_arch` (popcon_id, arch, nr) VALUES (?,?,?)");

my $count=0;

my @packages=();
my @package_names=();

while (<$fh>)
{
    print STDERR "Imported $count\r" if ($count%1000 == 0);

    $rollback= 1;
    if (/^Submissions:\s+(\d+)/)
    {
	my $sth= $dbh->prepare("INSERT INTO `popcon` (distro, popcon_date, submissions) VALUES (?,?,?)");
	$sth->execute($distro, $date, $1) or die $!;
	$popcon_id= $dbh->last_insert_id(undef, undef, undef, undef);
	print STDERR "Popcon $popcon_id has $1 submissions\n";
    }
    elsif (/^Release:\s+(.+)\s+(\d+)/)
    {
	$release_sth->execute($popcon_id, $1, $2) or last;
    }
    elsif (/^Architecture:\s+(.+)\s+(\d+)/)
    {
	print STDERR "Arch $1 $2\n";
	$arch_sth->execute($popcon_id, $1, $2) or last;
    }
    elsif (/^Vendor:/)
    {
# ignored
    }
    elsif (/^Package:\s+(.+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
    {
	$count++;
	my $name = $1;
	my ($vote_nr,$old_nr, $recent_nr, $no_files_nr) = ($2, $3, $4, $5);
	my $inst_nr= $vote_nr + $old_nr + $recent_nr + $no_files_nr;
	$name =~ s/\s+//g;

	push @package_names, $name;

	push @packages, $popcon_id, $name, $inst_nr, $vote_nr, $old_nr, $recent_nr, $no_files_nr;

    }

    if ($#packages > 300*7)
    {
	{
	    my $sql="INSERT IGNORE INTO `package` (package) VALUES (?)";
	    $sql.=",(?)" foreach(1..$#package_names);
	    my $sth= $dbh->prepare($sql);
	    $sth->execute(@package_names) or last;
	    @package_names=();
	}

	{
	my $sql= "INSERT INTO `popcon_package` (popcon_id, package_id, inst_nr, vote_nr, old_nr, recent_nr, no_files_nr) VALUES (?,(select id from package where package=?),?,?,?,?,?)";
	$sql.=",(?,(select id from package where package=?),?,?,?,?,?)" foreach (1..($#packages / 7));
	my $package_sth= $dbh->prepare($sql);
	$package_sth->execute(@packages) or last;
	@packages=();
	}
    }
    $rollback = 0;
}

	{
	    my $sql="INSERT IGNORE INTO `package` (package) VALUES (?)";
	    $sql.=",(?)" foreach(1..$#package_names);
	    my $sth= $dbh->prepare($sql);
	    $sth->execute(@package_names) or last;
	    @package_names=();
	}

    {
	my $sql= "INSERT INTO `popcon_package` (popcon_id, package_id, inst_nr, vote_nr, old_nr, recent_nr, no_files_nr) VALUES (?,(select id from package where package=?),?,?,?,?,?)";
	$sql.=",(?,(select id from package where package=?),?,?,?,?,?)" foreach (1..($#packages / 7));
	my $package_sth= $dbh->prepare($sql);
	$package_sth->execute(@packages) or $rollback=1;
    }

$fh->close;


print STDERR "Imported $count\n";

$dbh->commit if ! $rollback;

if ($rollback)
{
    $dbh->rollback;
    print STDERR "Rolling back changes due to error\n";
}
