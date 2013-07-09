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

sub get_psvsmaria_data($$)
{
    my ($distro, $version) = @_;
    my %p = get_popcons($distro);

    my @pdata = (get_nr_for_package("percona-server-server-$version", $distro));

    my @mdata;
    if ($version == '5.6')
    {
	@mdata = (get_nr_for_package("mariadb-server-10.0", $distro));
    }
    else
    {
	@mdata= (get_nr_for_package("mariadb-server-$version", $distro));
    }

    foreach (0..$#{$pdata[0]})
    {
	$p{$pdata[0][$_]}{"percona-server-server-$version"} = $pdata[1][$_];
    }

    foreach (0..$#{$mdata[0]})
    {
	$p{$mdata[0][$_]}{"mariadb-server-$version"} = $mdata[1][$_];
    }

    my @data = ([],[],[]);
    foreach(sort keys %p)
    {
	push $data[0], $_;
	push $data[1], $p{$_}{"percona-server-server-$version"} || 0;
	push $data[2], $p{$_}{"mariadb-server-$version"} || 0;
    }

    return @data;
}


get '/data/ubuntu/ps51vsmaria51' => sub {
    my @data = get_psvsmaria_data('Ubuntu','5.1');

    content_type 'text/plain';

    my $r="Date,PS 5.1, MariaDB 5.1\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_]\n"
    }

    return $r;
};

get '/data/ubuntu/ps55vsmaria55' => sub {
    my @data = get_psvsmaria_data('Ubuntu','5.5');

    content_type 'text/plain';

    my $r="Date,PS 5.5, MariaDB 5.5\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_]\n"
    }

    return $r;
};

get '/data/ubuntu/ps56vsmaria10' => sub {
    my @data = get_psvsmaria_data('Ubuntu','5.6');

    content_type 'text/plain';

    my $r="Date,PS 5.6, MariaDB 10.0\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_]\n"
    }

    return $r;
};


get '/graph/ubuntu/ps51vsmaria51' => sub {

    my @data = get_psvsmaria_data('Ubuntu', '5.1');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.1', 'MariaDB 5.1');

    my $max_y= int((max(@{$data[1]}, @{$data[2]}) + 10) / 10) * 10;

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.1 vs MariaDB 5.1 in Ubuntu",
	y_max_value       => $max_y,
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

    my @data = get_psvsmaria_data('Ubuntu', '5.5');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.5', 'MariaDB 5.5');

    my $max_y= int((max(@{$data[1]}, @{$data[2]}) + 10) / 10) * 10;

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.5 vs MariaDB 5.5 in Ubuntu",
	y_max_value       => $max_y,
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

    my @data = get_psvsmaria_data('Ubuntu','5.6');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.6', 'MariaDB 10.0');

    my $max_y= int((max(@{$data[1]}, @{$data[2]}) + 10) / 10) * 10;

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.6 vs MariaDB 10.0 in Ubuntu",
	y_max_value       => $max_y,
	y_tick_number     => 10,
#	y_label_skip      => 4,
	x_label_skip      => 2,
	line_width        => 2,
	) or die $graph->error;
    
    my $gd = $graph->plot(\@data) or die $graph->error;

    content_type 'png';
    return $gd->png;
};



sub get_all_data($$)
{
    my ($distro, $version) = @_;

    my %p = get_popcons($distro);

    my @pdata = (get_nr_for_package("percona-server-server-$version", $distro));

    my @mdata;
    if ($version == '5.6')
    {
	@mdata = (get_nr_for_package("mariadb-server-10.0", $distro));
    }
    else
    {
	@mdata= (get_nr_for_package("mariadb-server-$version", $distro));
    }

    my @odata = (get_nr_for_package("mysql-server-$version", $distro));

    foreach (0..$#{$pdata[0]})
    {
	$p{$pdata[0][$_]}{'percona-server-server-$version'} = $pdata[1][$_];
    }

    foreach (0..$#{$mdata[0]})
    {
	$p{$mdata[0][$_]}{'mariadb-server-$version'} = $mdata[1][$_];
    }

    foreach (0..$#{$odata[0]})
    {
	$p{$odata[0][$_]}{'mysql-server-$version'} = $odata[1][$_];
    }

    my @data = ([],[],[],[]);
    foreach(sort keys %p)
    {
	push $data[0], $_;
	push $data[1], $p{$_}{'percona-server-server-$version'} || 0;
	push $data[2], $p{$_}{'mariadb-server-$version'} || 0;
	push $data[3], $p{$_}{'mysql-server-$version'} || 0;
    }

    return @data;
}

get '/data/ubuntu/all51' => sub {
    my @data = get_all_data('Ubuntu','5.1');

    content_type 'text/plain';

    my $r="Date,PS 5.1, MariaDB 5.1,MySQL 5.1\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_],$data[3][$_]\n"
    }

    return $r;
};

get '/data/ubuntu/all55' => sub {
    my @data = get_all_data('Ubuntu','5.5');

    content_type 'text/plain';

    my $r="Date,PS 5.5, MariaDB 5.5,MySQL 5.5\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_],$data[3][$_]\n"
    }

    return $r;
};

get '/data/ubuntu/all56' => sub {
    my @data = get_all_data('Ubuntu','5.6');

    content_type 'text/plain';

    my $r="Date,PS 5.6, MariaDB 10.0,MySQL 5.6\n";
    foreach(0..$#{$data[0]})
    {
	$r.= "$data[0][$_],$data[1][$_],$data[2][$_],$data[3][$_]\n"
    }

    return $r;
};


get '/graph/ubuntu/all51' => sub {

    my @data = get_all_data('Ubuntu', '5.1');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.1', 'MariaDB 5.1', 'Oracle MySQL 5.1');

    my $max_y= int((max(@{$data[1]}, @{$data[2]}, @{$data[3]}) + 10) / 10) * 10;

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.1 vs MariaDB 5.1 vs Oracle MySQL 5.1 in Ubuntu",
	y_max_value       => $max_y,
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

    my @data = get_all_data('Ubuntu','5.5');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.5', 'MariaDB 5.5', 'Oracle MySQL 5.5');

    my $max_y= int((max(@{$data[1]}, @{$data[2]}, @{$data[3]}) + 10) / 10) * 10;

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.5 vs MariaDB 5.5 vs Oracle MySQL 5.5 in Ubuntu",
	y_max_value       => $max_y,
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

    my @data = get_all_data('Ubuntu','5.6');

    my $graph = GD::Graph::lines->new(900, 550);

    $graph->set_legend('PS 5.6', 'MariaDB 10.0', 'Oracle MySQL 5.6');

    my $max_y= int((max(@{$data[1]}, @{$data[2]}, @{$data[3]}) + 10) / 10) * 10;

    $graph->set(
	x_label           => 'Date',
	y_label           => 'Installs',
	title             => "PS5.6 vs MariaDB 10.0 vs Oracle MySQL 5.6 in Ubuntu",
	y_max_value       => $max_y,
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
