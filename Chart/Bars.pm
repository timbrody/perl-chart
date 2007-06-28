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

use Chart::Base 2.4;
use GD;
use Carp;
use strict;

@Chart::Bars::ISA = qw(Chart::Base);
$Chart::Bars::VERSION = '2.4';

use constant PI => 4 * atan2(1, 1);
use constant ANGLE_VERTICAL => (90 / 360) * (2 * PI);
use constant DEBUG => 0;
use constant TRUE => 1;
use constant FALSE => 0;

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

## finally get around to plotting the data
sub _draw_data {
  my $self = shift;
  my $font = 'series_label_font';
  my $data = $self->{'dataref'};
  my $misccolor = $self->_color_role_to_index('misc');
  my ($x1, $x2, $x3, $y1, $y2, $y3);
  my ($width, $height, $delta1, $delta2, $map, $mod, $cut, $pink);
  my (@LABELS, $i, $j, $color, $neg_color);
  my $white = $self->{'gd_obj'}->colorAllocate(255,255,255);
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
     $self->{'gd_obj'}->line ($self->{'curr_x_min'}, $y1,
                              $self->{'curr_x_max'}, $y1,
                              $misccolor);
    }
  
    # get the color for this dataset
    $color = $self->_color_role_to_index('dataset'.($i-1));
	$neg_color = defined($self->{'color_table'}{'neg_dataset'.($i-1)}) ?
		$self->_color_role_to_index('neg_dataset'.($i-1)) :
		$color;
    
	# Draw a line at the zero_offset for the current data set
	if( $zero_offset->[$i-1] ) {
		$self->{'gd_obj'}->setThickness(3);
		$self->{'gd_obj'}->line ($self->{'curr_x_min'}, $y1,
								 $self->{'curr_x_max'}, $y1,
								 $color);
		$self->{'gd_obj'}->setThickness(1);
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
	my ($w,$h) = $self->_gd_string_dimensions($font,$value);
#	if ($data->[$i][$j] > 0) {
	if( $y3 <= $y2 ) {
	  $self->{'gd_obj'}->filledRectangle ($x2, $y3, $x3, $y2, $color);
	  if ($self->{'imagemap'}) {
	    $self->{'imagemap_data'}->[$i][$j] = [$x2, $y3, $x3, $y2];
	  }
	  if( my $style = $self->{'series_label'}[$i-1] ) {
		  if( 1 == $style || $self->_gd_string_width($font,$value) > ($y2-$y3) ) {
			  push @LABELS, [$color,$font,0,int(($x2+$x3)/2-$w/2),$y3-$h-$self->{'text_space'},$value];
		  } else {
			  push @LABELS, [$white,$font,ANGLE_VERTICAL,int(($x2+$x3)/2-$h/2),$y3+$w+$self->{'text_space'},$value];
		  }
	  }
	}
	else {
	  $self->{'gd_obj'}->filledRectangle ($x2, $y2, $x3, $y3, $neg_color);
	  if ($self->{'imagemap'}) {
	    $self->{'imagemap_data'}->[$i][$j] = [$x2, $y2, $x3, $y3];
	  }
	  if( my $style = $self->{'series_label'}[$i-1] ) {
		  if( 1 == $style || $self->_gd_string_width($font,$value) > ($y3-$y2) ) {
			  push @LABELS, [$color,$font,0,int(($x2+$x3)/2-$w/2),$y3+$self->{'text_space'},$value];
		  } else {
			  push @LABELS, [$white,$font,ANGLE_VERTICAL,int(($x2+$x3)/2-$h/2),$y3-$self->{'text_space'},$value];
		  }
	  }
	}

        # now outline it. outline red if the bar had been cut off
    unless ($cut){
	  $self->_gd_rectangle ($x2, $y3, $x3, $y2, $misccolor);
    }
    else {
      $pink = $self->{'gd_obj'}->colorAllocate(255,0,255);
      $self->_gd_rectangle ($x2, $y3, $x3, $y2, $pink);
	  # Line through the bar to indicate it's been cut off
	  $self->{'gd_obj'}->setThickness(int(($x3-$x2)/3) || 1);
	  my $up = $y2 > $y3 ? 1 : -1;
	  $self->{'gd_obj'}->line ($x2, int(($y3+$y2)/2), $x3, int(($y3+$y2)/2)-$up*($x3-$x2), $white);
	  $self->{'gd_obj'}->line ($x2, int(($y3+$y2)/2)+$up*($x3-$x2), $x3, int(($y3+$y2)/2), $white);
	  $self->{'gd_obj'}->setThickness(1);
    }
   }
  }
  
  # render the series labels after columns, otherwise the text gets overwritten
  for(@LABELS) {
	$self->_gd_string(@$_);
  }
  
  # and finaly box it off 
  $self->_gd_rectangle ($self->{'curr_x_min'},
  				$self->{'curr_y_min'},
				$self->{'curr_x_max'},
				$self->{'curr_y_max'},
				$misccolor);
  return;
}

## be a good module and return 1
1;
