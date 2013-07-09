package PopconHistorical::App;
use Dancer ':syntax';
use strict;
use DBI;

use GD::Graph::lines;
use List::Util qw( min max );

our $VERSION = '0.1';

my $dsn= "DBI:mysql:database=popcon;host=127.0.0.1;port=3306";
my $user= "root";
my $password= undef;
my $dbh = DBI->connect($dsn, $user, $password) or die $!;

sub max_y
{
    my $m = max(@_);
    my $t = int(0.1 * $m);
    $t = max(int(($t + 10) / 10) * 10, $t);
    my $max_y= int(($m + $t) / $t) * $t;
    return $max_y;
}

sub get_distros()
{
    my @distros;
    my $sql= "SELECT DISTINCT distro FROM popcon ORDER BY distro";
    my $r= $dbh->selectall_arrayref($sql) or die $!;

    push @distros, @$_[0] foreach @$r;
    

    return @distros;
}

get '/' => sub {
    template 'index', {
	'distros' => [get_distros()] ,
	'comparisons' => [
	    { title=>'MySQL',
	      items=>[
		  { name=>'MySQL',
		    's'=> [
			{ url=>'?title=MySQL&packages=mysql-server-5.0,mysql-server-5.1,mysql-server-5.5,mysql-server-5.6' },
			]
		  },
		  ]
	    },
	    { title=>'Percona Toolkit',
	      items=>[
		  { name=>'Percona Toolkit',
		    's'=> [ { url=>'?title=Percona%20Toolkit%20vs%20Maatkit&packages=percona-toolkit,maatkit' } ] }
		  ]
	    },
	    { title=>'Percona XtraBackup',
	      items=> [
		  { name=>'Percona XtraBackup',
		    's'=> [ { url=>'?title=Percona%20XtraBackup&packages=percona-xtrabackup'} ] },
		  { name=>'MySQL Backup solutions',
		    's'=> [ { url=>'?title=MySQL%20Backup&packages=percona-xtrabackup,mydumper,mylvmbackup'} ] },
		  ]
	    },
	    { title=>'5.1 Server versions',
	      items=> [
		  { name=>'Percona 5.1 Vs MariaDB 5.[123]',
		    's'=> [ { url=>'?title=Percona%20Server%205.1%20vs%20MariaDB%205.[123]&packages=percona-server-server-5.1,mariadb-server-5.1,mariadb-server-5.2,mariadb-server-5.3'} ] },
		  { name=>'All 5.1',
		    's'=> [ { url=>'?title=MySQL%205.1&packages=percona-server-server-5.1,mariadb-server-5.1,mariadb-server-5.2,mariadb-server-5.3,mysql-server-5.1'} ] },
		  ]
	    },

	    { title=>'5.5 Server versions',
	      items=> [
		  { name=>'Percona 5.5 Vs MariaDB 5.5',
		    's'=> [ { url=>'?title=Percona%20Server%205.5%20vs%20MariaDB%205.5&packages=percona-server-server-5.5,mariadb-server-5.5'} ] },
		  { name=>'All 5.5',
		    's'=> [ { url=>'?title=MySQL%205.5&packages=percona-server-server-5.5,mariadb-server-5.5,mysql-server-5.5'} ] },
		  ]
	    },

	    { title=>'5.6 Server versions',
	      items=> [
		  { name=>'Percona 5.6 Vs MariaDB 10.0',
		    's'=> [ { url=>'?title=Percona%20Server%205.6%20vs%20MariaDB%2010.0&packages=percona-server-server-5.6,mariadb-server-10.0'} ] },
		  { name=>'All 5.6',
		    's'=> [ { url=>'?title=MySQL%205.6&packages=percona-server-server-5.6,mariadb-server-10.0,mysql-server-5.6'} ] },
		  ]
	    },

	    { title=>'Galera',
	      items=> [
		  { name=>'Percona XtraDB Cluster Vs MariaDB Galera 5.5',
		    's'=> [ { url=>'?title=Percona%20XtraDB%20Cluster%205.6%20vs%20MariaDB%20Galera%205.5&packages=percona-xtradb-cluster-server-5.5,mariadb-galera-server-5.5'} ] },
		  { name=>'PXC vs MariaDB vs MMM',
		    's'=> [ { url=>'?title=MySQL%20Clustering&packages=percona-xtradb-cluster-server-5.5,mariadb-galera-server-5.5,mysql-mmm-tools'} ] },
		  ]
	    },

	    { title=>'MySQL Clients',
	      items=> [
		  { name=>'Percona Clients Vs MariaDB Clients',
		    's'=> [ { url=>'?title=Percona%20Clients%20vs%20MariaDB%20Clients&packages=percona-server-client-5.1,percona-server-client-5.5,percona-server-client-5.6,,mariadb-client-5.1,mariadb-client-5.2,mariadb-client-5.3,mariadb-client-5.5,mariadb-client-10.0'} ] },
		  { name=>'All Clients',
		    's'=> [ { url=>'?title=Percona%20Clients%20vs%20MariaDB%20Clients&packages=percona-server-client-5.1,percona-server-client-5.5,percona-server-client-5.6,,mariadb-client-5.1,mariadb-client-5.2,mariadb-client-5.3,mariadb-client-5.5,mariadb-client-10.0,mysql-client-5.0,mysql-client-5.1,mysql-client-5.5'} ] }
		  ]
	    },




	    ]
    };
};

sub get_popcons($)
{
    my ($distro) = @_;
    my $sql = "select popcon_date from popcon where distro=?";
    my $sth= $dbh->prepare($sql);
    $sth->execute($distro) or die $!;

    my $r= $sth->fetchall_arrayref;

    my %p;

    foreach (@$r) {
	$p{@$_[0]} = undef;
    }

    return %p;
}    


sub get_nr_for_package($$$)
{
    my ($pkg, $distro,$counter) = @_;

    my $c= "vote_nr+no_files_nr+recent_nr";
    $c= "inst_nr" if($counter eq "inst");
    
    my $sql= "select popcon_date,$c from popcon_package LEFT JOIN popcon ON popcon.id=popcon_id LEFT JOIN package ON package_id=package.id where package=? and distro=? order by package, popcon_date";
    my $sth= $dbh->prepare($sql);
    $sth->execute($pkg, $distro) or die $!;

    my $r= $sth->fetchall_arrayref;

    my (@x, @y);
    foreach (@$r) {
	push @x, @$_[0];
	push @y, @$_[1];
    }

    return ( \@x, \@y );
}

sub get_all_data($@)
{
    my ($counter, $distro, @packages) = @_;

    my %p = get_popcons($distro);

    my @rdata;

    foreach (@packages)
    {
	push @rdata, [get_nr_for_package($_,$distro, $counter)];
    }

    foreach my $pkg (0..$#packages)
    {
	foreach (0..$#{$rdata[$pkg][0]})
	{
	    $p{$rdata[$pkg][0][$_]}{$packages[$pkg]} = $rdata[$pkg][1][$_];
	}
    }

    my @data = ([]);
    push @data, [] foreach (@packages);

    foreach(sort keys %p)
    {
	push $data[0], $_;
	foreach my $pkg (0..$#packages)
	{
	    push $data[$pkg+1], $p{$_}{$packages[$pkg]} || 0;
	}
    }

    return @data;
}

get '/data/*/*.*' => sub {
    my ($distro, $inst, $fmt) = splat;
    my @pkgs = split /,/,param 'packages';

    my @data = get_all_data($inst, $distro, @pkgs);

    content_type 'text/plain' if $fmt eq 'txt';
    content_type 'text/csv' if $fmt eq 'csv';

    my $r=join ',',("Date",@pkgs);
    $r.="\n";
    foreach my $s (0..$#{$data[0]})
    {
	$r.= "$data[0][$s]";
	$r.=",$data[$_+1][$s]" foreach (0..$#pkgs);
	$r.="\n";
    }
    return $r;
};


get '/graph/*/*' => sub {
    my ($distro, $inst) = splat;
    my @pkgs = split /,/,param 'packages';

    my @data = get_all_data($inst, $distro, @pkgs);

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend(@pkgs);

    my $max_y_val;
    {
	my @all;
	push @all, @{$data[$_]} foreach 1..$#data;
	$max_y_val = max_y(@all);
    }


    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => param('title')." in $distro ($inst)",
	y_max_value       => $max_y_val,
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};

get '/graph/*/*/*' => sub {
    my ($distro, $pkg, $inst) = splat;

    my @data = get_nr_for_package($pkg, $distro, $inst);

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend($pkg);


    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "$pkg in $distro ($inst)",
	y_max_value       => max_y(@{$data[1]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};


get '/data/*/*/*' => sub {
    my ($distro,$pkg,$inst) = splat;
    my @data = get_nr_for_package($pkg, $distro, $inst);

    content_type 'text/csv';

    my $r="Date,$pkg in $distro ($inst)\n";

    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_]\n"
    }

    return $r;
};



true;
