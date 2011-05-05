#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  Chart::Pie                    #
#                                #
#  written by Chart Group        #
#                                #
#  maintained by the Chart Group #
#  Chart@wettzell.ifag.de        #
#                                #
#                                #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#

package Chart::Pie;

use Chart::Base 3.0;
use Math::Trig;
use Chart::Bars; # legend example

@ISA = qw(Chart::Base);
$VERSION = $Chart::Base::VERSION;

use strict;

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#



#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

# a pie chart legend consists of a single dataset, so lets render the X-axis labels as the legend
sub _draw_legend
{
	my $self = shift;

	# localise the dataset labels
	local $self->{'legend_labels'} = $self->{'dataref'}->[0];
	local $self->{'num_datasets'} = scalar @{$self->{'legend_labels'}};

	$self->SUPER::_draw_legend();
}

sub _draw_legend_entry_example {
	return shift->Chart::Bars::_draw_legend_entry_example( @_ );
}

# Override the ticks methods for the pie charts
# as they do not always make sense.
sub _draw_x_ticks {
  my $self = shift;

  return;
}
sub _draw_y_ticks {
  my $self = shift;

  return;
}

sub _find_y_scale {
  my $self = shift;

  # Disable the y axes
  $self->{'y_axes'} = undef;

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
  my $sum_total;
  my $dataset_sum;
  my ($start_degrees, $end_degrees, $label_degrees, $max_label_len);
  my ($labelX, $labelY, $label_offset);
  my ($last_labelX, $last_labelY, $label, $max_val_len);
  my ($last_dlabelX, $last_dlabelY);
  my ($i, $j, $color);
  my ($label_length, $last_dlabel_length); 
  my ($label_width, $label_height);
  my @LABELS;
  my $line_size = $self->{'line_size'};

  # set up initial constant values
  $start_degrees=0;
  $end_degrees=0;
  my( $font, $fsize ) = $self->_font_role_to_font( 'label' );
  $label_offset = .55;
  $last_labelX = $last_dlabelX = 0;
  $last_labelY = $last_dlabelY = 0;
  my $white = [255,255,255,127];

  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  # find width and height
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};

  # find the longest label
  # first we need the length of the values
  $max_val_len = 0;
  for $j (0..$self->{'num_datapoints'}) {   
	  next unless defined $data->[1][$j];

	  my $len = $self->string_width( $font, $fsize, $data->[1][$j] );
	  $max_val_len = $len if $len > $max_val_len;
  }
 
  # now the whole label
  $max_label_len = 0;
  for $j (0..$self->{'num_datapoints'}) {
	  next unless defined $data->[0][$j];

	  my $len = $self->string_width( $font, $fsize, $data->[1][$j] );
	  $max_label_len = $len if $len > $max_label_len;
  }

  my $space_len = $self->string_width( $font, $fsize, " " );
  my( $percent_len, $fontH ) = $self->{'surface'}->string_bounds( $fsize, $fsize, "00.00%" );

  if ( defined $self->{'label_values'} ) {
    if ($self->{'label_values'} =~ /^value$/i) {
      $max_label_len += $max_val_len + $space_len;
    }
    elsif ( $self->{'label_values'} =~ /^percent$/i ) {
      $max_label_len += $percent_len;
    }
    elsif ( $self->{'label_values'} =~ /^both$/i ){
      $max_label_len += $max_val_len + $percent_len + $space_len;
    }
  }

  # find center point, from which the pie will be drawn around
  $centerX = int($width/2)  + $self->{'curr_x_min'};
  $centerY = int($height/2) + $self->{'curr_y_min'};

  # always draw a circle, which means the diameter will be the smaller
  # of the width and height. let enougth space for the label.
  
 
  
  	if ($width < $height) {
		$diameter = .9 * $width;
		#$diameter = $width - 2*$max_label_len -20;
	}
  	else {
		$diameter = .9 * $height;
		#$diameter = $height  - 2*$fontH -20 ;
		#if ( $width < ($diameter + 2 * $max_label_len) ) {
		#	$diameter = $width - 2*$max_label_len -20 ;
		#}
  	}

  # make sure, that we have a positiv diameter
  if ($diameter < 0) {
   Carp::croak "I have calculated a negative diameter for the pie chart, maybe your labels are to long or the picture is to small.";
  }
  
  # okay, add up all the numbers of all the datasets, to get the
  # sum total. This will be used to determine the percentage 
  # of each dataset. Obviously, negative numbers might be bad :)
  $sum_total=0;

   for $j (0..$self->{'num_datapoints'}) {
        if(defined $data->[1][$j])
        {  #add to sum
           $dataset_sum += $data->[1][$j];
           #don't allow negativ values
           if ($data->[1][$j] < 0) {
             Carp::croak "We need positiv data for a pie chart!";
           }
        }
   }
   
   for $j (0..($self->{'num_datapoints'}-1)) {
      # get the color for this datapoint, take the color of the datasets
      $color = $self->_color_role_to_rgb('dataset'.$j);
      # don't try to draw anything if there's no data
      if (defined ($data->[1][$j])) {
         $label = $data->[0][$j];
         if(defined $self->{'label_values'})  {
              if($self->{'label_values'} =~ /^percent$/i)
               {
                 $label = sprintf("%s %4.2f%%",$label, $data->[1][$j] / $dataset_sum * 100);
               }
              elsif($self->{'label_values'} =~ /^value$/i)
               {
                 if ($data->[1][$j] =~ /\./) {
                   $label = sprintf("%s %.2f",$label, $data->[1][$j]);
                 }
                 else {
                   $label = sprintf("%s %d",$label,$data->[1][$j]);
                 }
               }
              elsif($self->{'label_values'} =~ /^both$/i)
               {
                 if ($data->[1][$j] =~ /\./) {
                   $label = sprintf("%s %4.2f%% %.2f",$label,
                                          $data->[1][$j] / $dataset_sum * 100,
                                          $data->[1][$j]);
                 }
                 else {
                   $label = sprintf("%s %4.2f%% %d",$label,
                                          $data->[1][$j] / $dataset_sum * 100,
                                          $data->[1][$j]);
                 }
               }
               elsif($self->{'label_values'} =~ /^none$/i)
               {
                 $label = sprintf("%s",$label);
               }
        }
	
		$label_length = length($label);
	
		($label_width, $label_height) = $self->{'surface'}->string_bounds($font,$fsize,$label);
      }
  

    # The first value starts at 0 degrees, each additional dataset
    # stops where the previous left off, and since I've already 
    # calculated the sum_total for the whole graph, I know that
    # the final pie slice will end at 360 degrees.

    # So, get the degree offset for this dataset
    $end_degrees = $start_degrees + ($data->[1][$j] / $dataset_sum  * 360);

    # stick the label in the middle of the slice
    $label_degrees = ($start_degrees + $end_degrees) / 2;

	# Draw the segment
	$self->{'surface'}->filled_segment( $color, 0, $centerX, $centerY, $diameter, $diameter, $start_degrees/180*pi, $end_degrees/180*pi );
 
 	# Add a border around the segment
	$self->{'surface'}->segment( $misccolor, -1*abs($line_size), $centerX, $centerY, $diameter, $diameter, $start_degrees/180*pi, $end_degrees/180*pi );

    # Figure out where to place the label
    $labelX = $centerX+$label_offset*$diameter*cos($label_degrees*pi/180);
    $labelY = $centerY+$label_offset*$diameter*sin($label_degrees*pi/180);

   
    # If label is to the left of the pie chart, make sure the label doesn't
    # bleed into the chart. So, back it up the length of the label
    if($labelX < $centerX)
    {
       $labelX -= $label_width;
    }

    # label is below chart
    if($labelY > $centerY)
    {
       $labelY += $label_height;
    }

  # Shift the label in if it falls outside of the drawing area
  if( $labelX < $self->{'curr_x_min'} ) {
	  $labelY += abs($self->{'curr_x_min'}-$labelX)*tan($label_degrees*pi/180);
	  $labelX = $self->{'curr_x_min'};
  } elsif( ($labelX+$label_width) > $self->{'curr_x_max'} ) {
	  $labelY += abs(($labelX+$label_width)-$self->{'curr_x_max'})*tan($label_degrees*pi/180);
	  $labelX = $self->{'curr_x_max'}-$label_width;
  }
 	
  	if ($labelY < $self->{'curr_y_min'}) {
	  	$labelY = $self->{'curr_y_min'}
  	}
 	
  	if(($labelY+$fontH)>=$self->{'curr_y_max'}) {
		$labelY = $self->{'curr_y_max'}-$fontH;
 	}	

	push @LABELS, {
		x=>$labelX,
		y=>$labelY,
		angle=>$label_degrees,
		label=>$label,
		width=>$label_width,
		height=>$label_height,
	};
      
    # reset starting point for next dataset and continue.
    $start_degrees = $end_degrees;
    $last_labelX = $labelX;
    $last_labelY = $labelY;
  }
  
  # Try shifting the previous label
  for(my $i = 2; $i < @LABELS; $i++) {
	  if( _intersects($LABELS[$i],$LABELS[$i-1]) ) {
		  my %test = %{$LABELS[$i-1]};
		  if( $LABELS[$i]->{y} < $centerY && $LABELS[$i]->{angle} <= 270 ) { # Top left
			  $test{y} += $test{height};
			  if( _intersects(\%test,$LABELS[$i-2]) ) {
				  $LABELS[$i]->{y} -= $LABELS[$i]->{height};
			  } else {
				  $LABELS[$i-1] = \%test;
			  }
		  } elsif( $LABELS[$i]->{y} >= $centerY && $LABELS[$i]->{angle} >= 90 ) { # Bottom left
			  $test{y} -= $test{height};
			  next if( $test{y} > $self->{'curr_y_max'} );
			  if( _intersects(\%test,$LABELS[$i-2]) ) {
				  $LABELS[$i]->{y} += $LABELS[$i]->{height};
			  } else {
				  $LABELS[$i-1] = \%test;
			  }
		  } elsif( $LABELS[$i]->{y} < $centerY ) { # Top right
			  $test{y} -= $test{height};
			  next if( $test{y} < $self->{'curr_y_min'} );
			  if( _intersects(\%test,$LABELS[$i-2]) ) {
				  $LABELS[$i]->{y} += $LABELS[$i]->{height};
			  } else {
				  $LABELS[$i-1] = \%test;
			  }
		  } else { # Bottom right
			  $test{y} -= $test{height};
			  next if( $test{y} < $centerY ); # Don't encroach before the beginning
			  if( _intersects(\%test,$LABELS[$i-2]) ) {
				  $LABELS[$i]->{y} += $LABELS[$i]->{height};
			  } else {
				  $LABELS[$i-1] = \%test;
			  }
		  }
	  }
  }
  # Remove labels if we still can't fit them in
  for(my $i = 0; $i < @LABELS; $i++) {
	  if( $i > 0 ) {
		  my $j;
		  for($j = 0; $j < $i; $j++) {
	 		  if( _intersects($LABELS[$i],$LABELS[$j]) ) {
				  splice(@LABELS,$i,1);
				  last;
			  }
		  }
		  if( $j != $i ) {
			  $i--;
			  next;
		  }
	  }
	  my %label = %{$LABELS[$i]};
	  $self->{'surface'}->filled_rectangle(
	  	$white,
		0,
	  	$label{x}-$self->{'text_space'},$label{y}-$self->{'text_space'}-$label{height},
		$label{x}+$label{width}+$self->{'text_space'},$label{y}+$self->{'text_space'}
	  );
	  $self->{'surface'}->string($textcolor, $font, $fsize, $label{x}, $label{y}, 0, $label{label});
  }
  # and finaly box it off 
  # No other charts do this, so neither should Pie
  #$self->{'gd_obj'}->rectangle ($self->{'curr_x_min'},
  #                              $self->{'curr_y_min'},
  #                              $self->{'curr_x_max'},
  #                              $self->{'curr_y_max'},
  #                              $misccolor);
  return;

}

# x/y are the top left corner!
sub _intersects
{
	my ($a,$b) = @_;
	return !(
		$a->{x} < $b->{x}-$a->{width} ||
		$a->{x} > $b->{x}+$b->{width} ||
		$a->{y} < $b->{y}-$a->{height} ||
		$a->{y} > $b->{y}+$b->{height}
	);
}

## be a good module and return 1
1;
