package Chart::CGI;

=head1 NAME

Chart::CGI - a charting CGI service

=head1 SYNOPSIS

=cut

use Chart::Bars;
use Chart::Composite;
use Chart::Lines;
use Chart::Pie;

use Data::Dumper;
use CGI;
use CGI::Carp qw( fatalsToBrowser );

sub handler
{
	my( $r ) = @_;

	my $q = CGI->new;

	my @DATA;

	my @SERIES;

	my @series_labels;
	my @series_types;

	# data series
	for(1..100)
	{
		last unless defined scalar $q->param( "series_$_" );
		my @data = $q->param( "series_$_" );
		if( $#data == 0 )
		{
			@data = split / /, $data[$#data];
		}
		push @SERIES, \@data;

		if( defined $q->param( "series_$_\_label" ) )
		{
			$series_labels[$#SERIES] = $q->param( "series_$_\_label" );
		}
		if( defined $q->param( "series_$_\_type" ) )
		{
			$series_types[$#SERIES] = $q->param( "series_$_\_type" );
		}
	}

	# x-axis labels
	my @labels = $q->param( "x_label" );

	# default to bars
	for(0..$#SERIES)
	{
		if( !defined $series_types[$_] || $series_types[$_] !~ /^lines|bars|stackedbars$/i )
		{
			$series_types[$_] = "bars";
		}
	}

	# find the first two unique types
	my %composite_index;
	my @composite_types;
	for( @series_types )
	{
		next if exists $composite_index{$_};
		push @composite_types, ["\u$_", []];
		$composite_index{$_} = $#composite_types;
	}

	for(0..$#series_types)
	{
		my $type = $series_types[$_];
		push @{$composite_types[$composite_index{$type}]->[1]}, $_+1;
	}
	
	# chart size (in pixels)
	my $width = $q->param( "width" ) || 400;
	my $height = $q->param( "height" ) || 300;
	
	$width = 400 if $width =~ /\D/ or $width < 0 or $width > 1024;
	$height = 300 if $height =~ /\D/ or $height < 0 or $height > 1024;
	
	my $chart;

	if( $#composite_types == 0 )
	{
		my $type = $composite_types[0][0];
		$type = "Chart::$type";
		$chart = $type->new( $width, $height );
	}
	else
	{
		$chart = Chart::Composite->new( $width, $height );
		$chart->set( "composite_info", \@composite_types );
	}

	# settings
	for( qw( legend same_y_axes min_val min_val1 min_val2 max_val1 max_val2 y_axis_scale y_axis_scale1 y_axis_scale2 brush_size bar_border_size title ) )
	{
		if( defined $q->param( $_ ) )
		{
			$chart->set( $_, $q->param( $_ ) );
		}
	}

	my @custom_x_ticks;
	for(my $i = 0; $i < @labels; ++$i)
	{
		if( $labels[$i] ne "" )
		{
			push @custom_x_ticks, $i;
		}
	}
	if( @custom_x_ticks < @labels )
	{
		$chart->set( custom_x_ticks => \@custom_x_ticks );
	}

	$chart->set( "legend_labels", \@series_labels );

	$chart->set( "legend_font", "/home/tools/chart2/fonts/Vera.ttf" );

	print $q->header( "image/png" );

	print $chart->png( \*STDOUT, [\@labels, @SERIES] );
}

sub render_png
{
	my( $q, $chart ) = @_;

	print $q->header( "image/png" ),
		$chart->png();
}

1;
