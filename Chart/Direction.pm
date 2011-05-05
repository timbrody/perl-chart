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

use Chart::Base 3.0;
use POSIX; # ceil

@ISA = qw(Chart::Base);
$VERSION = $Chart::Base::VERSION;

use strict;

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#

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

#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

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
	     Carp::croak "The the specified 'min_val' & 'max_val' values are reversed (min > max: $d_min>$d_max)";
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
		Carp::carp "Chart::Base : Incorrect value for 'min_circles', too small.\n";
		$minTicks = 2;
	}

	if( $maxTicks < 5*$minTicks  )
	{
		Carp::carp "Chart::Base : Incorrect value for 'max_circles', too small.\n";
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
				Carp::carp "Chart::Base : Caution: Tick limit of $maxTicks exceeded. Backing of to an interval of ".1/$divisor." which plots $tickCount ticks\n";
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
  my $misccolor = $self->_color_role_to_rgb('misc');
  my $textcolor = $self->_color_role_to_rgb('text');
  my $background = $self->_color_role_to_rgb('background');
  my @labels = @{$self->{'y_tick_labels'}};
  my ($width, $height, $centerX, $centerY, $diameter);
  my ($labelX, $labelY, $label_offset);
  my ($dia_delta, $dia, $x, $y, @label_degrees, $arc, $angle_interval);

  my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );

  # set up initial constant values
  $angle_interval = $self->{'angle_interval'};

  if ($self->{'grey_background'}) {
      $background = $self->_color_role_to_rgb('grey_background');
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
     Carp::carp "The angle_interval must be between 0 and 90!\nCorrected value: 30";
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
      $self->{'surface'}->line($misccolor, $self->{line_size}, $centerX, $centerY, $x, $y);
      #calculate the string point
	  my $label = $_.'°';
	  my( $w, $h ) = $self->{surface}->string_bounds($font, $fsize, $label);
      $x = sin ($arc)*($diameter/2+30) + $centerX - $w/2;
      $y = cos  ($arc)*($diameter/2+28) + $centerY + $h/2;
      #draw the labels
      $self->{'surface'}->string($textcolor, $font, $fsize, $x, $y, 0, $label);
      $arc += (($angle_interval)/360) *2*Math::Trig::pi;
  }
      
  #draw the circles
  $dia = $dia_delta;
  foreach (@labels[1..$#labels]) {
      $self->{'surface'}->arc($misccolor, $self->{line_size},
	  				$centerX,
					$centerY,
                    $dia,
					$dia,
                    0,
					2*Math::Trig::pi );
      $dia += $dia_delta;
  }
  
	# white-out the background for the x-labels
	my( $w, $h ) = $self->{surface}->string_bounds(
		$font,
		$fsize,
		$labels[0]
	);
  $self->{'surface'}->filled_rectangle($background, 0,
		  $centerX-$w/2-2,
		  $centerY,
		  $centerX+2+$diameter/2,
		  $centerY+$h+2
		);

  #draw the labels of the circles
  $dia = 0;
  foreach (@labels) {
		my( $w, $h ) = $self->{surface}->string_bounds(
			$font,
			$fsize,
			$_
		);

       $self->{'surface'}->string($textcolor, $font, $fsize, $centerX+$dia/2-$w/2, $centerY+$h+2, 0, $_);
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
	my $misccolor = $self->_color_role_to_rgb('misc');
	my $textcolor = $self->_color_role_to_rgb('text');
	my $background = $self->_color_role_to_rgb('background');
	my ($width, $height, $centerX, $centerY, $diameter);
	my ($mod, $map, $i, $j, $brush, $color, $x, $y, $winkel, $first_x, $first_y );
	my ($arrow_x, $arrow_y, $m);
	$color = 1;
	my $brush_size = $self->{brush_size};

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
			Carp::croak "Wrong number of datasets for 'pairs'";
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


# draw every line for this dataset

	if (!$self->{'pairs'}) { 

		for  $j (1..$self->{'num_datasets'}) {
			my @lines;
			$color = $self->_color_role_to_rgb('dataset'.($j-1));

			for $i (0..$self->{'num_datapoints'}-1) {

# don't try to draw anything if there's no data
				if (defined ($data->[$j][$i]) && $data->[$j][$i] <= $self->{'max_val'}
						&&  $data->[$j][$i] >= $self->{'min_val'}) {

#calculate the point
					$winkel = (180 - ($data->[0][$i] % 360)) /360 * 2* Math::Trig::pi;

					$x = ceil($centerX + sin ($winkel) * ($data->[$j][$i] - $mod) * $map);
					$y = ceil($centerY + cos ($winkel) * ($data->[$j][$i] - $mod) * $map);

					push @lines, [$x, $y];

					if ($self->{'arrow'}) {
						$self->{surface}->line( $color, $brush_size, $centerX, $centerY, $x, $y );
#draw the arrow
						if ($data->[$j][$i] > $self->{'min_val'}) {
							$self->{surface}->point( $color, $brush_size*6, $x, $y, -$winkel + Math::Trig::pi, 'chevron' );
						}
					}

# store the imagemap data if they asked for it
					if ($self->{'imagemap'}) {
						$self->{'imagemap_data'}->[$j][$i] = [$x, $y ];
					}
				} else {
					if ($self->{'imagemap'}) {
						$self->{'imagemap_data'}->[$j][$i] = [ undef(), undef() ];

					}
				}
			} # end of points

# draw the line 
			if ($self->{'line'}) {
				$self->{surface}->polygon ($color, $brush_size, \@lines);
			}
			my $shape = $self->{'pointStyle'.$j};
			if (!$self->{arrow} && $shape) {
				foreach my $p (@lines) {
					$self->{surface}->point ($color, $brush_size*3, @$p, 0, $shape);
				}
			}

		}
	}


	if ($self->{'pairs'}) {
		for  ($j = 1; $j <= $self->{'num_datasets'}; $j+=2) {
			my @lines;
			if ($j ==1) {
				$color = $self->_color_role_to_rgb('dataset'.($j-1));
			}
			else {
				$color = $self->_color_role_to_rgb('dataset'.($j/2-0.5));
			}
			for $i (0..$self->{'num_datapoints'}-1) {

# don't try to draw anything if there's no data
				if (defined ($data->[$j][$i]) && $data->[$j][$i] <= $self->{'max_val'}
						&&  $data->[$j][$i] >= $self->{'min_val'}) {

# calculate the point
					$winkel = (180 - ($data->[$n][$i] % 360)) /360 * 2* Math::Trig::pi;

					$x = ceil($centerX + sin ($winkel) * ($data->[$j][$i] - $mod) * $map);
					$y = ceil($centerY + cos ($winkel) * ($data->[$j][$i] - $mod) * $map);

					push @lines, [$x, $y];


					if ($self->{'arrow'}) {
						$self->{surface}->line( $color, $brush_size, $centerX, $centerY, $x, $y );
#draw the arrow
						if ($data->[$j][$i] > $self->{'min_val'}) {
							$self->{surface}->point( $color, $brush_size*6, $x, $y, -$winkel + Math::Trig::pi, 'chevron' );
						}
					}

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

# draw the line
			if ($self->{'line'}) {
				$self->{surface}->polygon($color, $brush_size, \@lines);
			}
			my $shape = $self->{'pointStyle'.$j};
			if (!$self->{arrow} && $shape) {
				foreach my $p (@lines) {
					$self->{surface}->point ($color, $brush_size*3, @$p, 0, $shape);
				}
			}
			$n+=2;
		}

	}

# now outline it  
	$self->{'surface'}->rectangle ($misccolor,
			$self->{line_size},
			$self->{'curr_x_min'} ,
			$self->{'curr_y_min'},
			$self->{'curr_x_max'},
			$self->{'curr_y_max'});

	return;

}

sub _find_y_range {
  my $self = shift;
  my $data = $self->{'dataref'};
  
  my $max = undef;
  my $min = undef;
  my $k=1;
  my $dataset = 1;
  my $datum;
  
  
  
  if (!$self->{'pairs'}) {
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

# we don't actually have a y_axes
sub _draw_legend {
	my $self = shift;

	local $self->{y_axes};
	return $self->SUPER::_draw_legend (@_);
}

## be a good module and return 1
1;
