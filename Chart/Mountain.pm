#====================================================================
# 
#  Chart::Mountain
# 
#  Inspired by Chart::Lines
#  by davidb bonner 
#  dbonner@cs.bu.edu
# 
#  Updated for 
#  compatibility with 
#  changes to Chart::Base
#  by peter clark
#  ninjaz@webexpress.com
#
# Copyright 1998, 1999 by James F. Miner.
# All rights reserved. 
# This program is free software; you can redistribute it 
# and/or modify it under the same terms as Perl itself. 
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: Mountain.pm,v $ $Revision: 1.4 $ $Date: 2003/02/14 14:16:23 $
# $Author: dassing $
# $Log: Mountain.pm,v $
# Revision 1.4  2003/02/14 14:16:23  dassing
# First setup to cvs
#
#
#====================================================================

package Chart::Mountain;

use Chart::Base 3.0;
use Chart::Lines;

@ISA = qw( Chart::Lines );
$VERSION = $Chart::Base::VERSION;

use strict;

##  Some Mountain chart details:
#
#   The effective y data value for a given x point and dataset
#   is the sum of the actual y data values of that dataset and 
#   all datasets "below" it (i.e., with higher dataset indexes).
# 
#   If the y data value in any dataset is undef or negative for 
#   a given x, then all datasets are treated as missing for that x.
#   
#   The y minimum is always forced to zero.
# 
#   To avoid a dataset area "cutting into" the area of the dataset below
#   it, the y pixel for each dataset point will never be below the y pixel for
#   the same point in the dataset below the dataset.

#   This probably should have a custom legend method, because each 
#   dataset is identified by the fill color (and optional pattern)
#   of its area, not just a line color.  So the legend shou a square
#   of the color and pattern for each dataset.

#===================#
#  private methods  #
#===================#

sub _find_y_range {
    my $self = shift;
    
    #   This finds the maximum point-sum over all x points,
    #   where the point-sum is the sum of the dataset values at that point.
    #   If the y value in any dataset is undef for a given x, then all datasets
    #   are treated as missing for that x.
    
    my $data = $self->{'dataref'};
    my $max = undef;
    for my $i (0..$#{$data->[0]}) {
	my $y_sum = $data->[1]->[$i];
	if ( defined $y_sum && $y_sum >= 0 ) {
	    for my $dataset ( @$data[2..$#$data] ) { # order not important
		my $datum = $dataset->[$i];
		if ( defined $datum && $datum >= 0 ) { 
		    $y_sum += $datum 
		}
		else { # undef or negative, treat all at same x as missing.
		    $y_sum = undef;  
		    last 
		}
	    }
	}
	if ( defined $y_sum ) {
	    $max = $y_sum unless defined $max && $y_sum <= $max;
	}
    }

## new _find_y_scale does this:
#   my $tmp = ($max) ? 10 ** (int (log ($max) / log (10))) : 10;
#   $max = $tmp * (int ($max / $tmp) + 1);

    (0, $max);
}


sub _draw_data {
  my $self = shift;
  my $data = $self->{'dataref'};
  my $misccolor = $self->_color_role_to_rgb('misc');
  my ($x1, $x2, $x3, $y1, $y2, $y3, $mod, $abs_x_max, $abs_y_max, $tan_alpha);
  my ($width, $height, $delta, $delta_num, $map, $t_x_min, $t_x_max, $t_y_min, $t_y_max);
  my ($i, $j, $color, $brush, $zero_offset);
  my $brush_size = $self->{'brush_size'};
  my $pt_size = $self->{'pt_size'};

  # init the imagemap data field if they asked for it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }
  my @xy; # the xy translation of all data points

  # find the delta value between data points, as well
  # as the mapping constant
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
  $delta = $width / ($self->{'num_datapoints'} > 1 ? $self->{'num_datapoints'}-1 : 1);
  $map = $height / ($self->{'max_val'} - $self->{'min_val'});

  #for a xy-plot, use this delta and maybe an offset for the zero-axes
  if ($self->{'xy_plot'}) {
    $delta_num = $width / ($self->{'x_max_val'} - $self->{'x_min_val'});

    if ($self->{'x_min_val'} <= 0 && $self->{'x_max_val'} >= 0) {
       $zero_offset = abs($self->{'x_min_val'}) * abs($delta_num);
    }
    elsif ($self->{'x_min_val'} > 0 || $self->{'x_max_val'} < 0) {
       $zero_offset =  -$self->{'x_min_val'} * $delta_num;
    }
    else {
       $zero_offset = 0;
    }
  }
  
  # get the base x-y values
  if ($self->{'xy_plot'}) {
    $x1 = $self->{'curr_x_min'};
  }
  else {
    $x1 = $self->{'curr_x_min'};
  }
  if ($self->{'min_val'} >= 0 ) {
    $y1 = $self->{'curr_y_max'};
    $mod = $self->{'min_val'};
  }
  elsif ($self->{'max_val'} <= 0) {
    $y1 = $self->{'curr_y_min'};
    $mod = $self->{'max_val'};
  }
  else {
    $y1 = $self->{'curr_y_min'} + ($map * $self->{'max_val'});
    $mod = 0;
    $self->{'surface'}->line(
			$misccolor,
			1,
			$self->{'curr_x_min'}, $y1,
			$self->{'curr_x_max'}, $y1);
  }

  # Work out where to place a line marker
  # = brush_size * 3
  my $marker_delta = $brush_size * 3;
  
	$self->{'surface'}->clip(
		$self->{'curr_x_min'}, $self->{'curr_y_min'},
		$self->{'curr_x_max'}, $self->{'curr_y_max'},
    );

	my @y_values;
	for $j (0..$self->{'num_datapoints'}-1)
	{
		for $i (1..$self->{'num_datasets'})
		{
			# if any column is undefined or less than 0 we can't plot it
			if( !defined $data->[$i][$j] or $data->[$i][$j] < 0 )
			{
				$y_values[$_][$j] = undef for (1..$self->{'num_datasets'});
				last;
			}
			$y_values[$i][$j] += $data->[$_][$j] for (1..$i);
		}
	}

	# draw the lines
	for $i (reverse 1..$self->{'num_datasets'}) {
		# get the color for this dataset, and set the brush
		$color = $self->_color_role_to_rgb('dataset'.($i-1));

		my $shape = $self->{'pointStyle' . $i};
		my $marker_index = 0; # haven't drawn one yet

		push @xy, [];

		my @line;
		# draw every line for this dataset
		for $j (0..$self->{'num_datapoints'}-1) {
			# don't try to draw anything if there's no data
			if( !defined($y_values[$i][$j]) )
			{
				if( scalar(@line) > 1 )
				{
					unshift @line, [$line[0]->[0], $y1];
					push @line, [$line[$#line]->[0], $y1];
					$self->{'surface'}->filled_polygon($color,$brush_size,\@line);
				}
				@line = ();
				push @{$xy[$i]}, [undef,undef];
				next;
			}

			if ($self->{'xy_plot'}) {
				$x3 = $x1 + $delta_num * $data->[0][$j] + $zero_offset;
			}
			else {
				$x3 = $x1 + ($delta * $j);
			}
			$y3 = $y1 - (($y_values[$i][$j] - $mod) * $map);

			# store every point in the graph for the imagemap
			if( $y3 >= $self->{'curr_y_min'} && $y3 < $self->{'curr_y_max'} ) {
				push @{$xy[$i]}, [$x3,$y3];
			}
			else {
				push @{$xy[$i]}, [undef,undef];
			}

			# now draw the line
			push @line, [$x3,$y3];

			# draw the marker
			if( defined($shape) && $x3 > $marker_index ) {
				$self->{'surface'}->point($color,$pt_size,$x3,$y3,$shape);
				$marker_index = $x3 + $marker_delta;
			}
		}
		if( @line > 1 )
		{
			unshift @line, [$line[0]->[0], $y1];
			push @line, [$line[$#line]->[0], $y1];
			$self->{'surface'}->filled_polygon($color,$brush_size,\@line);
		}
		@line = ();
	}

	if( $self->{'imagemap'} ) {
		$self->{'imagemap_data'} = \@xy;
	}

	$self->{'surface'}->reset_clip();

	# and finally box it off
	if( !defined($self->{'draw_box'}) or $self->{'draw_box'} ne 'none' )
	{
		$self->{'surface'}->rectangle(
				$misccolor,
				1,
				$self->{'curr_x_min'}, $self->{'curr_y_min'},
				$self->{'curr_x_max'}, $self->{'curr_y_max'});
	}
}

###############################################################

1;
