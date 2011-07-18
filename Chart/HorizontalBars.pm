#====================================================================
#  Chart::HorizontalBars
#
#  written by Chart-Group
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: HorizontalBars.pm,v $ $Revision: 1.2 $ $Date: 2003/02/14 14:04:40 $
# $Author: dassing $
# $Log: HorizontalBars.pm,v $
# Revision 1.2  2003/02/14 14:04:40  dassing
# First setup
#
#====================================================================

package Chart::HorizontalBars;

use Chart::Base;
use Chart::Bars 3.0;
use Carp;

@ISA = qw(Chart::Bars);
$VERSION = $Chart::Base::VERSION;

use strict;
#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#



#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

sub _draw_x_ticks {
	my $self = shift;
	my $data = $self->{'dataref'};

	my @labels = @{$self->{'y_tick_labels'}};

	local $self->{dataref}->[0] = \@labels;
	local $self->{num_datapoints} = @labels;
	local $self->{xy_plot} = TRUE; # line up start/end
	local( $self->{x_tick_label_width}, $self->{y_tick_label_width} )
	   = ( $self->{y_tick_label_width}, $self->{x_tick_label_width} );
	local( $self->{x_tick_label_height}, $self->{y_tick_label_height} )
	   = ( $self->{y_tick_label_height}, $self->{x_tick_label_height} );

	$self->SUPER::_draw_x_ticks;
}

sub _draw_y_ticks {
	my( $self, $side ) = @_;
	my $data = $self->{dataref};

	my $height = $self->{curr_y_max} - $self->{curr_y_min};
	my @labels = @{$data->[0]};
	my $delta = $height / @labels;

	local $self->{curr_y_max} = $self->{curr_y_max} - $delta/2;
	local $self->{curr_y_min} = $self->{curr_y_min} + $delta/2;

	local $self->{min_val} = 0;
	local $self->{max_val} = @labels;
	local $self->{y_tick_labels} = \@labels;
	local $self->{y_ticks} = @labels;
	local( $self->{x_tick_label_width}, $self->{y_tick_label_width} )
	   = ( $self->{y_tick_label_width}, $self->{x_tick_label_width} );
	local( $self->{x_tick_label_height}, $self->{y_tick_label_height} )
	   = ( $self->{y_tick_label_height}, $self->{x_tick_label_height} );

	$self->SUPER::_draw_y_ticks( $side );
}

## finally get around to plotting the data
sub _draw_data {
  my $self = shift;
  my $data = $self->{'dataref'};
  my $misccolor = $self->_color_role_to_rgb('misc');
  my ($x1, $x2, $x3, $y1, $y2, $y3);
  my $cut = 0;
  my ($width, $height, $delta1, $delta2, $map, $mod);
  my $pink = [255,0,255];
  my ($i, $j, $color);
  my $line_size = $self->{'line_size'};

  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  my $bar_border_size = $self->{'bar_border_size'};
  $bar_border_size = $self->{'line_size'} unless defined $bar_border_size;
  
  # find both delta values ($delta1 for stepping between different
  # datapoint names, $delta2 for setpping between datasets for that
  # point) and the mapping constant
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
  $delta1 = $height / ($self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
  $map = $width / ($self->{'max_val'} - $self->{'min_val'});
  if ($self->{'spaced_bars'}) {
    $delta2 = $delta1 / ($self->{'num_datasets'} + 2);
  }
  else {
    $delta2 = $delta1 / $self->{'num_datasets'};
  }

  # get the base x-y values
  $y1 = $self->{'curr_y_max'} - $delta2;
  if ($self->{'min_val'} >= 0) {
    $x1 = $self->{'curr_x_min'} ;
    $mod = $self->{'min_val'};
  }
  elsif ($self->{'max_val'} <= 0) {
    $x1 = $self->{'curr_x_max'};
    $mod = $self->{'max_val'};
  }
  else {
   $x1 = $self->{'curr_x_min'} + abs($map * $self->{'min_val'});
   $mod = 0;
   $self->{'surface'}->line ($misccolor, $line_size,$x1, $self->{'curr_y_min'},
                            $x1, $self->{'curr_y_max'});
  }
  
  # draw the bars
  for $i (1..$self->{'num_datasets'}) {
    # get the color for this dataset
    $color = $self->_color_role_to_rgb('dataset'.($i-1));
    
    # draw every bar for this dataset
    for $j (0..$self->{'num_datapoints'}) {
      # don't try to draw anything if there's no data
      if (defined ($data->[$i][$j])) {
	# find the bounds of the rectangle
        if ($self->{'spaced_bars'}) {
           $y2 = $y1 - ($j * $delta1) - ($self->{'num_datasets'} * $delta2) + (($i-1) * $delta2);
	}
	else {
           $y2 = $y1 - ($j * $delta1) - ($self->{'num_datasets'} * $delta2) + (($i) * $delta2);
	}
	$x2 = $x1;
	$y3 = $y2 + $delta2;

        #cut the bars off, if needed
        if ($data->[$i][$j] > $self->{'max_val'}) {
           $x3 = $x1 + (($self->{'max_val'} - $mod ) * $map) -1;
           $cut = 1;
        }
        elsif  ($data->[$i][$j] < $self->{'min_val'}) {
           $x3 = $x1 + (($self->{'min_val'} - $mod ) * $map) +1;
           $cut = 1;
        }
        else {
           $x3 = $x1 + (($data->[$i][$j] - $mod) * $map);
           $cut = 0;
        }
        
	# draw the bar
	  $self->{'surface'}->filled_rectangle ($color, $line_size, $x2, $y2, $x3, $y3);
	  if ($self->{'imagemap'}) {
	    $self->{'imagemap_data'}->[$i][$j] = [$x2, $y2, $x3, $y3];
	  }

	# now outline it. outline red if the bar had been cut off
        unless ($cut){
	  $self->{'surface'}->rectangle ($misccolor, $bar_border_size, $x2, $y3, $x3, $y2);
        }
        else {
          $self->{'surface'}->rectangle ($pink, $bar_border_size, $x2, $y3, $x3, $y2);
        }
        
      } else {
	  if ($self->{'imagemap'}) {
            $self->{'imagemap_data'}->[$i][$j] = [undef(), undef(), undef(), undef()];
          }
      }
    }
  }
      
  # and finaly box it off 
  $self->{'surface'}->rectangle (
  				$misccolor,
				$line_size,
  				$self->{'curr_x_min'},
  				$self->{'curr_y_min'},
				$self->{'curr_x_max'},
				$self->{'curr_y_max'}
		);
  return;

}

## be a good module and return 1
1;
