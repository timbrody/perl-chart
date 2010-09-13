#====================================================================
#  Chart::Bars
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
# $RCSfile: Bars.pm,v $ $Revision: 1.4 $ $Date: 2003/02/14 13:10:05 $
# $Author: dassing $
# $Log: Bars.pm,v $
# Revision 1.4  2003/02/14 13:10:05  dassing
# Circumvent division of zeros
#
#====================================================================

package Chart::Bars;

use Chart::Base 3.0;

@ISA = qw(Chart::Base);
$VERSION = $Chart::Base::VERSION;

use strict;

use constant DEBUG => 0;

=pod

=head1 NAME

Chart::Bars - Bar Charts

=head1 DESCRIPTION

Vertical bar chart.

=head1 SYNOPSIS

	use Chart::Bars;

	my $ch = new Chart::Bars(640,480);

	$ch->set(
		key=>value,
	);

=cut

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#


#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

sub _draw_legend_entry_example {
	my( $self, $color, $x, $y, $h, $shape ) = @_;

	my $legend_example_size = $self->{'legend_example_size'};
	my $misccolor = $self->_color_role_to_rgb('misc');

	my $x2 = $x + $legend_example_size;
	my $y2 = $y;
	$y -= $h;

	# draw a square for bars
	$self->{'surface'}->filled_rectangle($color,
			0,
			$x, $y, 
			$x2, $y2);

	$self->{'surface'}->rectangle($misccolor,
			$self->{'line_size'},
			$x, $y, 
			$x2, $y2);
}

## finally get around to plotting the data
sub _draw_data {
  my $self = shift;
  my( $font, $fsize ) = $self->_font_role_to_font( 'series_label' );
  my $data = $self->{'dataref'};
  my $misccolor = $self->_color_role_to_rgb('misc');
  my $white = $self->_color_spec_to_rgb('data_label','white');
  my $pink = [255,0,255];
  my ($x1, $x2, $x3, $y1, $y2, $y3);
  my ($width, $height, $delta1, $delta2, $map, $mod, $cut);
  my (@LABELS, $i, $j, $color, $neg_color);
  my $zero_offset = $self->{'zero_offset'} || [];
  if( ref($zero_offset) eq 'ARRAY' ) {
	  for(1..$self->{'num_datasets'}) {
		  $zero_offset->[$_-1] ||= 0;
	  }
  } else {
	  $zero_offset = [$zero_offset];
	  for(2..$self->{'num_datasets'}) {
		  $zero_offset->[$_-1] = $zero_offset->[0];
	  }
  }
 
  my $bar_border_size = $self->{'bar_border_size'};
  $bar_border_size = $self->{'line_size'} unless defined $bar_border_size;

  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  # find both delta values ($delta1 for stepping between different
  # datapoint names, $delta2 for stepping between datasets for that
  # point) and the mapping constant
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
  $delta1 = ( $self->{'num_datapoints'} > 0 ) ? $width / ($self->{'num_datapoints'}*1) : $width;    ###
 
   $map = ( ($self->{'max_val'} - $self->{'min_val'}) > 0 ) ? $height / ($self->{'max_val'} - $self->{'min_val'}) : $height;
  if ($self->{'spaced_bars'}) {
    #OLD: $delta2 = $delta1 / ($self->{'num_datasets'} + 2);
    $delta2 = ( ($self->{'num_datasets'} + 2) > 0 ) ? $delta1 / ($self->{'num_datasets'} + 2) : $delta1;
    }
  else {
    $delta2 = ( $self->{'num_datasets'} > 0 ) ? $delta1 / $self->{'num_datasets'} : $delta1;
  }

  # draw the bars
  for $i (1..$self->{'num_datasets'}) {   
    # get the base x-y values
    $x1 = $self->{'curr_x_min'};

    if ($self->{'min_val'} >= 0) {
      $y1 = $self->{'curr_y_max'} - $map * $zero_offset->[$i-1];
      $mod = $self->{'min_val'};
    }
    elsif ($self->{'max_val'} <= 0) {
      $y1 = $self->{'curr_y_min'} - $map * $zero_offset->[$i-1];
      $mod = $self->{'max_val'};
    }
    else {
     $y1 = $self->{'curr_y_min'} + ($map * ($self->{'max_val'} - $zero_offset->[$i-1]));
     $mod = 0;
     $self->{'surface'}->line(
	 		$misccolor,
			1,
	 		$self->{'curr_x_min'}, $y1,
			$self->{'curr_x_max'}, $y1);
    }
  
    # get the color for this dataset
    $color = $self->_color_role_to_rgb('dataset'.($i-1));
	$neg_color = defined($self->{'color_table'}{'neg_dataset'.($i-1)}) ?
		$self->_color_role_to_rgb('neg_dataset'.($i-1)) :
		$color;
    
	# Draw a line at the zero_offset for the current data set
	if( $zero_offset->[$i-1] ) {
		$self->{'surface'}->line(
			$color,
			3,
			$self->{'curr_x_min'}, $y1,
			$self->{'curr_x_max'}, $y1);
	}
	
    # draw every bar for this dataset
    for $j (0..$self->{'num_datapoints'}) {
    
      # don't try to draw anything if there's no data
      if (!defined ($data->[$i][$j])) {
	  	if ($self->{'imagemap'}) {
            $self->{'imagemap_data'}->[$i][$j] = [undef(), undef(), undef(), undef()];
        }
		next;
	  }
		# find the bounds of the rectangle
        if ($self->{'spaced_bars'}) {
          $x2 = ($x1 + ($j * $delta1) + ($i * $delta2)); 
	  	} else {
	  	  $x2 = $x1 + ($j * $delta1) + (($i - 1) * $delta2);
	    }
		$y2 = $y1;
		$x3 = $x2 + $delta2;
		$y3 = $y1 - (($data->[$i][$j] - $mod - $zero_offset->[$i-1]) * $map);
	
        #cut the bars off, if needed
        if ($data->[$i][$j] > $self->{'max_val'}) {
           $y3 = $y1 - (($self->{'max_val'} - $mod - $zero_offset->[$i-1]) * $map) ;
           $cut = TRUE;
        }
        elsif  ($data->[$i][$j] < $self->{'min_val'}) {
           $y3 = $y1 - (($self->{'min_val'} - $mod - $zero_offset->[$i-1]) * $map) ;
           $cut = TRUE;
        }
        else {
           $cut = FALSE;
        }
        	
	# draw the bar
	## y2 and y3 are reversed in some cases because GD's fill
	## algorithm is lame
	my $value = &{$self->{'f_y_tick'}}($data->[$i][$j] - $zero_offset->[$i-1]);
	my ($w,$h) = $self->{'surface'}->string_bounds($font,$fsize,$value);
	if( $y3 <= $y2 ) {
		if( $self->{'f_bar_color'} )
		{
			$color = &{$self->{'f_bar_color'}}($data->[$i][$j], $color);
		}
	  $self->{'surface'}->filled_rectangle($color, 0, $x2, $y3, $x3, $y2);
	  if ($self->{'imagemap'}) {
	    $self->{'imagemap_data'}->[$i][$j] = [$x2, $y3, $x3, $y2];
	  }
	  if( my $style = $self->{'series_label'}[$i-1] ) {
		  if( 1 == $style || $self->string_width($font,$fsize,$value) > ($y2-$y3) ) {
			  push @LABELS, [$color,$font,$fsize,int(($x2+$x3)/2-$w/2),$y3-$h-$self->{'text_space'},0,$value];
		  } else {
			  push @LABELS, [$white,$font,$fsize,int(($x2+$x3)/2-$h/2),$y3+$w+$self->{'text_space'},ANGLE_VERTICAL,$value];
		  }
	  }
	}
	else {
		if( $self->{'f_bar_color'} )
		{
			$neg_color = &{$self->{'f_bar_color'}}($data->[$i][$j], $neg_color);
		}
	  $self->{'surface'}->filled_rectangle($neg_color, 0, $x2, $y2, $x3, $y3);
	  if ($self->{'imagemap'}) {
	    $self->{'imagemap_data'}->[$i][$j] = [$x2, $y2, $x3, $y3];
	  }
	  if( my $style = $self->{'series_label'}[$i-1] ) {
		  if( 1 == $style || $self->string_width($font,$fsize,$value) > ($y3-$y2) ) {
			  push @LABELS, [$color,$font,$fsize,int(($x2+$x3)/2-$w/2),$y3+$self->{'text_space'},0,$value];
		  } else {
			  push @LABELS, [$white,$font,$fsize,int(($x2+$x3)/2-$h/2),$y3-$self->{'text_space'},ANGLE_VERTICAL,$value];
		  }
	  }
	}

    # now outline it. outline red if the bar had been cut off
    if( $cut )
	{
      $self->{'surface'}->rectangle($pink, $bar_border_size, $x2, $y3, $x3, $y2);
	  # Line through the bar to indicate it's been cut off
	  my $line_size = int(($x3-$x2)/3) || 1;
	  my $up = $y2 > $y3 ? 1 : -1;
	  $self->{'surface'}->line($white, $line_size, $x2, int(($y3+$y2)/2), $x3, int(($y3+$y2)/2)-$up*($x3-$x2));
	  $self->{'surface'}->line($white, $line_size, $x2, int(($y3+$y2)/2)+$up*($x3-$x2), $x3, int(($y3+$y2)/2));
    }
	else
	{
	  $self->{'surface'}->rectangle($misccolor, $bar_border_size, $x2, $y3, $x3, $y2);
	}
   }
  }
  
  # render the series labels after columns, otherwise the text gets overwritten
  for(@LABELS) {
	$self->{'surface'}->string(@$_);
  }
  
  # and finally box it off 
  $self->{'surface'}->rectangle(
		$misccolor,
		1,
		$self->{'curr_x_min'},
		$self->{'curr_y_min'},
		$self->{'curr_x_max'},
		$self->{'curr_y_max'});

}

## be a good module and return 1
1;
