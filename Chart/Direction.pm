#====================================================================
#  Chart::Direction
#
#  written by Chart-Group
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: Direction.pm,v $ $Revision: 1.2 $ $Date: 2003/02/14 13:30:42 $
# $Author: dassing $
# $Log: Direction.pm,v $
# Revision 1.2  2003/02/14 13:30:42  dassing
# Circumvent division of zeros
#
#====================================================================

package Chart::Direction;

use Chart::Base 2.3;
use GD;
use Carp;
use strict;
use POSIX;

@Chart::Direction::ISA = qw(Chart::Base);
$Chart::Direction::VERSION = '2.3';

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#



#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

#we don't need a legend for this type.
#sub _draw_legend {

#    return 1;
#}

# we use the find_y_scale methode to det the labels of the circles and the amount of them
sub _find_y_scale
{
	my $self = shift;

	# Predeclare vars.
	my ($d_min, $d_max);		# Dataset min & max.
	my ($p_min, $p_max);		# Plot min & max.
	my ($tickInterval, $tickCount, $skip);
	my @tickLabels;				# List of labels for each tick.
	my $maxtickLabelLen = 0;	# The length of the longest tick label.

	# Find the datatset minimum and maximum.
	($d_min, $d_max) = $self->_find_y_range();

	# Force the inclusion of zero if the user has requested it.
	if( $self->{'include_zero'} )
	{
		if( ($d_min * $d_max) > 0 )	# If both are non zero and of the same sign.
		{
			if( $d_min > 0 )	# If the whole scale is positive.
			{
				$d_min = 0;
			}
			else				# The scale is entirely negative.
			{
				$d_max = 0;
			}
		}
	}

	    # Allow the dataset range to be overidden by the user.
	    # f_min/max are booleans which indicate that the min & max should not be modified.
	    my $f_min = defined $self->{'min_val'};
	    $d_min = $self->{'min_val'} if $f_min;

	    my $f_max = defined $self->{'max_val'};
	    $d_max = $self->{'max_val'} if $f_max;

	    # Assert against the min is larger than the max.
	    if( $d_min > $d_max )
	    {
	     croak "The the specified 'min_val' & 'max_val' values are reversed (min > max: $d_min>$d_max)";
	     }

	     # Calculate the width of the dataset. (posibly modified by the user)
	     my $d_width = $d_max - $d_min;

	     # If the width of the range is zero, forcibly widen it
	     # (to avoid division by zero errors elsewhere in the code).
	     if( 0 == $d_width )
	         {
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
		= $self->_calcTickInterval($d_min/$rangeMuliplier, $d_max/$rangeMuliplier,
				$f_min, $f_max,
				$self->{'min_circles'}+1, $self->{'max_circles'}+1);
	     # Restore the tickInterval etc to the correct scale
	     $_ *= $rangeMuliplier foreach($tickInterval, $p_min, $p_max);

	     #get teh precision for the labels
	     my $precision = $self->{'precision'};

	     # Now sort out an array of tick labels.
	     for( my $labelNum = $p_min; $labelNum<=$p_max; $labelNum+=$tickInterval )
	     {
		my $labelText;

		if( defined $self->{f_y_tick} )
		{
                        # Is _default_f_tick function used?
                        if ( $self->{f_y_tick} == \&Chart::Base::_default_f_tick ) {
			   $labelText = sprintf("%.".$precision."f", $labelNum);
                        } else {         print \&_default_f_tick;
			   $labelText = $self->{f_y_tick}->($labelNum);
                        }
		}
		else
		{
			$labelText = sprintf("%.".$precision."f", $labelNum);
		}
		push @tickLabels, $labelText;
		$maxtickLabelLen = length $labelText if $maxtickLabelLen < length $labelText;
	     }

	# Store the calculated data.
	$self->{'min_val'} = $p_min;
	$self->{'max_val'} = $p_max;
	$self->{'y_ticks'} = $tickCount;
	$self->{'y_tick_labels'} = \@tickLabels;
	$self->{'y_tick_label_length'} = $maxtickLabelLen;

	# and return.
	return 1;
}

# Calculates the tick  in normalised units.
sub _calcTickInterval
{       my $self = shift;
	my(
		$min, $max,		# The dataset min & max.
		$minF, $maxF,	# Indicates if those min/max are fixed.
		$minTicks, $maxTicks,	# The minimum & maximum number of ticks.
	) = @_;

	# Verify the supplied 'min_y_ticks' & 'max_y_ticks' are sensible.
	if( $minTicks < 2 )
	{
		print STDERR "Chart::Base : Incorrect value for 'min_circles', too small.\n";
		$minTicks = 2;
	}

	if( $maxTicks < 5*$minTicks  )
	{
		print STDERR "Chart::Base : Incorrect value for 'max_circles', too small.\n";
		$maxTicks = 5*$minTicks;
	}

	my $width = $max - $min;
	my @divisorList;

	for( my $baseMul = 1; ; $baseMul *= 10 )
	{
		TRY: foreach my $tryMul (1, 2, 5)
		{
			# Calc a fresh, smaller tick interval.
			my $divisor = $baseMul * $tryMul;

			# Count the number of ticks.
			my ($tickCount, $pMin, $pMax) = $self->_countTicks($min, $max, 1/$divisor);

			# Look a the number of ticks.
			if( $maxTicks < $tickCount )
			{
				# If it is to high, Backtrack.
				$divisor = pop @divisorList;
                                # just for security:
                                if ( !defined($divisor) || $divisor == 0 ) { $divisor = 1; }
				($tickCount, $pMin, $pMax) = $self->_countTicks($min, $max, 1/$divisor);
				print "\nChart::Base : Caution: Tick limit of $maxTicks exceeded. Backing of to an interval of ".1/$divisor." which plots $tickCount ticks\n";
				return(1/$divisor, $tickCount, $pMin, $pMax);
			}
			elsif( $minTicks > $tickCount )
			{
				# If it is to low, try again.
				next TRY;
			}
			else
			{
				# Store the divisor for possible later backtracking.
				push @divisorList, $divisor;

				# if the min or max is fixed, check they will fit in the interval.
				next TRY if( $minF && ( int ($min*$divisor) != ($min*$divisor) ) );
				next TRY if( $maxF && ( int ($max*$divisor) != ($max*$divisor) ) );

				# If everything passes the tests, return.
				return(1/$divisor, $tickCount, $pMin, $pMax)
			}
		}
	}
	die "can't happen!";
}

#this is where we draw the circles and the axes
sub _draw_y_ticks {
  my $self = shift;
  my $data = $self->{'dataref'};
  my $misccolor = $self->_color_role_to_index('misc');
  my $textcolor = $self->_color_role_to_index('text');
  my $background = $self->_color_role_to_index('background');
  my @labels = @{$self->{'y_tick_labels'}};
  my ($width, $height, $centerX, $centerY, $diameter);
  my ($pi, $font, $fontW, $fontH, $labelX, $labelY, $label_offset);
  my ($dia_delta, $dia, $x, $y, @label_degrees, $arc, $angle_interval);

  # set up initial constant values
  $pi = 3.14159265358979323846;
  $font = $self->{'legend_font'};
  $fontW = $self->{'legend_font'}->width;
  $fontH = $self->{'legend_font'}->height;
  $angle_interval = $self->{'angle_interval'};

  if ($self->{'grey_background'}) {
      $background = $self->_color_role_to_index('grey_background');
  }
  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  # find width and height
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};

  # find center point, from which the pie will be drawn around
  $centerX = int($width/2  + $self->{'curr_x_min'});
  $centerY = int($height/2 + $self->{'curr_y_min'});

  # always draw a circle, which means the diameter will be the smaller
  # of the width and height. let enougth space for the label.
  if ($width < $height) {
   $diameter = $width -110;
  }
  else {
    $diameter = $height -80 ;
  }

  #the difference between the diameter of two following circles;
  $dia_delta = ceil($diameter / ($self->{'y_ticks'}-1));

  #store the calculated data
  $self->{'centerX'} = $centerX;
  $self->{'centerY'} = $centerY;
  $self->{'diameter'} = $diameter;

  #draw the axes and its labels
  # set up an array of labels for the axes
  if ($angle_interval == 0) {
     @label_degrees = ( );
  }
  elsif ($angle_interval <= 5 && $angle_interval > 0) {
     @label_degrees = qw(180 175 170 165 160 155 150 145 140 135 130 125 120 115
     110 105 100 95 90 85 80 75 70 65 60 55 50 45 40 35 30 25 20 15 10 5 0 355 350
     345 340 335 330 325 320 315 310 305 300 295 290 285 280 275 270 265 260 255
     250 245 240 235 230 225 220 215 210 205 200 195 190 185);
     $angle_interval = 5;
  }
  elsif ($angle_interval <= 10 && $angle_interval > 5) {
     @label_degrees = qw(180 170 160 150 140 130 120 110 100 90 80 70 60 50 40
     30 20 10 0 350 340 330 320 310 300 290 280 270 260 250 240 230 220 210 200 190);
     $angle_interval = 10;
  }
  elsif ($angle_interval <= 15 && $angle_interval > 10) {
     @label_degrees = qw(180 165 150 135 120 105 90 75 60 45 30 15 0 345 330 315 300
     285 270 255 240 225 210 195);
     $angle_interval = 15;
  }
  elsif ($angle_interval <=20 && $angle_interval > 15) {
     @label_degrees = qw(180 160 140 120 100 80 60 40 20 0 340 320 300 280 260 240
     220 200);
     $angle_interval = 20;
  }
  elsif ($angle_interval <= 30 && $angle_interval > 20) {
     @label_degrees = qw(180 150 120 90 60 30 0 330 300 270 240 210);
     $angle_interval = 30;
  }
  elsif ($angle_interval <= 45 && $angle_interval > 30) {
     @label_degrees = qw(180 135 90 45 0 315 270 225);
     $angle_interval = 45;
  }
  elsif ($angle_interval <= 90 && $angle_interval > 45) {
     @label_degrees = qw(180 90 0 270);
     $angle_interval = 90;
  }
  else {
     carp "The angle_interval must be between 0 and 90!\nCorrected value: 30";
     @label_degrees = qw(180 150 120 90 60 30 0 330 300 270 240 210);
     $angle_interval = 30;
  }
  $arc = 0;
  foreach (@label_degrees)    {
      #calculated the coordinates of the end point of the line
      $x = sin ($arc)*($diameter/2+10) + $centerX;
      $y = cos  ($arc)*($diameter/2+10) + $centerY;
      #some ugly correcture
      if ($_ == '270') { $y++;}
      #draw the line
      $self->{'gd_obj'}->line($centerX, $centerY, $x, $y, $misccolor);
      #calculate the string point
      $x = sin ($arc)*($diameter/2+30) + $centerX-8;
      $y = cos  ($arc)*($diameter/2+28) + $centerY-6;
      #draw the labels
      $self->{'gd_obj'}->string($font, $x, $y, $_.'�', $textcolor);
      $arc += (($angle_interval)/360) *2*$pi;
  }
      
  #draw the circles
  $dia = 0;
  foreach (@labels) {
      $self->{'gd_obj'}->arc($centerX,$centerY,
                    $dia, $dia,
                    0, 360,
                    $misccolor);
      $dia += $dia_delta;
  }
  
  $self->{'gd_obj'}->filledRectangle($centerX-length($labels[0])/2*$fontW-2,
                                     $centerY+2,
                                     $centerX+2+$diameter/2,
                                     $centerY+$fontH+2,
                                     $background);
  #draw the labels of the circles
  $dia = 0;
  foreach (@labels) {
       $self->{'gd_obj'}->string($font, $centerX+$dia/2-length($_)/2*$fontW,
                                 $centerY+2, $_, $textcolor);
       $dia += $dia_delta;
  }
       
  

  return;
}

#We don't need x ticks, it's all done in _draw_y_ticks
sub _draw_x_ticks {
  my $self = shift;

  return;
}


## finally get around to plotting the data
sub _draw_data {
  my $self = shift;
  my $data = $self->{'dataref'};
  my $misccolor = $self->_color_role_to_index('misc');
  my $textcolor = $self->_color_role_to_index('text');
  my $background = $self->_color_role_to_index('background');
  my ($width, $height, $centerX, $centerY, $diameter);
  my ($mod, $map, $i, $j, $brush, $color, $x, $y, $winkel, $first_x, $first_y );
  my ($arrow_x, $arrow_y, $m);
  $color = 1;

  my $pi = 3.14159265358979323846;
  my $len = 10;
  my $alpha = 1;
  my $last_x = undef;
  my $last_y = undef;
  my $diff;
  my $n=0;
  
  
  
  
  
  if ($self->{'pairs'}) {
     my $a = $self->{'num_datasets'}/2;
     my $b = ceil($a);
     my $c = $b-$a;
    
     if ($c == 0) {
     croak "Wrong number of datasets for 'pairs'";
     }
    }
  
 
  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  # find width and height
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
  
  # get the base values
  $mod = $self->{'min_val'};
  $centerX = $self->{'centerX'};
  $centerY = $self->{'centerY'};
  $diameter = $self->{'diameter'};
  $diff = $self->{'max_val'} - $self->{'min_val'};
  $diff = 1 if $diff < 1;
  $map = $diameter/2/$diff;
  
  
  $brush = $self->_prepare_brush ($color, 'point');
  $self->{'gd_obj'}->setBrush ($brush);

 
  # draw every line for this dataset
  
  if ($self->{'pairs'}) { 
  
    for  $j (1..$self->{'num_datasets'}) {
       $color = $self->_color_role_to_index('dataset'.($j-1));
     
      for $i (0..$self->{'num_datapoints'}-1) {
           
      # don't try to draw anything if there's no data
      if (defined ($data->[$j][$i]) && $data->[$j][$i] <= $self->{'max_val'}
          &&  $data->[$j][$i] >= $self->{'min_val'}) {
	  
        #calculate the point
	$winkel = (180 - ($data->[0][$i] % 360)) /360 * 2* $pi;

        $x = ceil($centerX + sin ($winkel) * ($data->[$j][$i] - $mod) * $map);
        $y = ceil($centerY + cos ($winkel) * ($data->[$j][$i] - $mod) * $map);

	# set the x and y values back
	if ($i ==0) {
	    $first_x = $x;
	    $first_y = $y;
	    $last_x = $x;
            $last_y = $y;
	    }
	    
	
        if ($self->{'point'}) {
          $brush = $self->_prepare_brush ($color, 'point');
          $self->{'gd_obj'}->setBrush ($brush);
          #draw the point
          $self->{'gd_obj'}->line($x+1, $y, $x, $y, gdBrushed);
        }
        if ($self->{'line'}) {
          $brush = $self->_prepare_brush ($color, 'line');
          $self->{'gd_obj'}->setBrush ($brush);
          #draw the line
          if (defined $last_x) {
	     $self->{'gd_obj'}->line($x, $y, $last_x, $last_y, gdBrushed);
          }
          else {}
	
        }
	
	
        if ($self->{'arrow'}) {
          $brush = $self->_prepare_brush ($color, 'line');
          $self->{'gd_obj'}->setBrush ($brush);
          #draw the arrow
          if ($data->[$j][$i] > $self->{'min_val'}) {
            $self->{'gd_obj'}->line($x, $y, $centerX, $centerY, gdBrushed);

            $arrow_x =  $x - cos($winkel-$alpha )*$len;
            $arrow_y = $y + sin($winkel-$alpha)*$len;
            $self->{'gd_obj'}->line($x, $y, $arrow_x, $arrow_y, gdBrushed);

            $arrow_x = $x + sin($pi/2-$winkel-$alpha )*$len;
            $arrow_y = $y - cos($pi/2-$winkel-$alpha)*$len;
            $self->{'gd_obj'}->line($x, $y, $arrow_x, $arrow_y, gdBrushed);

            
          }
        }

        $last_x = $x;
        $last_y = $y;
        
        
	# store the imagemap data if they asked for it
	if ($self->{'imagemap'}) {
	  $self->{'imagemap_data'}->[$j][$i] = [$x, $y ];
 	}
      } else {
	if ($self->{'imagemap'}) {
	  $self->{'imagemap_data'}->[$j][$i] = [ undef(), undef() ];

        }
      }
    }
    
    # draw the last line to the first point    
    if ($self->{'line'}) {
      $self->{'gd_obj'}->line($x, $y, $first_x, $first_y, gdBrushed);
      }
      
    }
  }
  
 
  if ($self->{'pairs'}) {
     
     for  ($j = 1; $j <= $self->{'num_datasets'}; $j+=2) {
       if ($j ==1) {
         $color = $self->_color_role_to_index('dataset'.($j-1));
	 }
       else {
         $color = $self->_color_role_to_index('dataset'.($j/2-0.5));
        }
       for $i (0..$self->{'num_datapoints'}-1) {
          
      # don't try to draw anything if there's no data
      if (defined ($data->[$j][$i]) && $data->[$j][$i] <= $self->{'max_val'}
          &&  $data->[$j][$i] >= $self->{'min_val'}) {
	  
        # calculate the point
	$winkel = (180 - ($data->[$n][$i] % 360)) /360 * 2* $pi;

        $x = ceil($centerX + sin ($winkel) * ($data->[$j][$i] - $mod) * $map);
        $y = ceil($centerY + cos ($winkel) * ($data->[$j][$i] - $mod) * $map);

	# set the x and y values back
	if ($i ==0) {
	    $first_x = $x;
	    $first_y = $y;
	    $last_x = $x;
            $last_y = $y;
	    }
	    
	
        if ($self->{'point'}) {
          $brush = $self->_prepare_brush ($color, 'point');
          $self->{'gd_obj'}->setBrush ($brush);
          #draw the point
          $self->{'gd_obj'}->line($x+1, $y, $x, $y, gdBrushed);
        }
        if ($self->{'line'}) {
          $brush = $self->_prepare_brush ($color, 'line');
          $self->{'gd_obj'}->setBrush ($brush);
          #draw the line
          if (defined $last_x) {
	     $self->{'gd_obj'}->line($x, $y, $last_x, $last_y, gdBrushed);
          }
          else {}
	  
         }
	
	
        if ($self->{'arrow'}) {
          $brush = $self->_prepare_brush ($color, 'line');
          $self->{'gd_obj'}->setBrush ($brush);
          #draw the arrow
          if ($data->[$j][$i] > $self->{'min_val'}) {
            $self->{'gd_obj'}->line($x, $y, $centerX, $centerY, gdBrushed);

            $arrow_x =  $x - cos($winkel-$alpha )*$len;
            $arrow_y = $y + sin($winkel-$alpha)*$len;
            $self->{'gd_obj'}->line($x, $y, $arrow_x, $arrow_y, gdBrushed);

            $arrow_x = $x + sin($pi/2-$winkel-$alpha )*$len;
            $arrow_y = $y - cos($pi/2-$winkel-$alpha)*$len;
            $self->{'gd_obj'}->line($x, $y, $arrow_x, $arrow_y, gdBrushed);

            
          }
        }

        $last_x = $x;
        $last_y = $y;
        
        
	# store the imagemap data if they asked for it
	if ($self->{'imagemap'}) {
	  $self->{'imagemap_data'}->[$j][$i] = [$x, $y ];
 	}
      } else {
	if ($self->{'imagemap'}) {
	  $self->{'imagemap_data'}->[$j][$i] = [ undef(), undef() ];

        }
      }
    }
    
    # draw the last line to the first point    
    if ($self->{'line'}) {
      $self->{'gd_obj'}->line($x, $y, $first_x, $first_y, gdBrushed);
      }
      $n+=2;
     }
     
   }
 
 # now outline it  
   $self->{'gd_obj'}->rectangle ($self->{'curr_x_min'} ,
                                 $self->{'curr_y_min'},
                                 $self->{'curr_x_max'},
                                 $self->{'curr_y_max'},
                                 $misccolor);

  return;

}


##  set the gdBrush object to trick GD into drawing fat lines
sub _prepare_brush {
  my $self = shift;
  my $color = shift;
  my $type = shift;
  my ($radius, @rgb, $brush, $white, $newcolor);
   
  @rgb = $self->{'gd_obj'}->rgb($color);

  # get the appropriate brush size
  if ($type eq 'line') {
    $radius = $self->{'brush_size'}/2;
  }
  elsif ($type eq 'point') {
    $radius = $self->{'pt_size'}/2;
  }

  # create the new image
  $brush = GD::Image->new ($radius*2, $radius*2);

  # get the colors, make the background transparent
  $white = $brush->colorAllocate (255,255,255);
  $newcolor = $brush->colorAllocate (@rgb);
  $brush->transparent ($white);

  # draw the circle
  $brush->arc ($radius-1, $radius-1, $radius, $radius, 0, 360, $newcolor);

  # fill it if we're using lines
  $brush->fill ($radius-1, $radius-1, $newcolor);
  
  #}

  # set the new image as the main object's brush
  return $brush;
}



sub _draw_legend {
  my $self = shift;
  my ($length);

  # check to see if legend type is none..
  if ($self->{'legend'} =~ /^none$/) {
    return 1;
  }
  # check to see if they have as many labels as datasets,
  # warn them if not
  if (($#{$self->{'legend_labels'}} >= 0) && 
       ((scalar(@{$self->{'legend_labels'}})) != $self->{'num_datasets'})) {
    carp "The number of legend labels and datasets doesn\'t match";
  }

  # init a field to store the length of the longest legend label
  unless ($self->{'max_legend_label'}) {
    $self->{'max_legend_label'} = 0;
  }

  # fill in the legend labels, find the longest one
  
  if ($self->{'pairs'}) {
  for (1..$self->{'num_datasets'}) {
    unless ($self->{'legend_labels'}[$_-1]) {
      $self->{'legend_labels'}[$_-1] = "Dataset $_";
    }
    $length = length($self->{'legend_labels'}[$_-1]);
    if ($length > $self->{'max_legend_label'}) {
      $self->{'max_legend_label'} = $length;
    }
  }
  }
  
  if ($self->{'pairs'}) {
  
   for (1..ceil($self->{'num_datasets'}/2)) {
    unless ($self->{'legend_labels'}[$_-1]) {
      $self->{'legend_labels'}[$_-1] = "Dataset $_";
    }
    $length = length($self->{'legend_labels'}[$_-1]);
    if ($length > $self->{'max_legend_label'}) {
      $self->{'max_legend_label'} = $length;
    }
  }
 }
      
  # different legend types
  if ($self->{'legend'} eq 'bottom') {
    $self->_draw_bottom_legend;
  }
  elsif ($self->{'legend'} eq 'right') {
    $self->_draw_right_legend;
  }
  elsif ($self->{'legend'} eq 'left') {
    $self->_draw_left_legend;
  }
  elsif ($self->{'legend'} eq 'top') {
    $self->_draw_top_legend;
  } else {
    carp "I can't put a legend there (at ".$self->{'legend'}.")\n";
  }

  # and return
  return 1;
}

## put the legend on the bottom of the chart
sub _draw_bottom_legend {
  my $self = shift;
  my @labels = @{$self->{'legend_labels'}};
  my ($x1, $y1, $x2, $x3, $y2, $empty_width, $max_label_width, $cols, $rows, $color, $brush);
  my ($col_width, $row_height, $r, $c, $index, $x, $y, $w, $h, $axes_space);
  my $font = $self->{'legend_font'};


  # make sure we're using a real font
  unless ((ref ($font)) eq 'GD::Font') {
    croak "The subtitle font you specified isn\'t a GD Font object";
  }

  # get the size of the font
  ($h, $w) = ($font->height, $font->width);

  # find the base x values
  $axes_space = ($self->{'y_tick_label_length'} * $self->{'tick_label_font'}->width)
	        + $self->{'tick_len'} + (3 * $self->{'text_space'});
  $x1 = $self->{'curr_x_min'} + $self->{'graph_border'};
  $x2 = $self->{'curr_x_max'} - $self->{'graph_border'};

  if ($self->{'y_axes'} =~ /^right$/i) {
     $x2 -= $axes_space;
  }
  elsif ($self->{'y_axes'} =~ /^both$/i) {
     $x2 -= $axes_space;
   #  $x1 += $axes_space;
  }
  else {
   #  $x1 += $axes_space;
     
  }


  if ($self->{'y_label'}) {
    $x1 += $self->{'label_font'}->height + 2 * $self->{'text_space'};
  }
  if ($self->{'y_label2'}) {
    $x2 -= $self->{'label_font'}->height + 2 * $self->{'text_space'};
  }

  # figure out how wide the columns need to be, and how many we
  # can fit in the space available
  $empty_width = ($x2 - $x1) - (2 * $self->{'legend_space'});
  $max_label_width = $self->{'max_legend_label'} * $w
    + (4 * $self->{'text_space'}) + $self->{'legend_example_size'};
  $cols = int ($empty_width / $max_label_width);
  unless ($cols) {
    $cols = 1;
  }
  $col_width = $empty_width / $cols;

  # figure out how many rows we need, remember how tall they are
  $rows = int ($self->{'num_datasets'} / $cols);
  unless (($self->{'num_datasets'} % $cols) == 0) {
    $rows++;
  }
  unless ($rows) {
    $rows = 1;
  }
  $row_height = $h + $self->{'text_space'};

  # box the legend off
  $y1 = $self->{'curr_y_max'} - $self->{'text_space'}
          - ($rows * $row_height) - (2 * $self->{'legend_space'});
  $y2 = $self->{'curr_y_max'};
 
  
  $self->{'gd_obj'}->rectangle($x1, $y1, $x2, $y2, 
                               $self->_color_role_to_index('misc'));
 
  $x1 += $self->{'legend_space'} + $self->{'text_space'};
  $x2 -= $self->{'legend_space'};
  $y1 += $self->{'legend_space'} + $self->{'text_space'};
  $y2 -= $self->{'legend_space'} + $self->{'text_space'};

  # draw in the actual legend
  for $r (0..$rows-1) {
    for $c (0..$cols-1) {
      $index = ($r * $cols) + $c;  # find the index in the label array
      if ($labels[$index]) {
	# get the color
        $color = $self->_color_role_to_index('dataset'.$index); 

        # get the x-y coordinate for the start of the example line
	$x = $x1 + ($col_width * $c);
        $y = $y1 + ($row_height * $r) + $h/2;
	
	# now draw the example line
        $self->{'gd_obj'}->line($x, $y, 
                                $x + $self->{'legend_example_size'}, $y,
                                $color);

        # reset the brush for points
        $brush = $self->_prepare_brush($color, 'point',
				$self->{'pointStyle' . $index});
        $self->{'gd_obj'}->setBrush($brush);
        # draw the point
        $x3 = int($x + $self->{'legend_example_size'}/2);
        $self->{'gd_obj'}->line($x3, $y, $x3, $y, gdBrushed);

        # adjust the x-y coordinates for the start of the label
	$x += $self->{'legend_example_size'} + (2 * $self->{'text_space'});
        $y = $y1 + ($row_height * $r);

	# now draw the label
	$self->{'gd_obj'}->string($font, $x, $y, $labels[$index], $color);
      }
    }
  }

  # mark off the space used
  $self->{'curr_y_max'} -= ($rows * $row_height) + $self->{'text_space'}
			      + (2 * $self->{'legend_space'}); 

  # now return
  return 1;
}

## put the legend on top of the chart
sub _draw_top_legend {
  my $self = shift;
  my @labels = @{$self->{'legend_labels'}};
  my ($x1, $y1, $x2, $x3, $y2, $empty_width, $max_label_width, $cols, $rows, $color, $brush);
  my ($col_width, $row_height, $r, $c, $index, $x, $y, $w, $h, $axes_space);
  my $font = $self->{'legend_font'};

  # make sure we're using a real font
  unless ((ref ($font)) eq 'GD::Font') {
    croak "The subtitle font you specified isn\'t a GD Font object";
  }

  # get the size of the font
  ($h, $w) = ($font->height, $font->width);

  # find the base x values
  $axes_space = ($self->{'y_tick_label_length'} * $self->{'tick_label_font'}->width)
	        + $self->{'tick_len'} + (3 * $self->{'text_space'});
  $x1 = $self->{'curr_x_min'} + $self->{'graph_border'};
  $x2 = $self->{'curr_x_max'} - $self->{'graph_border'};

  if ($self->{'y_axes'} =~ /^right$/i) {
     $x2 -= $axes_space;
  }
  elsif ($self->{'y_axes'} =~ /^both$/i) {
     $x2 -= $axes_space;
    # $x1 += $axes_space;
  }
  else {
    # $x1 += $axes_space;
  }

  # figure out how wide the columns can be, and how many will fit
  $empty_width = ($x2 - $x1) - (2 * $self->{'legend_space'});
  $max_label_width = (4 * $self->{'text_space'})
    + ($self->{'max_legend_label'} * $w)
    + $self->{'legend_example_size'};
  $cols = int ($empty_width / $max_label_width);
  unless ($cols) {
    $cols = 1;
  }
  $col_width = $empty_width / $cols;

  # figure out how many rows we need and remember how tall they are
  $rows = int ($self->{'num_datasets'} / $cols);
  unless (($self->{'num_datasets'} % $cols) == 0) {
    $rows++;
  }
  unless ($rows) {
    $rows = 1;
  }
  $row_height = $h + $self->{'text_space'};

  # box the legend off
  $y1 = $self->{'curr_y_min'};
  $y2 = $self->{'curr_y_min'} + $self->{'text_space'}
          + ($rows * $row_height) + (2 * $self->{'legend_space'});
  $self->{'gd_obj'}->rectangle($x1, $y1, $x2, $y2, 
                               $self->_color_role_to_index('misc'));

  # leave some space inside the legend
  $x1 += $self->{'legend_space'} + $self->{'text_space'};
  $x2 -= $self->{'legend_space'};
  $y1 += $self->{'legend_space'} + $self->{'text_space'};
  $y2 -= $self->{'legend_space'} + $self->{'text_space'};

  # draw in the actual legend
  for $r (0..$rows-1) {
    for $c (0..$cols-1) {
      $index = ($r * $cols) + $c;  # find the index in the label array
      if ($labels[$index]) {
	# get the color
        $color = $self->_color_role_to_index('dataset'.$index); 
        
	# find the x-y coords
	$x = $x1 + ($col_width * $c);
        $y = $y1 + ($row_height * $r) + $h/2;

	# draw the line first
        $self->{'gd_obj'}->line($x, $y, 
                                $x + $self->{'legend_example_size'}, $y,
                                $color);

        # reset the brush for points
        $brush = $self->_prepare_brush($color, 'point',
				$self->{'pointStyle' . $index});
        $self->{'gd_obj'}->setBrush($brush);
        # draw the point
        $x3 = int($x + $self->{'legend_example_size'}/2);
        $self->{'gd_obj'}->line($x3, $y, $x3, $y, gdBrushed);

        # now the label
	$x += $self->{'legend_example_size'} + (2 * $self->{'text_space'});
	$y -= $h/2;
	$self->{'gd_obj'}->string($font, $x, $y, $labels[$index], $color);
      }
    }
  }
      
  # mark off the space used
  $self->{'curr_y_min'} += ($rows * $row_height) + $self->{'text_space'}
			      + 2 * $self->{'legend_space'}; 

  # now return
  return 1;
}



sub _draw_left_legend {
  my $self = shift;
  my @labels = @{$self->{'legend_labels'}};
  my ($x1, $x2, $x3, $y1, $y2, $width, $color, $misccolor, $w, $h, $brush);
  my $font = $self->{'legend_font'};
 
  # make sure we're using a real font
  unless ((ref ($font)) eq 'GD::Font') {
    croak "The subtitle font you specified isn\'t a GD Font object";
  }

  # get the size of the font
  ($h, $w) = ($font->height, $font->width);

  # get the miscellaneous color
  $misccolor = $self->_color_role_to_index('misc');

  # find out how wide the largest label is
  $width = (2 * $self->{'text_space'})
    + ($self->{'max_legend_label'} * $w)
    + $self->{'legend_example_size'}
    + (2 * $self->{'legend_space'});

  # get some base x-y coordinates
  $x1 = $self->{'curr_x_min'};
  $x2 = $self->{'curr_x_min'} + $width;
  $y1 = $self->{'curr_y_min'} + $self->{'graph_border'} ;
  
  if ($self->{'pairs'}) {
  $y2 = $self->{'curr_y_min'} + $self->{'graph_border'} + $self->{'text_space'}
          + (($self->{'num_datasets'}/2) * ($h + $self->{'text_space'}))
	  + (4 * $self->{'legend_space'});
     }
  else {
  $y2 = $self->{'curr_y_min'} + $self->{'graph_border'} + $self->{'text_space'}
        + ($self->{'num_datasets'} * ($h + $self->{'text_space'}))
	+ (2 * $self->{'legend_space'});
	}
	
  # box the legend off
  $self->{'gd_obj'}->rectangle ($x1, $y1, $x2, $y2, $misccolor);

  # leave that nice space inside the legend box
  $x1 += $self->{'legend_space'};
  $y1 += $self->{'legend_space'} + $self->{'text_space'};

  # now draw the actual legend
  for (0..$#labels) {
    # get the color
    my $c = $self->{'num_datasets'}-$_-1;
    $color = $self->_color_role_to_index('dataset'.$_);
    
    # find the x-y coords
    $x2 = $x1;
    $x3 = $x2 + $self->{'legend_example_size'};
    $y2 = $y1 + ($_ * ($self->{'text_space'} + $h)) + $h/2;

    # do the line first
    $self->{'gd_obj'}->line ($x2, $y2, $x3, $y2, $color);

    # reset the brush for points
    $brush = $self->_prepare_brush($color, 'point',
				$self->{'pointStyle' . $_});
    $self->{'gd_obj'}->setBrush($brush);
    # draw the point
    $self->{'gd_obj'}->line(int(($x3+$x2)/2), $y2,
				int(($x3+$x2)/2), $y2, gdBrushed);
    
    # now the label
    $x2 = $x3 + (2 * $self->{'text_space'});
    $y2 -= $h/2;
    
    # order of the datasets in the legend
    $self->{'gd_obj'}->string ($font, $x2, $y2, $labels[$_], $color);
   }

  # mark off the used space
  $self->{'curr_x_min'} += $width;

  # and return
  return 1;
}



sub _draw_right_legend {
  my $self = shift;
  my @labels = @{$self->{'legend_labels'}};
  my ($x1, $x2, $x3, $y1, $y2, $width, $color, $misccolor, $w, $h, $brush);
  my $font = $self->{'legend_font'};
 
  # make sure we're using a real font
  unless ((ref ($font)) eq 'GD::Font') {
    croak "The subtitle font you specified isn\'t a GD Font object";
  }

  # get the size of the font
  ($h, $w) = ($font->height, $font->width);

  # get the miscellaneous color
  $misccolor = $self->_color_role_to_index('misc');

  # find out how wide the largest label is
  $width = (2 * $self->{'text_space'})
    + ($self->{'max_legend_label'} * $w)
    + $self->{'legend_example_size'}
    + (2 * $self->{'legend_space'});

  # get some starting x-y values
  $x1 = $self->{'curr_x_max'} - $width;
  $x2 = $self->{'curr_x_max'};
  $y1 = $self->{'curr_y_min'} + $self->{'graph_border'} ;
  
  if ($self->{'pairs'}) {
  $y2 = $self->{'curr_y_min'} + $self->{'graph_border'} + $self->{'text_space'}
          + (($self->{'num_datasets'}/2) * ($h + $self->{'text_space'}))
	  + (4 * $self->{'legend_space'});
	  }
  else {
  $y2 = $self->{'curr_y_min'} + $self->{'graph_border'} + $self->{'text_space'}
          + ($self->{'num_datasets'} * ($h + $self->{'text_space'}))
	  + (2 * $self->{'legend_space'});
	  }
  # box the legend off
  $self->{'gd_obj'}->rectangle ($x1, $y1, $x2, $y2, $misccolor);

  # leave that nice space inside the legend box
  $x1 += $self->{'legend_space'};
  $y1 += $self->{'legend_space'} + $self->{'text_space'};

  # now draw the actual legend
  for (0..$#labels) {
    # get the color
    $color = $self->_color_role_to_index('dataset'.$_);
   
    # find the x-y coords
    $x2 = $x1;
    $x3 = $x2 + $self->{'legend_example_size'};
    $y2 = $y1 + ($_ * ($self->{'text_space'} + $h)) + $h/2;

    # do the line first
    $self->{'gd_obj'}->line ($x2, $y2, $x3, $y2, $color);

    # reset the brush for points
    $brush = $self->_prepare_brush($color, 'point',
				$self->{'pointStyle' . $_});
    $self->{'gd_obj'}->setBrush($brush);
    # draw the point
    $self->{'gd_obj'}->line(int(($x3+$x2)/2), $y2,
				int(($x3+$x2)/2), $y2, gdBrushed);

    # now the label
    $x2 = $x3 + (2 * $self->{'text_space'});
    $y2 -= $h/2;
    
    $self->{'gd_obj'}->string ($font, $x2, $y2, $labels[$_], $color);
   
  }

  # mark off the used space
  $self->{'curr_x_max'} -= $width;

  # and return
  return 1;
}


sub _find_y_range {
  my $self = shift;
  my $data = $self->{'dataref'};
  
  my $max = undef;
  my $min = undef;
  my $k=1;
  my $dataset = 1;
  my $datum;
  
  
  
  if ($self->{'pairs'}) {
  for  $dataset ( @$data[1..$#$data] ) {
  # print "dataset @$dataset\n";
    for  $datum ( @$dataset ) {
      if ( defined $datum ) {
#  Prettier, but probably slower:
#         $max = $datum unless defined $max && $max >= $datum;
#         $min = $datum unless defined $min && $min <= $datum;
        if ( defined $max ) {
          if ( $datum > $max ) { $max = $datum }
          elsif ( $datum < $min ) { $min = $datum }
        }
        else { $min = $max = $datum }
      }
    }
  }
 }
 
 if ($self->{'pairs'}) {
# only every second dataset must be checked
 for  $dataset ( @$data[$k] ) {
      for  $datum ( @$dataset ) {
      if ( defined $datum ) {
## Prettier, but probably slower:
#         $max = $datum unless defined $max && $max >= $datum;
#         $min = $datum unless defined $min && $min <= $datum;
          if ( defined $max ) {
            if ( $datum > $max ) { $max = $datum }
          elsif ( $datum < $min ) { $min = $datum }
          }
         else { $min = $max = $datum }
       }
    }
    $k+=2;
  }
 }

 ($min, $max);
}

## be a good module and return 1
1;
