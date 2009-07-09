#!/usr/bin/perl -w

use Chart::Mountain;         
use File::Spec;
use Math::Trig;

print "1..1\n";

my( @x, @y1, @y2 );

for(my $i = -1; $i < 1; $i+=0.01)
{
	push @x, $i * pi;
	push @y1, sin($x[$#x]) + 1;
	push @y2, cos($x[$#x]) + 1;
}

my $chart = Chart::Mountain->new();

$chart->set( xy_plot => "true" );
$chart->set( legend_labels => [qw( sin cos )] );

$chart->png( "samples/mountain_3.png", [\@x, \@y1, \@y2] );

print "ok\n";

exit (0);

