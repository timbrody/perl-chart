#====================================================================
#  Chart::Points
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
# $RCSfile: Points.pm,v $ $Revision: 1.4 $ $Date: 2003/02/14 14:22:05 $
# $Author: dassing $
# $Log: Points.pm,v $
# Revision 1.4  2003/02/14 14:22:05  dassing
# First setup to cvs
#
#====================================================================

package Chart::Points;

use Chart::Base;

@ISA = qw(Chart::Base);
$VERSION = $Chart::Base::VERSION;

use strict;

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#



#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

sub _init
{
	my $self = shift;

	my $rc = $self->SUPER::_init( @_ );

	# backwards-compatibility
	for(1..20) {
		$self->{'pointStyle' . $_} = 'circle';
	}

	return $rc;
}

## finally get around to plotting the data
sub _draw_data {
	my $self = shift;
	my $data = $self->{'dataref'};
	my $misccolor = $self->_color_role_to_rgb('misc');
	my ($x1, $x2, $x3, $y1, $y2, $y3, $mod);
	my ($width, $height, $delta, $map, $delta_num, $zero_offset);
	my ($i, $j, $color, $brush);
	my $diff;

	my $pt_size = $self->{pt_size};

# init the imagemap data field if they want it
	if ($self->{'imagemap'}) {
		$self->{'imagemap_data'} = [];
	}

# find the delta value between data points, as well
# as the mapping constant
	$width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
	$height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
	$delta = $width / ( $self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
	$diff = ($self->{'max_val'} - $self->{'min_val'});
	$diff = 1 if $diff == 0;
	$map = $height / $diff;

#for a xy-plot, use this delta and maybe an offset for the zero-axes
	if ($self->{'xy_plot'}) {
		$diff = ($self->{'x_max_val'} - $self->{'x_min_val'});
		$diff = 1 if $diff == 0;
		$delta_num = $width / $diff;

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
		$x1 = $self->{'curr_x_min'} + $delta / 2;
	}
	if ($self->{'min_val'} >= 0) {
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
		$self->{'surface'}->line ($misccolor, $self->{brush_size}, $self->{'curr_x_min'}, $y1, $self->{'curr_x_max'}, $y1);
	}

# draw the points
	for $i (1..$self->{'num_datasets'}) {
# get the color for this dataset, and set the brush
		$color = $self->_color_role_to_rgb('dataset'.($i-1));
		my $shape = $self->{'pointStyle'.$i};

# draw every point for this dataset
		for $j (0..$self->{'num_datapoints'}) {
# don't try to draw anything if there's no data
			if (defined ($data->[$i][$j])) {
				if ($self->{'xy_plot'}) {
					$x2 = $x1 + $delta_num * $data->[0][$j] + $zero_offset;
					$x3 = $x2 ;
				}
				else {
					$x2 = $x1 + ($delta * $j);
					$x3 = $x2;
				}
				$y2 = $y1 - (($data->[$i][$j] - $mod) * $map);
				$y3 = $y2;

# draw the point only if it is within the chart borders
				if ($data->[$i][$j] <= $self->{'max_val'} && $data->[$i][$j] >= $self->{'min_val'}) {
					$self->{'surface'}->point($color, $pt_size, $x2, $y2, 0, $shape);
				}

# store the imagemap data if they asked for it
				if ($self->{'imagemap'}) {
					$self->{'imagemap_data'}->[$i][$j] = [ $x2, $y2 ];
				}
			}
		}
	}

# and finaly box it off 
	$self->{'surface'}->rectangle ($misccolor, $self->{line_size},
			$self->{'curr_x_min'},
			$self->{'curr_y_min'},
			$self->{'curr_x_max'},
			$self->{'curr_y_max'});

	return;

}

## be a good module and return 1
1;
