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
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
 my $textcolor = $self->_color_role_to_rgb('text');
 my $misccolor = $self->_color_role_to_rgb('misc');
 my ($h, $w, $x1, $y1, ,$y2, $x2, $delta, $width, $label);
 my @labels = @{$self->{'y_tick_labels'}};
  my $line_size = $self->{'line_size'};

 $self->{'grid_data'}->{'x'} = [];
 
 #get height and width of the font
 #($h, $w) = ($font->height, $font->width);
 $h = $self->{'x_tick_label_height'};
 
 #get the right x-value and width
 if ( $self->{'y_axes'} =~ /^right$/i ){
  $x1 = $self->{'curr_x_min'};
  $width = $self->{'curr_x_max'} - $x1 -$self->{'tick_len'} - $self->{'text_space'}
           - $self->{'x_tick_label_width'};
 }
 elsif ( $self->{'y_axes'} =~ /^both$/i) {
  $x1 = $self->{'curr_x_min'} + $self->{'text_space'} + $self->{'x_tick_label_width'}
        + $self->{'tick_len'};
  $width = $self->{'curr_x_max'} - $x1 - $self->{'tick_len'} - $self->{'text_space'}
           - $self->{'x_tick_label_width'};
 }
 else {
  $x1 = $self->{'curr_x_min'} + $self->{'text_space'} + $self->{'x_tick_label_width'}
        + $self->{'tick_len'};
  $width = $self->{'curr_x_max'} - $x1;
 }

 #get the delta value
 $delta = $width / ($self->{'y_ticks'} -1) ;

 #draw the labels
 $y2 =$y1;
 
 if ($self->{'x_ticks'} =~ /^normal/i ) {  #just normal ticks
   #get the point for updating later
   $y1 = $self->{'curr_y_max'} - 2*$self->{'text_space'} -$h - $self->{'tick_len'};
   #get the start point
   $y2 = $y1  + $self->{'tick_len'} + $self->{'text_space'} + $h;
   for (0..$#labels){
		$label = $self->{'y_tick_labels'}[$_];
		$x2 = $x1 + ($delta * $_) - $self->string_width($font,$fsize,$label)/2 ;
		$self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0, $label);
   }
 }
 elsif ($self->{'x_ticks'} =~ /^staggered/i ) {  #staggered ticks
   #get the point for updating later
   $y1 = $self->{'curr_y_max'} - 2*$self->{'text_space'} - 2*$h - $self->{'tick_len'};

   for (0..$#labels) {
   $label = $self->{'y_tick_labels'}[$_];
     $x2 = $x1 + ($delta * $_) - $self->string_width($font,$fsize,$label)/2;
     unless ($_%2) {
		$y2 = $y1  + $self->{'text_space'} + $self->{'tick_len'} + $h;
     }
     else {
		$y2 = $y1  + 2*$h + 2*$self->{'text_space'} + $self->{'tick_len'};
     }
	$self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0, $label);
   }

 }

 elsif ($self->{'x_ticks'} =~ /^vertical/i ) {  #vertical ticks
   #get the point for updating later
   $y1 = $self->{'curr_y_max'} - 2*$self->{'text_space'} - $self->{'y_tick_label_width'} - $self->{'tick_len'};


   for (0..$#labels){
     $label = $self->{'y_tick_labels'}[$_];
     #get the start point
     $y2 = $y1  + $self->{'tick_len'} + $self->string_width($font,$fsize,$label) + $self->{'text_space'};

     $x2 = $x1 + ($delta * $_) - ($h /2);
     $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, Chart::Base::ANGLE_VERTICAL, $label);
   }

 }
 
 else {
  carp "I don't understand the type of x-ticks you specified";
 }
 #update the curr x and y max value
 $self->{'curr_y_max'} = $y1;
 $self->{'curr_x_max'} = $x1 + $width;
 
 #draw the ticks
 $y1 =$self->{'curr_y_max'};
 $y2 =$self->{'curr_y_max'} + $self->{'tick_len'};
 for(0..$#labels ) {
   $x2 = $x1 + ($delta * $_);
   $self->{'surface'}->line($misccolor, $line_size, $x2, $y1, $x2, $y2);
     if ($self->{'grid_lines'} or $self->{'x_grid_lines'}) {
        $self->{'grid_data'}->{'x'}->[$_] = $x2;
     }
 }
 
 return 1;
}

sub _draw_y_ticks {
  my $self = shift;
  my $side = shift || 'left';
  my $data = $self->{'dataref'};
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
  my $textcolor = $self->_color_role_to_rgb ('text');
  my $misccolor = $self->_color_role_to_rgb ('misc');
  my ($h, $x1, $x2,  $y1, $y2);
  my ($width, $height, $delta);
  my $line_size = $self->{'line_size'};

  $self->{'grid_data'}->{'y'} =[];
  
  #get the size of the font
  #($h, $w) = ($font->height, $font->width);
  $h = $self->{'y_tick_label_height'};

  #figure out, where to draw
  if ($side =~ /^right$/i) {
    #get the right startposition
    $x1 = $self->{'curr_x_max'};
    $y1 = $self->{'curr_y_max'} - $h/2;
    
    #get the delta values
    $height =  $self->{'curr_y_max'} - $self->{'curr_y_min'} ;
    $delta = ($height) / ($self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
    $y1 -= ($delta/2 );

    #look if skipping is desired
    if (!defined($self->{'skip_y_ticks'})) {
       $self->{'skip_y_ticks'} =1;
    }
    
    #draw the labels
    for(0.. int (($self->{'num_datapoints'} - 1) / $self->{'skip_y_ticks'})) {
       $y2 = $y1 - ($delta) * ($_ * $self->{'skip_y_ticks'}) + $h;
       $x2 = $x1 + $self->{'tick_len'} + $self->{'text_space'};
       $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0,
                              $self->{f_y_tick}->($data->[0][$_*$self->{'skip_y_ticks'}]));
    }
    
    #draw the ticks
    $x1 = $self->{'curr_x_max'};
    $x2 = $self->{'curr_x_max'} + $self->{'tick_len'};
    $y1 += $h/2;
    for(0..($self->{'num_datapoints'} -1 / $self->{'skip_y_ticks'})) {
           $y2 = $y1 - ($delta * $_);
           $self->{'surface'}->line($misccolor, $line_size, $x1,$y2,$x2,$y2);
           if ($self->{'grid_lines'} or $self->{'x_grid_lines'}) {
              $self->{'grid_data'}->{'y'}->[$_] = $y2;
           }
    }
    
  }
  elsif ($side =~ /^both$/i) {
    #get the right startposition
    $x1 = $self->{'curr_x_max'};
    $y1 = $self->{'curr_y_max'} - $h/2;

    #get the delta values
    $height =  $self->{'curr_y_max'} - $self->{'curr_y_min'} ;
    $delta = ($height) / ($self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
    $y1 -= ($delta/2 );

    #look if skipping is desired
    if (!defined($self->{'skip_y_ticks'})) {
       $self->{'skip_y_ticks'} =1;
    }

    #first draw the right labels
    for(0.. int (($self->{'num_datapoints'} - 1) / $self->{'skip_y_ticks'})) {
       $y2 = $y1 - ($delta) * ($_ * $self->{'skip_y_ticks'}) + $h;
       $x2 = $x1 + $self->{'tick_len'} + $self->{'text_space'};
       $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0,
                              $self->{f_y_tick}->($data->[0][$_*$self->{'skip_y_ticks'}]));
    }

    #then draw the right ticks
    $x1 = $self->{'curr_x_max'};
    $x2 = $self->{'curr_x_max'} + $self->{'tick_len'};
    $y1 += $h/2;
    for(0..($self->{'num_datapoints'} -1 / $self->{'skip_y_ticks'})) {
           $y2 = $y1 - ($delta * $_);
           $self->{'surface'}->line($misccolor,$line_size,$x1,$y2,$x2,$y2);
           if ($self->{'grid_lines'} or $self->{'x_grid_lines'}) {
              $self->{'grid_data'}->{'y'}->[$_] = $y2;
           }
    }

    #get the right startposition
    $x1 = $self->{'curr_x_min'} ;
    $y1 = $self->{'curr_y_max'} -$h/2 ;

    #get the delta values for positioning
    $height =  $self->{'curr_y_max'} - $self->{'curr_y_min'} ;
    $delta = ($height) / ($self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
    $y1 -= ($delta/2 );

    #then draw the left labels
    for(0.. int (($self->{'num_datapoints'} - 1) / $self->{'skip_y_ticks'})) {
       $y2 = $y1 - ($delta) * ($_ * $self->{'skip_y_ticks'}) + $h;
       $x2 = $x1 - $self->string_width($font,$fsize,$self->{f_y_tick}->($data->[0][$_*$self->{'skip_y_ticks'}])) #print the Labels right-sided
             + $self->{'x_tick_label_width'};
       $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0,
                              $self->{f_y_tick}->($data->[0][$_*$self->{'skip_y_ticks'}]));
    }

    #update the curr_x_min val
    $self->{'curr_x_min'} = $x1 + $self->{'text_space'} + $self->{'x_tick_label_width'}
                           + $self->{'tick_len'};

    #finally draw the left ticks
    $x1 = $self->{'curr_x_min'};
    $x2 = $self->{'curr_x_min'} - $self->{'tick_len'};
    $y1 += $h/2;
    for(0..($self->{'num_datapoints'} -1 / $self->{'skip_y_ticks'})) {
           $y2 = $y1 - ($delta * $_);
           $self->{'surface'}->line($misccolor,$line_size,$x1,$y2,$x2,$y2);
           if ($self->{'grid_lines'} or $self->{'x_grid_lines'}) {
              $self->{'grid_data'}->{'y'}->[$_] = $y2;
           }
    }
  }

  else {
    #get the right startposition
    $x1 = $self->{'curr_x_min'} ;
    $y1 = $self->{'curr_y_max'} -$h/2 ;

    #get the delta values for positioning
    $height =  $self->{'curr_y_max'} - $self->{'curr_y_min'} ;
    $delta = ($height) / ($self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
    $y1 -= ($delta/2 );
  
    if (!defined($self->{'skip_y_ticks'})) {
       $self->{'skip_y_ticks'} =1;
    }

    #draw the labels
    for(0.. int (($self->{'num_datapoints'} - 1) / $self->{'skip_y_ticks'})) {
       $y2 = $y1 - ($delta) * ($_ * $self->{'skip_y_ticks'}) + $h;
       $x2 = $x1 - $self->string_width($font,$fsize,$self->{f_y_tick}->($data->[0][$_*$self->{'skip_y_ticks'}])) #print the Labels right-sided
             + $self->{'x_tick_label_width'};
       $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0,
                              $self->{f_y_tick}->($data->[0][$_*$self->{'skip_y_ticks'}]));
    }
    
    #update the curr_x_min val
    $self->{'curr_x_min'} = $x1 + $self->{'text_space'} + $self->{'x_tick_label_width'}
                           + $self->{'tick_len'};
  
    #draw the ticks
    $x1 = $self->{'curr_x_min'};
    $x2 = $self->{'curr_x_min'} - $self->{'tick_len'};
    $y1 += $h/2;
    for(0..($self->{'num_datapoints'} -1 / $self->{'skip_y_ticks'})) {
           $y2 = $y1 - ($delta * $_);
           $self->{'surface'}->line($misccolor,$line_size,$x1,$y2,$x2,$y2);
           if ($self->{'grid_lines'} or $self->{'x_grid_lines'}) {
              $self->{'grid_data'}->{'y'}->[$_] = $y2;
           }
    }
  }
  #now return
  return 1;
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
