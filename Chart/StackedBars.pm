#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  Chart::StackedBars            #
#                                #
#  written by david bonner       #
#  dbonner@cs.bu.edu             #
#                                #
#  maintained by the Chart Group #
#  Chart@wettzell.ifag.de        #
#                                #
#  theft is treason, citizen     #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#

package Chart::StackedBars;

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

## override check_data to make sure we don't get datasets with positive
## and negative values mixed
sub _check_data {
  my $self = shift;
  my $data = $self->{'dataref'};
  my $length = 0;
  my ($i, $j, $posneg);
  my( $font, $fsize ) = $self->_font_role_to_font( "tick_label" );

  my $composite;
  # remember the number of datasets
  if (defined $self->{'composite_info'}) { 
    if ($self->{'composite_info'}[0][0] =~ /^StackedBars$/i) {
      $composite=0; 
      }
    if ($self->{'composite_info'}[1][0] =~ /^StackedBars$/i) {
      $composite=1;
      }
 # $self->{'num_datasets'} = $#{$data};     ###
  
  $self->{'num_datasets'} = ($#{$self->{'composite_info'}[$composite][1]})+1;
  }
  else {
  $self->{'num_datasets'} = $#{$data}; 
  }
  # remember the number of points in the largest dataset
  $self->{'num_datapoints'} = 0;
  for (0..$self->{'num_datasets'}) { 
  if (scalar(@{$data->[$_]}) > $self->{'num_datapoints'}) {
      $self->{'num_datapoints'} = scalar(@{$data->[$_]});
    }
  }

  # make sure the datasets don't mix pos and neg values
  for $i (0..$self->{'num_datapoints'}-1) {
    $posneg = '';
    for $j (1..$self->{'num_datasets'}) {
      if ($data->[$j][$i] > 0) {
	if ($posneg eq 'neg') {
	  Carp::croak "The values for a Chart::StackedBars data point must either be all positive or all negative";
	}
	else {
	  $posneg = 'pos';
	}
      }
      elsif ($data->[$j][$i] < 0) {
	if ($posneg eq 'pos') {
	  Carp::croak "The values for a Chart::StackedBars data point must either be all positive or all negative";
	}
	else {
	  $posneg = 'neg';
	}
      }
    }
  }

  # find good min and max y-values for the plot
  $self->_find_y_scale;

  $self->{'x_tick_label_height'} = $self->{'x_tick_label_width'} = 0;

  # find the longest x-tick label
  for (@{$data->[0]}) {
	my ($w,$h) = $self->{'surface'}->string_bounds($font,$fsize,$_);
	$self->{'x_tick_label_width'} = $w if( $w > $self->{'x_tick_label_width'} );
	$self->{'x_tick_label_height'} = $h if( $h > $self->{'x_tick_label_height'} );
#    if (length($_) > $length) {
#      $length = length ($_);
#    }
  }

  # now store it in the object
#  $self->{'x_tick_label_length'} = $length;

  return;
}


sub _find_y_range {
  my $self = shift;
  
  #   This finds the minimum and maximum point-sum over all x points,
  #   where the point-sum is the sum of the dataset values for that point.
  #   If the y value in any dataset is undef for a given x, it simply
  #   adds nothing to the sum.
  
  
  my $data = $self->{'dataref'};
  my $max = undef;
  my $min = undef;
  for my $i (0..$#{$data->[0]}) { # data point
    my $sum = $data->[1]->[$i] || 0;
    for my $dataset ( @$data[2..$#$data] ) { # order not important
      my $datum = $dataset->[$i];
      $sum += $datum if defined $datum;
    }
    if ( defined $max ) {
      if ( $sum > $max ) { $max = $sum }
      elsif ( $sum < $min ) { $min = $sum }
    }
    else { $min = $max = $sum }
  }


  # make sure all-positive or all-negative charts get anchored at
  # zero so that we don't cut out some parts of the bars
  if (($max > 0) && ($min > 0)) {
    $min = 0;
  }
  if (($min < 0) && ($max < 0)) {
    $max = 0;
  }

	($min, $max);
}

## finally get around to plotting the data
sub _draw_data {
  my $self = shift;
  my $raw = $self->{'dataref'};
  my $data = [];
  my $misccolor = $self->_color_role_to_rgb('misc');
  my ($width, $height, $delta, $map, $mod);
  my ($x1, $y1, $x2, $y2, $x3, $y3, $i, $j, $color, $cut);
  my $pink = [255,0,255];
  my $line_size = $self->{'line_size'};

  # init the imagemap data field if they want it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }
   
  # width and height of remaining area, delta for width of bars, mapping value
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
   
  if ($self->{'spaced_bars'}) {
   $delta = ($width / ($self->{'num_datapoints'} * 2));
    }
  else {
    $delta = $width / $self->{'num_datapoints'};
    }
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
  $map = $height / ($self->{'max_val'} - $self->{'min_val'});

  # get the base x and y values
  $x1 = $self->{'curr_x_min'};
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
    $self->{'gd_obj'}->line ($self->{'curr_x_min'}, $y1,
                             $self->{'curr_x_max'}, $y1,
			     $misccolor);
  }

  
  # create another copy of the data, but stacked
  $data->[1] = [@{$raw->[1]}];
  for $i (0..$self->{'num_datapoints'}-1) {
    for $j (2..$self->{'num_datasets'}) {
      $data->[$j][$i] = $data->[$j-1][$i] + $raw->[$j][$i];
    }
  }
 
  # draw the damn bars
  for $i (0..$self->{'num_datapoints'}-1) {
    # init the y values for this datapoint
    $y2 = $y1;
    
    
    for $j (1..$self->{'num_datasets'}) {
      # get the color
      $color = $self->_color_role_to_rgb('dataset'.($j-1));
      
      # set up the geometry for the bar
      if ($self->{'spaced_bars'}) {
        $x2 = $x1 + (2 * $i * $delta) + ($delta / 2);
       	$x3 = $x2 + $delta;
	
      }
      else {
        $x2 = $x1 + ($i * $delta);
        $x3 = $x2 + $delta;
      }
      $y3 = $y1 - (($data->[$j][$i] - $mod) * $map);
     
      #cut the bars off, if needed
      if ($data->[$j][$i] > $self->{'max_val'}) {
           $y3 = $y1 - (($self->{'max_val'} - $mod ) * $map) ;
           $cut = 1;
      }
      elsif  ($data->[$j][$i] < $self->{'min_val'}) {
           $y3 = $y1 - (($self->{'min_val'} - $mod ) * $map) ;
           $cut = 1;
      }
      else {
           $cut = 0;
      }
      
      # draw the bar
      ## y2 and y3 are reversed in some cases because GD's fill
      ## algorithm is lame
      if ($data->[$j][$i] > 0) {
        $self->{'surface'}->filled_rectangle($color, 0, $x2, $y3, $x3, $y2);
	if ($self->{'imagemap'}) {
	  $self->{'imagemap_data'}->[$j][$i] = [ $x2, $y3, $x3, $y2 ];
	}
      }
      else {
        $self->{'surface'}->filled_rectangle($color, 0, $x2, $y2, $x3, $y3);
	if ($self->{'imagemap'}) {
	  $self->{'imagemap_data'}->[$j][$i] = [ $x2, $y2, $x3, $y3 ];
	}
      }

      # now outline it. outline red if the bar had been cut off
      unless ($cut){
		  $self->{'surface'}->rectangle($misccolor, $line_size, $x2, $y2, $x3, $y3);
      }
      else {
          $self->{'surface'}->rectangle($misccolor, $line_size, $x2, $y2, $x3, $y3);
          $self->{'surface'}->rectangle($pink, $line_size, $x2, $y1, $x3, $y3);
      }

      # now bootstrap the y values
      $y2 = $y3; 
    }
  }

  
  # and finaly box it off 
  $self->{'surface'}->rectangle(
  			$misccolor,
			$line_size,
			$self->{'curr_x_min'},
			$self->{'curr_y_min'},
			$self->{'curr_x_max'},
			$self->{'curr_y_max'});
  return;
}

## be a good module and return 1
1;
