#====================================================================
#  Chart::Pareto
#
#  written by Chart-Group
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: Pareto.pm,v $ $Revision: 1.2 $ $Date: 2003/02/14 14:18:33 $
# $Author: dassing $
# $Log: Pareto.pm,v $
# Revision 1.2  2003/02/14 14:18:33  dassing
# First setup to cvs
#
#====================================================================

package Chart::Pareto;

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

#calculate the range with the sum dataset1. all datas has to be positiv
sub _find_y_range {
  my $self = shift;
  my $data = $self->{'dataref'};
  my $sum = 0;

  for ( my $i = 0; $i < $self->{'num_datapoints'} ; $i++) {
    if ( $data->[1][$i] >= 0 ) {
      $sum += $data->[1][$i];
    }
    else {
      Carp::carp "We need positiv data, if we want to draw a pareto graph!!";
      return 0;
    }
  }

  #store the sum
  $self->{'sum'} =  $sum;
  #return the range
  (0, $sum);
}

# sort the data
sub _sort_data {
   my $self = shift;
   my $data = $self->{'dataref'};
   my @labels = @{$data->[0]};
   my @values = @{$data->[1]};

   
   # sort the values and their labels
   @labels =  @labels [ sort {$values[$b] <=> $values[$a]} 0..$#labels];
   @values = sort {$b <=> $a} @values;

   #save the sorted values and their labels
   @{$data->[0]} = @labels;
   @{$data->[1]} = @values;
   #finally return
   return 1;
}

#  let them know what all the pretty colors mean
sub _draw_legend {
  my $self = shift;
  my ($length);
  my $num_dataset;
  
  # check to see if legend type is none..
  if ($self->{'legend'} =~ /^none$/) {
    return 1;
  }
  # check to see if they have as many labels as datasets,
  # warn them if not
  if (($#{$self->{'legend_labels'}} >= 0) &&
       ((scalar(@{$self->{'legend_labels'}})) != 2)) {
    Carp::carp "I need two legend labels. One for the data and one for the sum.";
  }

  # init a field to store the length of the longest legend label
  unless ($self->{'max_legend_label'}) {
    $self->{'max_legend_label'} = 0;
  }

  # fill in the legend labels, find the longest one
  unless ($self->{'legend_labels'}[0]) {
     $self->{'legend_labels'}[0] = "Dataset";
  }
  unless ($self->{'legend_labels'}[1]) {
     $self->{'legend_labels'}[1] = "Running sum";
  }

  if (length($self->{'legend_labels'}[0]) >   length($self->{'legend_labels'}[1])) {
      $self->{'max_legend_label'} = length($self->{'legend_labels'}[0]);
  }
  else {
      $self->{'max_legend_label'} = length($self->{'legend_labels'}[1]);
  }
  
  #set the number of datasets to 2, and store it
  $num_dataset = $self->{'num_datasets'};
  $self->{'num_datasets'} = 2;
  
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
    Carp::carp "I can't put a legend there (at ".$self->{'legend'}.")\n";
  }

  #reload the number of datasets
  $self->{'num_datasets'} = $num_dataset;
  
  # and return
  return 1;
}


## finally get around to plotting the data
sub _draw_data {
  my $self = shift;
  my $data = $self->{'dataref'};
  my $misccolor = $self->_color_role_to_rgb('misc');
  my ($x1, $x2, $x3, $y1, $y2, $y3, $y1_line, $y2_line, $x1_line, $x2_line, $h, $w);
  my ($width, $height, $delta1, $delta2, $map, $mod, $cut);
  my ($i, $j, $color, $line_color, $percent, $per_label, $per_label_len);
  my $sum = $self->{'sum'};
  my $curr_sum = 0;
  my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );
  my $pink = $Chart::Base::NAMED_COLORS{'pink'};
  my $diff;
  
  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  # find both delta values ($delta1 for stepping between different
  # datapoint names, $delta2 for setpping between datasets for that
  # point) and the mapping constant
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
  $delta1 = $width / ( $self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
  $diff = ($self->{'max_val'} - $self->{'min_val'});
  $diff = 1 if $diff == 0;
  $map = $height / $diff;
  if ($self->{'spaced_bars'}) {
    $delta2 = $delta1 / 3;
  }
  else {
    $delta2 = $delta1 ;
  }

  # get the base x-y values
  $x1 = $self->{'curr_x_min'};
  $y1 = $self->{'curr_y_max'};
  $y1_line = $y1;
  $mod = $self->{'min_val'};
  $x1_line = $self->{'curr_x_min'};

  # draw the bars and the lines
  $color = $self->_color_role_to_rgb('dataset0');
  $line_color = $self->_color_role_to_rgb('dataset1');
  my $line_size = $self->{line_size};


  # draw every bar for this dataset
  for $j (0..$self->{'num_datapoints'}) {
      # don't try to draw anything if there's no data
      if (defined ($data->[1][$j])) {
        #calculate the percent value for this data and the actual sum;
        $curr_sum += $data->[1][$j];
        $percent = int($curr_sum / $sum * 100);

        # find the bounds of the rectangle
        if ($self->{'spaced_bars'}) {
          $x2 = $x1 + ($j * $delta1) + $delta2;
	}
	else {
	  $x2 = $x1 + ($j * $delta1);
	}
	$y2 = $y1;
	$x3 = $x2 + $delta2;
	$y3 = $y1 - (($data->[1][$j] - $mod) * $map);

        #cut the bars off, if needed
        if ($data->[1][$j] > $self->{'max_val'}) {
           $y3 = $y1 - (($self->{'max_val'} - $mod ) * $map) ;
           $cut = 1;
        }
        elsif  ($data->[1][$j] < $self->{'min_val'}) {
           $y3 = $y1 - (($self->{'min_val'} - $mod ) * $map) ;
           $cut = 1;
        }
        else {
           $cut = 0;
        }
        
	# draw the bar
	## y2 and y3 are reversed in some cases because GD's fill
	## algorithm is lame
        $self->{'surface'}->filled_rectangle ($color, 0, $x2, $y3, $x3, $y2);
        if ($self->{'imagemap'}) {
	    $self->{'imagemap_data'}->[1][$j] = [$x2, $y3, $x3, $y2];
        }
        # now outline it. outline red if the bar had been cut off
        unless ($cut){
	  $self->{'surface'}->rectangle ($misccolor, $line_size, $x2, $y3, $x3, $y2);
        }
        else {

          $self->{'surface'}->rectangle ($pink, $line_size, $x2, $y3, $x3, $y2);
        }
        $x2_line = $x3;
        if ( $self->{'max_val'} >= $curr_sum) {
          #get the y value
          $y2_line = $y1 - (($curr_sum - $mod) * $map);

          #draw the line
          $self->{'surface'}->line ( $line_color, $line_size, $x1_line, $y1_line, $x2_line, $y2_line);
          #draw a little rectangle at the end of the line
          $self->{'surface'}->filled_rectangle($line_color, 0, $x2_line-2, $y2_line-2, $x2_line+2, $y2_line+2);

          #draw the label for the percent value
          $per_label = $percent.'%';
		  ($per_label_len, $h) = $self->{surface}->string_bounds($font, $fsize, $per_label);
          $self->{'surface'}-> string ($line_color, $font, $fsize, $x2_line - $per_label_len -1, $y2_line - 1, 0, $per_label);

          #update the values for next the line
          $y1_line = $y2_line;
          $x1_line = $x2_line;
         }
         else {
          #get the y value
          $y2_line = $y1 - (($self->{'max_val'} - $mod) * $map) ;
          #draw the line
          $self->{'surface'}->line ( $pink, $line_size, $x1_line, $y1_line, $x2_line, $y2_line);
          #draw a little rectangle at the end of the line
          $self->{'surface'}->filled_rectangle( $pink, 0, $x2_line-2, $y2_line-2, $x2_line+2, $y2_line+2);

          #draw the label for the percent value
          $per_label = $percent.'%';
		  ($per_label_len, $h) = $self->{surface}->string_bounds($font, $fsize, $per_label);
          $self->{'surface'}-> string ($pink, $font, $fsize, $x2_line - $per_label_len -1, $y2_line - 1, 0, $per_label);

          #update the values for the next line
          $y1_line = $y2_line;
          $x1_line = $x2_line;
          }

       }
       else {
	  if ($self->{'imagemap'}) {
            $self->{'imagemap_data'}->[1][$j] = [undef(), undef(), undef(), undef()];
          }
      }
  }

      
  # and finaly box it off 
  $self->{'surface'}->rectangle ($misccolor, $line_size, $self->{'curr_x_min'},
  				$self->{'curr_y_min'},
				$self->{'curr_x_max'},
				$self->{'curr_y_max'});
  return;

}

## be a good module and return 1
1;
