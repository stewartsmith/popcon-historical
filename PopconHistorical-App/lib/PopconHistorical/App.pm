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
    template 'index', { 'distros' => [get_distros()] };
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


sub get_nr_for_package($$)
{
    my ($pkg, $distro) = @_;
    my $sql= "select popcon_date,inst_nr from popcon_package LEFT JOIN popcon ON popcon.id=popcon_id LEFT JOIN package ON package_id=package.id where package=? and distro=? order by package, popcon_date";
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
    my ($distro, @packages) = @_;

    my %p = get_popcons($distro);

    my @rdata;

    foreach (@packages)
    {
	push @rdata, [get_nr_for_package($_,$distro)];
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

get '/data/ubuntu/xtrabackup' => sub {
    my @data = get_nr_for_package('percona-xtrabackup','Ubuntu');

    content_type 'text/plain';

    my $r="Date,percona-xtrabackup\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_]\n"
    }

    return $r;
};

get '/graph/ubuntu/xtrabackup' => sub {
    my @data = get_nr_for_package('percona-xtrabackup','Ubuntu');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('Percona Xtrabackup');


    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "Percona XtraBackup in Ubuntu",
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


get '/data/ubuntu/pt' => sub {
    my @data = get_all_data('Ubuntu', 'percona-toolkit', 'maatkit');

    content_type 'text/plain';

    my $r="Date,percona-toolkit, maatkit\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_]\n"
    }

    return $r;
};

get '/graph/ubuntu/pt' => sub {
    my @data = get_all_data('Ubuntu', 'percona-toolkit', 'maatkit');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('Percona Toolkit', 'Maatkit');

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "Percona Toolkit vs Maatkit in Ubuntu",
	y_max_value       => max_y(@{$data[1]}, @{$data[2]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};


get '/data/ubuntu/backup' => sub {
    my @data = get_all_data('Ubuntu', 'percona-xtrabackup', 'mydumper', 'mylvmbackup');

    content_type 'text/plain';

    my $r="Date,percona-xtrabackup, mydumper, mylvmbackup\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_],$data[3][$_]\n"
    }

    return $r;
};


get '/graph/ubuntu/backup' => sub {
    my @data = get_all_data('Ubuntu', 'percona-xtrabackup', 'mydumper', 'mylvmbackup');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('Percona Xtrabackup', 'mydumper', 'mylvmbackup');

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "MySQL backup solutions in Ubuntu",
	y_max_value       => max_y(@{$data[1]}, @{$data[2]}, @{$data[3]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};


get '/data/ubuntu/ps51vsmaria51' => sub {
    my @data = get_all_data('Ubuntu', 'percona-server-server-5.1', 'mariadb-server-5.1', 'mariadb-server-5.2', 'mariadb-server-5.3');

    content_type 'text/plain';

    my $r="Date,PS 5.1, MariaDB 5.1, MariaDB 5.2, MariaDB 5.3\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_],$data[3][$_],$data[4][$_]\n"
    }

    return $r;
};

get '/data/ubuntu/ps55vsmaria55' => sub {
    my @data = get_all_data('Ubuntu', 'percona-server-server-5.5', 'mariadb-server-5.5');

    content_type 'text/plain';

    my $r="Date,PS 5.5, MariaDB 5.5\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_]\n"
    }

    return $r;
};

get '/data/ubuntu/ps56vsmaria10' => sub {
    my @data = get_all_data('Ubuntu','percona-server-server-5.6', 'mariadb-server-10.0');

    content_type 'text/plain';

    my $r="Date,PS 5.6, MariaDB 10.0\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_]\n"
    }

    return $r;
};


get '/graph/ubuntu/ps51vsmaria51' => sub {

    my @data = get_all_data('Ubuntu', 'percona-server-server-5.1', 'mariadb-server-5.1', 'mariadb-server-5.2', 'mariadb-server-5.3');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.1', 'MariaDB 5.1', 'MariaDB 5.2', 'MariaDB 5.3');

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.1 vs MariaDB 5.[123] in Ubuntu",
	y_max_value       => max_y(@{$data[1]}, @{$data[2]}, @{$data[3]}, @{$data[4]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};

get '/graph/ubuntu/ps55vsmaria55' => sub {

    my @data = get_all_data('Ubuntu', 'percona-server-server-5.5', 'mariadb-server-5.5');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.5', 'MariaDB 5.5');

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.5 vs MariaDB 5.5 in Ubuntu",
	y_max_value       => max_y(@{$data[1]}, @{$data[2]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};

get '/graph/ubuntu/ps56vsmaria10' => sub {

    my @data = get_all_data('Ubuntu','percona-server-server-5.6', 'mariadb-server-10.0');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.6', 'MariaDB 10.0');

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.6 vs MariaDB 10.0 in Ubuntu",
	y_max_value       => max_y(@{$data[1]}, @{$data[2]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};


get '/data/ubuntu/all51' => sub {
    my @data = get_all_data('Ubuntu', 'percona-server-server-5.1', 'mariadb-server-5.1', 'mariadb-server-5.2', 'mariadb-server-5.3', 'mysql-server-5.1');

    content_type 'text/plain';

    my $r="Date,PS 5.1, MariaDB 5.1, MariaDB 5.2, MariaDB 5.3, MySQL 5.1\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_],$data[3][$_],$data[4][$_],$data[5][$_]\n"
    }

    return $r;
};

get '/data/ubuntu/all55' => sub {
    my @data = get_all_data('Ubuntu', 'percona-server-server-5.5', 'mariadb-server-5.5', 'mysql-server-5.5');

    content_type 'text/plain';

    my $r="Date,PS 5.5, MariaDB 5.5,MySQL 5.5\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_],$data[3][$_]\n"
    }

    return $r;
};

get '/data/ubuntu/all56' => sub {
    my @data = get_all_data('Ubuntu', 'percona-server-server-5.6', 'mariadb-server-10.0', 'mysql-server-5.6');

    content_type 'text/plain';

    my $r="Date,PS 5.6, MariaDB 10.0,MySQL 5.6\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_],$data[3][$_]\n"
    }

    return $r;
};


get '/graph/ubuntu/all51' => sub {

    my @data = get_all_data('Ubuntu', 'percona-server-server-5.1', 'mariadb-server-5.1', 'mariadb-server-5.2', 'mariadb-server-5.3', 'mysql-server-5.1');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.1', 'MariaDB 5.1', 'MariaDB 5.2', 'MariaDB 5.3', 'Oracle MySQL 5.1');

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.1 vs MariaDB 5.[123] vs Oracle MySQL 5.1 in Ubuntu",
	y_max_value       => max_y(@{$data[1]}, @{$data[2]}, @{$data[3]}, @{$data[4]}, @{$data[5]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};

get '/graph/ubuntu/all55' => sub {

    my @data = get_all_data('Ubuntu', 'percona-server-server-5.5', 'mariadb-server-5.5', 'mysql-server-5.5');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.5', 'MariaDB 5.5', 'Oracle MySQL 5.5');

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.5 vs MariaDB 5.5 vs Oracle MySQL 5.5 in Ubuntu",
	y_max_value       => max_y(@{$data[1]}, @{$data[2]}, @{$data[3]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};

get '/graph/ubuntu/all56' => sub {

    my @data = get_all_data('Ubuntu', 'percona-server-server-5.6', 'mariadb-server-5.6', 'mysql-server-5.6');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.6', 'MariaDB 10.0', 'Oracle MySQL 5.6');

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.6 vs MariaDB 10.0 vs Oracle MySQL 5.6 in Ubuntu",
	y_max_value       => max_y(@{$data[1]}, @{$data[2]}, @{$data[3]}),
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};


true;
