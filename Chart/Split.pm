#====================================================================
#  Chart::Split
#
#  written by Chart-Group
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: Split.pm,v $ $Revision: 1.2 $ $Date: 2003/02/14 14:25:30 $
# $Author: dassing $
# $Log: Split.pm,v $
# Revision 1.2  2003/02/14 14:25:30  dassing
# First setup to cvs
#
#====================================================================

package Chart::Split;

use Chart::Base;
use Chart::Lines;
use Carp;
use POSIX;

@ISA = qw(Chart::Lines);
$VERSION = $Chart::Base::VERSION;

use strict;

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#



#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

sub _init {
	my $self = shift;

	$self->SUPER::_init( @_ );

	$self->{xy_plot} = TRUE;
}

sub _check_data {
	my $self = shift;
	my $data = $self->{dataref};

    my $x_interval = $self->{'interval'} || 1;
    my $start = $self->{'start'};

	my $x_max = $data->[0]->[0];

    foreach (@{$data->[0]}) {
      $x_max = $_ if $_ > $x_max;
    }

    my $lines = ceil(($x_max-$start)/$x_interval) || 1;

	$self->{num_lines} = $lines;

	$self->SUPER::_check_data( @_ );
}

sub _find_y_scale {
	my $self = shift;

	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );

	my @labels;

	my( $maxtickLabelLen, $maxtickLabelWidth, $maxtickLabelHeight ) = (0,0,0);
	foreach my $i (0 .. $self->{num_lines}) {
		my $label = $self->{f_y_tick}->($i);
		push @labels, $label;
		my( $w, $h ) = $self->{surface}->string_bounds($font, $fsize, $label);
		$maxtickLabelLen = length($label) if length($label) > $maxtickLabelLen;
		$maxtickLabelWidth = $w if $w > $maxtickLabelWidth;
		$maxtickLabelHeight = $h if $h > $maxtickLabelHeight;
	}

	my( $d_min, $d_max ) = $self->_find_y_range;

	$self->{'min_val'} = $d_min;
	$self->{'max_val'} = $d_max;
	$self->{'y_ticks'} = $self->{num_lines};
	$self->{y_tick_labels} = \@labels;
	$self->{'y_tick_label_length'} = $maxtickLabelLen;
	$self->{'y_tick_label_width'} = $maxtickLabelWidth;
	$self->{'y_tick_label_height'} = $maxtickLabelHeight;
}

# x_scale for a split-chart is start .. interval
sub _find_x_scale {
	my $self = shift;

	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
	my ($i, $j);
	my ($p_min, $p_max, $f_min, $f_max);
	my ($tickInterval, $tickCount, $skip);
	my @tickLabels;
	my $maxtickLabelLen = 0;
	my $maxtickLabelWidth = 0;
	my $maxtickLabelHeight = 0;

#find the dataset min and max
	my $d_min = $self->{start} || 0;
	my $d_max = $self->{interval} || 1;

# Force the inclusion of zero if the user has requested it.
	if( $self->{'include_zero'} )    {
		if( ($d_min * $d_max) > 0 ) {	# If both are non zero and of the same sign.
			if( $d_min > 0 ) {	# If the whole scale is positive.
				$d_min = 0;
			}
			else	{			# The scale is entirely negative.
				$d_max = 0;
			}
		}
	}

# Calculate the width of the dataset. (posibly modified by the user)
	my $d_width = $d_max - $d_min;

# If the width of the range is zero, forcibly widen it
# (to avoid division by zero errors elsewhere in the code).
	if( 0 == $d_width )  {
		$d_min--;
		$d_max++;
		$d_width = 2;
	}

# Descale the range by converting the dataset width into
# a floating point exponent & mantisa pair.
	my( $rangeExponent, $rangeMantisa ) = $self->_sepFP( $d_width );
	my $rangeMuliplier = 10 ** $rangeExponent;

# Find what tick
# to use & how many ticks to plot,
# round the plot min & max to suatable round numbers.
	($tickInterval, $tickCount, $p_min, $p_max)
		= $self->_calcXTickInterval($d_min/$rangeMuliplier, $d_max/$rangeMuliplier,
				$f_min, $f_max,
				$self->{'min_x_ticks'}, $self->{'max_x_ticks'});
# Restore the tickInterval etc to the correct scale
	$_ *= $rangeMuliplier foreach($tickInterval, $p_min, $p_max);

	my $f_x_tick = $self->{f_x_tick};
	if( !defined $f_x_tick || $self->{f_x_tick} == \&_default_f_tick )
	{
# Get the precision for the labels
		my $precision = $self->{'precision'};
		$precision = 0 if ($tickInterval-int($tickInterval) == 0);

		$f_x_tick = sub { sprintf("%.".$precision."f", $_[0] ) };
	}

# Now sort out an array of tick labels.
	for( my $labelNum = $d_min; $labelNum<=$d_max; $labelNum+=$tickInterval ) {
		my $labelText = &$f_x_tick( $labelNum );
		push @tickLabels, $labelText;

		$maxtickLabelLen = length $labelText if $maxtickLabelLen < length $labelText;
		my ($w,$h) = $self->string_bounds($font,$fsize,$labelText);
		$maxtickLabelWidth = $w if $w > $maxtickLabelWidth;
		$maxtickLabelHeight = $h if $h > $maxtickLabelHeight;
	}

# Store the calculated data.
	$self->{'x_min_val'} = $d_min;
	$self->{'x_max_val'} = $d_max;
	$self->{'x_tick_labels'} = \@tickLabels;
	$self->{'x_tick_label_length'} = $maxtickLabelLen;
	$self->{'x_tick_label_width'} = $maxtickLabelWidth;
	$self->{'x_tick_label_height'} = $maxtickLabelHeight;
	$self->{'x_number_ticks'} = $tickCount;
}

sub _draw_y_ticks {
	my $self = shift;
	my $side = shift || 'left';
	my $data = $self->{'dataref'};
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
	my $textcolor = $self->_color_role_to_rgb('text');
	my $misccolor = $self->_color_role_to_rgb('misc');
	my @labels = @{$self->{'y_tick_labels'}};
	my $num_points = $self->{'num_datapoints'};
	my ($w, $h);
	my ($x_start, $x, $y_start, $y);
	my ($height, $label);
	my ($s, $f);
	$self->{grid_data}->{'y'} = [];
	$self->{grid_data}->{'y2'} = [];
	my $line_size = $self->{line_size};

# find the height
	$height = $self->{'curr_y_max'} - $self->{'curr_y_min'};

	my $lines = $self->{num_lines};

#get the space between two lines
	my $delta = $height / $lines;

	my $label_len = $self->{y_tick_label_width};

	return if $lines == 1;

#now draw them
	if ( $side =~ /^right$/i ) {
#get the starting point
		$x_start = $self->{'curr_x_max'};
		$y_start = $self->{'curr_y_min'};

#draw the labels
		for $label (0..$lines-1) {
			$x = $x_start - $self->{'text_space'} - $label_len*$w;
			$y = $y_start + $label*$delta + $delta/2 -$h/2;
			$self->{'gd_obj'}->string($font, $x, $y, $label, $textcolor);
		}

#draw the ticks
		for $label ( 0..$lines) {
			$x = $x_start - $self->{'text_space'} *2 - $label_len*$w - $self->{'tick_len'};
			$y = $y_start + $label*$delta;
			$self->{'gd_obj'} ->line( $x_start-$self->{'text_space'}, $y, $x, $y, $misccolor);
#add data for grid_lines
			push @{$self->{grid_data} ->{'y'}}, $y;
		}

#update the borders
		$self->{'curr_x_max'} = $x_start - $self->{'text_space'}*2- $label_len*$w-$self->{'tick_len'};

	}

	elsif ( $side =~ /^both$/i) {
#get the starting point
		$x_start = $self->{'curr_x_min'};
		$y_start = $self->{'curr_y_min'};

#first the left side
#draw the labels
		for $label (0..$lines-1) {
			$x = $self->{'curr_x_min'}+$self->{'text_space'}*2;
			$y = $y_start+ $label*$delta + $delta/2 -$h/2;
			$self->{'gd_obj'}->string($font, $x, $y, $self->{'f_y_tick'}->($label), $textcolor);
		}
#draw the ticks
		for $label (0..$lines) {
			$x = $x_start + $self->{'text_space'}*2+ $label_len*$w+$self->{'tick_len'};
			$y = $y_start+ $label*$delta ;
			$self->{'gd_obj'}->line( $x_start+$self->{'text_space'}, $y, $x, $y, $misccolor);
		}

#then the right side
#get the starting point
		$x_start = $self->{'curr_x_max'};
		$y_start = $self->{'curr_y_min'};

#draw the labels
		for $label (0..$lines-1) {
			$x = $x_start - $self->{'text_space'} - $label_len*$w;
			$y = $y_start + $label*$delta + $delta/2 -$h/2;
			$self->{'gd_obj'}->string($font, $x, $y, $self->{'f_y_tick'}->($label), $textcolor);
		}

#draw the ticks
		for $label ( 0..$lines) {
			$x = $x_start - $self->{'text_space'} *2 - $label_len*$w - $self->{'tick_len'};
			$y = $y_start + $label*$delta;
			$self->{'gd_obj'} ->line( $x_start-$self->{'text_space'}, $y, $x, $y, $misccolor);
#add data for grid_lines
			push @{$self->{grid_data} ->{'y'}}, $y;
		}
#update the borders
		$self->{'curr_x_min'} += $self->{'text_space'}*2 + $label_len*$w+$self->{'tick_len'};
		$self->{'curr_x_max'} = $x_start -$self->{'text_space'}*2 - $label_len*$w-$self->{'tick_len'};

	}
	else {

#get the starting point
#draw the labels
		foreach my $i (0..$lines-1) {
			$label = $labels[$i];
			($w, $h) = $self->{surface}->string_bounds($font, $fsize, $label);
			$x = $self->{'curr_x_min'} + $self->{'text_space'}*2;
			$y = $self->{curr_y_min} + $i*$delta + $delta/2 + $h/2;
			$self->{'surface'}->string($textcolor, $font, $fsize, $x, $y, 0, $label);
		}
#draw the ticks
		foreach my $i (0..$lines) {
			$x = $self->{curr_x_min} + $self->{y_tick_label_width} + $self->{'tick_len'} + $self->{'text_space'}*2;
			$y = $self->{curr_y_min} + $i*$delta;
			$self->{'surface'}->line($misccolor, $line_size, $self->{curr_x_min}, $y, $x, $y);
#this is also where we have to draw the grid_lines
			push @{$self->{grid_data}->{'y'}} , $y;
		}
#update the borders
		$self->{'curr_x_min'} += $self->{'y_tick_label_width'} + $self->{'tick_len'} + $self->{'text_space'}*2;
	}

#finally return
	return 1;
}

sub _draw_data {
	my $self = shift;
    my $data = $self->{'dataref'};
    my $num_datapoints = $self->{'num_datapoints'} || 1;
    my $num_datasets = $self->{'num_datasets'} || 1;
	my $misccolor = $self->_color_role_to_rgb('misc');
	my $line_size = $self->{line_size};

    # find the height and the width
    my $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
    my $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};

    # init the imagemap data field if they asked for it
	if ($self->{'imagemap'}) {
		$self->{'imagemap_data'} = [];
	}

	return if !$width || !$height; # no space to draw in

    my $x_interval = $self->{'interval'} || 1;
    my $start = $self->{'start'};

	my $x_max = $data->[0]->[0];

    foreach (@{$data->[0]}) {
      $x_max = $_ if $_ > $x_max;
    }

    my $lines = ceil(($x_max-$start)/$x_interval) || 1;

	my $delta_lines = $height / $lines;
	my $delta_datasets = $delta_lines / $num_datasets;

	foreach my $line (0..$lines-1) {
		foreach my $dataset (1..$num_datasets) {
			local $self->{curr_y_min} = $self->{curr_y_min};
			local $self->{curr_y_max} = $self->{curr_y_min};
			local $self->{dataref} = [];
			local $self->{num_datasets} = 1;
			local $self->{num_datapoints} = 0;
			local $self->{x_min_val} = $x_interval * $line;
			local $self->{x_max_val} = $x_interval * ($line+1);
			local $self->{colors}->{dataset0} = $self->_color_role_to_rgb('dataset'.($dataset-1));
			local $self->{draw_box} = 'none';

			# calculate the line-chart boundaries
			$self->{curr_y_min} += $delta_lines * $line;
			$self->{curr_y_min} += $delta_datasets * ($dataset-1);
			$self->{curr_y_max} = $self->{curr_y_min} + $delta_datasets;

			# populate the section of data for this line-chart
			my $x_min = $self->{x_min_val};
			my $x_max = $self->{x_max_val};
			foreach my $i (0..$num_datapoints-1) {
				my $value = $data->[0]->[$i];
				next if !defined $value;
				next if $value < $x_min;
				last if $value > $x_max;
				push @{$self->{dataref}->[0]}, $value;
				push @{$self->{dataref}->[1]}, $data->[$dataset]->[$i];
			}
			$self->{num_datapoints} = scalar(@{$self->{dataref}->[1]});

			$self->SUPER::_draw_data;
		}
	}

	# and finally box it off
	if( !defined($self->{'draw_box'}) or $self->{'draw_box'} ne 'none' )
	{
		$self->{'surface'}->rectangle(
				$misccolor,
				$line_size,
				$self->{'curr_x_min'}, $self->{'curr_y_min'},
				$self->{'curr_x_max'}, $self->{'curr_y_max'});
	}
}

#be a good modul and return 1
1;

