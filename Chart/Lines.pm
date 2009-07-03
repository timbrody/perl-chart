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

use constant DEBUG => 0;

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
  my $repair_top_flag = 0;
  my $repair_bottom_flag = 0;
  my $brush_size = $self->{'brush_size'};
  my $pt_size = $self->{'pt_size'};

  # init the imagemap data field if they asked for it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

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
  my $marker_delta = $self->{'brush_size'} * 10;
  
  # draw the lines
  for $i (1..$self->{'num_datasets'}) {
    # get the color for this dataset, and set the brush
	$color = $self->_color_role_to_rgb('dataset'.($i-1));
    
	my $shape = $self->{'pointStyle' . $i};
	my $marker_index = 0; # haven't drawn one yet

	my @points;
    # draw every line for this dataset
    for $j (0..$self->{'num_datapoints'}-1) {
      # don't try to draw anything if there's no data
	  if( !defined( $data->[$i][$j] ) )
	  {
		  if( scalar(@points) > 1 )
		  {
			  $self->{'surface'}->continuous($color,$brush_size,\@points);
		  }
		  @points = ();
		  if ($self->{'imagemap'}) {
			  $self->{'imagemap_data'}->[$i][$j] = [ undef(), undef() ];
		  }
		  next;
	  }
        if ($self->{'xy_plot'}) {
           $x3 = $x1 + $delta_num * $data->[0][$j] + $zero_offset;
        }
        else {
           $x3 = $x1 + ($delta * $j);
        }
		$y3 = $y1 - (($data->[$i][$j] - $mod) * $map);

        # now draw the line
		push @points, [$x3,$y3];

		# draw the marker
		if( defined($shape) && $x3 > $marker_index ) {
			$self->{'surface'}->point($color,$pt_size,$x3,$y3,$shape);
			$marker_index = $x3 + $marker_delta;
		}
       
        # set the flags, if the lines are out of the borders of the chart
        if ( ($data->[$i][$j] > $self->{'max_val'}) || ($data->[$i][$j-1] > $self->{'max_val'}) ) {
           $repair_top_flag = 1;
        }
        
        if ( ($self->{'max_val'} <= 0) &&
             (($data->[$i][$j] > $self->{'max_val'}) || ($data->[$i][$j-1] > $self->{'max_val'})) ) {
           $repair_top_flag = 1;
        }
        if ( ($data->[$i][$j] < $self->{'min_val'}) || ($data->[$i][$j-1] < $self->{'min_val'}) ) {
           $repair_bottom_flag = 1;
        }

		# store the imagemap data if they asked for it
		if ($self->{'imagemap'}) {
			$self->{'imagemap_data'}->[$i][$j] = [ $x3, $y3 ];
		}
    }
	if( @points > 1 )
	{
		$self->{'surface'}->continuous($color,$brush_size,\@points);
	}
	@points = ();
  }
  # and finally box it off
  unless( exists($self->{'draw_box'}) and $self->{'draw_box'} eq 'none' )
  {
	$self->{surface}->rectangle(
			$misccolor,
			1,
			$self->{'curr_x_min'},
			$self->{'curr_y_min'},
			$self->{'curr_x_max'},
			$self->{'curr_y_max'});
  }

   #get the width and the heigth of the complete picture
  ($abs_x_max, $abs_y_max) = ($self->{width}, $self->{height});
  
  #repair the chart, if the lines are out of the borders of the chart
  if ($repair_top_flag) {
   #overwrite the ugly mistakes
   $self->{'gd_obj'}->filledRectangle ($self->{'curr_x_min'}, 0,
				$self->{'curr_x_max'}, $self->{'curr_y_min'}-1,
				$self->_color_role_to_index('background'));

   #save the actual x and y values
   $t_x_min = $self->{'curr_x_min'};
   $t_x_max = $self->{'curr_x_max'};
   $t_y_min = $self->{'curr_y_min'};
   $t_y_max = $self->{'curr_y_max'};


   #get back to the point, where everything began
   $self->{'curr_x_min'} = 0;
   $self->{'curr_y_min'} = 0;
   $self->{'curr_x_max'} = $abs_x_max;
print STDERR "_draw_data: curr_y_max=$self->{'curr_y_max'} => " if DEBUG;
   $self->{'curr_y_max'} = $abs_y_max;
warn $self->{'curr_y_max'} if DEBUG;

   #draw the title again
   if ($self->{'title'}) {
    $self->_draw_title
   }

   #draw the sub title again
   if ($self->{'sub_title'}) {
    $self->_draw_sub_title
   }

   #draw the top legend again
   if ($self->{'legend'} =~ /^top$/i) {
    $self->_draw_top_legend;
   }
   
   #reset the actual values
   $self->{'curr_x_min'} = $t_x_min;
   $self->{'curr_x_max'} = $t_x_max;
   $self->{'curr_y_min'} = $t_y_min;
print STDERR "_draw_data: curr_y_max=$self->{'curr_y_max'} => " if DEBUG;
   $self->{'curr_y_max'} = $t_y_max;
warn $self->{'curr_y_max'} if DEBUG;
  }

  if ($repair_bottom_flag) {

   #overwrite the ugly mistakes
   $self->{'gd_obj'}->filledRectangle ($self->{'curr_x_min'}, $self->{'curr_y_max'}+1,
				$self->{'curr_x_max'}, $abs_y_max,
				$self->_color_role_to_index('background'));
    #save the actual x and y values
   $t_x_min = $self->{'curr_x_min'};
   $t_x_max = $self->{'curr_x_max'};
   $t_y_min = $self->{'curr_y_min'};
   $t_y_max = $self->{'curr_y_max'};

   #get back to the point, where everything began
   $self->{'curr_x_min'} = 0;
   $self->{'curr_y_min'} = 0;
   $self->{'curr_x_max'} = $abs_x_max;
print STDERR "_draw_data: curr_y_max=$self->{'curr_y_max'} => " if DEBUG;
   $self->{'curr_y_max'} = $abs_y_max-1;
warn $self->{'curr_y_max'} if DEBUG;

    # mark off the graph_border space
print STDERR "_draw_data: curr_y_max=$self->{'curr_y_max'} => " if DEBUG;
   $self->{'curr_y_max'} -= 2* $self->{'graph_border'};
warn $self->{'curr_y_max'} if DEBUG;
   
   #draw the bottom legend again
   if ($self->{'legend'} =~ /^bottom$/i) {
    $self->_draw_bottom_legend;
   }
   
   #draw the x label again
   if ($self->{'x_label'}) {
    $self->_draw_x_label;
   }

   #get back to the start point for the ticks
   $self->{'curr_x_min'} = $self->{'temp_x_min'};
   $self->{'curr_y_min'} = $self->{'temp_y_min'};
   $self->{'curr_x_max'} = $self->{'temp_x_max'};
print STDERR "_draw_data: curr_y_max=$self->{'curr_y_max'} => " if DEBUG;
   $self->{'curr_y_max'} = $self->{'temp_y_max'};
warn $self->{'curr_y_max'} if DEBUG;
   
   #draw the x ticks again
   if ($self->{'xy_plot'}) {
      $self->_draw_x_number_ticks;
   }
   else {
      $self->_draw_x_ticks;
   }

   #reset the actual values
   $self->{'curr_x_min'} = $t_x_min;
   $self->{'curr_x_max'} = $t_x_max;
   $self->{'curr_y_min'} = $t_y_min;
print STDERR "_draw_data: curr_y_max=$self->{'curr_y_max'} => " if DEBUG;
   $self->{'curr_y_max'} = $t_y_max;
warn $self->{'curr_y_max'} if DEBUG;
  }
    
  return;

}

## be a good module and return 1
1;
