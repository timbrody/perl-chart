#====================================================================
#  Chart::Lines
#                                
#  written by david bonner        
#  dbonner@cs.bu.edu              
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: Lines.pm,v $ $Revision: 1.4 $ $Date: 2003/02/14 14:08:24 $
# $Author: dassing $
# $Log: Lines.pm,v $
# Revision 1.4  2003/02/14 14:08:24  dassing
# First setup to cvs
#
#====================================================================

package Chart::Lines;

use Chart::Base 3.0;

@ISA = qw(Chart::Base);
$VERSION = $Chart::Base::VERSION;

use strict;

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#



#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

## finally get around to plotting the data
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

  # get the base x-y values
  $x1 = $self->{'curr_x_min'};

  # find the delta value between data points, as well
  # as the mapping constant
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};

	# x-axis is always discrete for composite
	if( $self->{'component'} || !$self->{xy_plot} )
	{
		my $delta = $width / ($self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
		$width -= $delta;
		$x1 += $delta/2;
	}

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

	# draw the lines
	for $i (1..$self->{'num_datasets'}) {
		# get the color for this dataset, and set the brush
		$color = $self->_color_role_to_rgb('dataset'.($i-1));

		my $shape = $self->{'pointStyle' . $i};
		my $marker_index = 0; # haven't drawn one yet

		push @xy, [];

		my @line;
		# draw every line for this dataset
		for $j (0..$self->{'num_datapoints'}-1) {
			# don't try to draw anything if there's no data
			if( !defined($data->[$i][$j]) )
			{
				if( scalar(@line) > 1 )
				{
					$self->{'surface'}->continuous($color,$brush_size,\@line);
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
			$y3 = $y1 - (($data->[$i][$j] - $mod) * $map);

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
				$self->{'surface'}->point($color,$pt_size,$x3,$y3,0,$shape);
				$marker_index = $x3 + $marker_delta;
			}
		}
		if( @line > 1 )
		{
			$self->{'surface'}->continuous($color,$brush_size,\@line);
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

## be a good module and return 1
1;
