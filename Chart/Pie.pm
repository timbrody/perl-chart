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

use Chart::Base 2.4;
use GD;
use Carp;
use strict;

@Chart::Pie::ISA = qw(Chart::Base);
$Chart::Pie::VERSION = '2.4';

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#



#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

#Overwrite the legend methods to get the right legend
sub _draw_right_legend {
  my $self = shift;
  my $data = $self->{'dataref'};
  my @labels = @{$data->[0]};
  my ($x1, $x2, $x3, $y1, $y2, $width, $color, $misccolor, $w, $h, $brush);
  my $font = $self->{'legend_font'};
  my $l1 = 0;
  my $l2 =0;
  my ($i, $j, $label, $dataset_sum);
  my $max_label_len = 1;
  
  # make sure we're using a real font
  unless ((ref ($font)) eq 'GD::Font') {
    croak "The subtitle font you specified isn\'t a GD Font object";
  }

  # get the size of the font
  ($h, $w) = ($font->height, $font->width);

  # get the miscellaneous color
  $misccolor = $self->_color_role_to_index('misc');

  #find out what the sum of all datapoits is, needed for the Labels with percent
  for my $j (0..$self->{'num_datapoints'}) {
     if(defined $data->[1][$j])
        {
          $dataset_sum += $data->[1][$j];
        }
  }
  
  # find out how who wide the largest label text is
  foreach (@labels) {
   if ( length($_) > $l1) {
     $l1 = length($_);
   }
  }
  for (my $i =0 ; $i < ($self->{'num_datapoints'}) ; $i++) {
   if ( length($data->[1][$i]) > $l2  ) {
      $l2 = length($data->[1][$i]);

   }
  }
  
  if ($self->{'legend_label_values'} =~ /^value$/i ) {
    $max_label_len = $l1 + $l2 +1;
  }
  elsif ($self->{'legend_label_values'} =~ /^percent$/i ) {
    $max_label_len = $l1 +7;
  }
  elsif ($self->{'legend_label_values'} =~ /^both$/i ) {
    $max_label_len = $l1 + $l2 +9;
  }
  else {
    $max_label_len = $l1;
  }

  # find out how wide the largest label is
  $width = (2 * $self->{'text_space'})
    #+ ($self->{'max_legend_label'} * $w)
    + $max_label_len *$w
    + $self->{'legend_example_size'}
    + (2 * $self->{'legend_space'});

  # get some starting x-y values
  $x1 = $self->{'curr_x_max'} - $width;
  $x2 = $self->{'curr_x_max'};
  $y1 = $self->{'curr_y_min'} + $self->{'graph_border'} ;
  $y2 = $self->{'curr_y_min'} + $self->{'graph_border'} + $self->{'text_space'}
          + ($self->{'num_datapoints'} * ($h + $self->{'text_space'}))
	  + (2 * $self->{'legend_space'});

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
    if (defined $data->[1][$_]) {
       if ( $self->{'legend_label_values'} =~ /^value$/i ) {
        $self->{'gd_obj'}->string($font, $x2, $y2, $labels[$_].' '.$data->[1][$_], $color);
       }
       elsif ( $self->{'legend_label_values'} =~ /^percent$/i ) {
        $label = sprintf("%s %4.2f%%",$labels[$_], $data->[1][$_] / $dataset_sum * 100);
        $self->{'gd_obj'}->string($font, $x2, $y2, $label, $color);
       }
       elsif ( $self->{'legend_label_values'} =~ /^both$/i ) {
          if ( $data->[1][$_] =~ /\./ ) {
            $label = sprintf("%s %4.2f%% %.2f",$labels[$_], $data->[1][$_] / $dataset_sum * 100, $data->[1][$_]);
          }
          else {
            $label = sprintf("%s %4.2f%% %d",$labels[$_], $data->[1][$_] / $dataset_sum * 100, $data->[1][$_]);
          }
        $self->{'gd_obj'}->string($font, $x2, $y2, $label, $color);
       }
       else {
        $self->{'gd_obj'}->string($font, $x2, $y2, $labels[$_], $color);
      }

    }
  }

  # mark off the used space
  $self->{'curr_x_max'} -= $width;

  # and return
  return 1;
}


## put the legend on the left of the chart
sub _draw_left_legend {
  my $self = shift;
  my $data = $self->{'dataref'};
  my @labels = @{$data->[0]};
  my ($x1, $x2, $x3, $y1, $y2, $width, $color, $misccolor, $w, $h, $brush);
  my $font = $self->{'legend_font'};
  my $max_label_len= 1;;
  my $l1 = 0;
  my $l2 = 0;
  my ($dataset_sum, $label);
  # make sure we're using a real font
  unless ((ref ($font)) eq 'GD::Font') {
    croak "The subtitle font you specified isn\'t a GD Font object";
  }

  # get the size of the font
  ($h, $w) = ($font->height, $font->width);

  # get the miscellaneous color
  $misccolor = $self->_color_role_to_index('misc');

  #find out what the sum of all datapoits is, needed for the Labels with percent
  for my $j (0..$self->{'num_datapoints'}) {
     if(defined $data->[1][$j]) {
       $dataset_sum += $data->[1][$j];
     }
  }

  # find out how who wide the largest label text is
  foreach (@labels) {
   if ( length($_) > $l1) {
     $l1 = length($_);
   }
  }
  for (my $i =0 ; $i < ($self->{'num_datapoints'}) ; $i++) {
   if ( length($data->[1][$i]) > $l2 ) {
      $l2 = length($data->[1][$i]);
   }
  }

  if ($self->{'legend_label_values'} =~ /^value$/i ) {
    $max_label_len = $l1 + $l2 +1;
  }
  elsif ($self->{'legend_label_values'} =~ /^percent$/i ) {
    $max_label_len = $l1 +7;
  }
  elsif ($self->{'legend_label_values'} =~ /^both$/i ) {
    $max_label_len = $l1 + $l2 +9;
  }
  else {
    $max_label_len = $l1;
  }

  # find out how wide the largest label is
  $width = (2 * $self->{'text_space'})
    + ($max_label_len * $w)
    + $self->{'legend_example_size'}
    + (2 * $self->{'legend_space'});

  # get some base x-y coordinates
  $x1 = $self->{'curr_x_min'};
  $x2 = $self->{'curr_x_min'} + $width;
  $y1 = $self->{'curr_y_min'} + $self->{'graph_border'} ;
  $y2 = $self->{'curr_y_min'} + $self->{'graph_border'} + $self->{'text_space'}
          + ($self->{'num_datapoints'} * ($h + $self->{'text_space'}))
	  + (2 * $self->{'legend_space'});

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
    if ( $self->{'legend_label_values'} =~ /^value$/i ) {
        $self->{'gd_obj'}->string($font, $x2, $y2, $labels[$_].' '.$data->[1][$_], $color);
    }
    elsif ( $self->{'legend_label_values'} =~ /^percent$/i ) {
        $label = sprintf("%s %4.2f%%",$labels[$_], $data->[1][$_] / $dataset_sum * 100);
        $self->{'gd_obj'}->string($font, $x2, $y2, $label, $color);
    }
    elsif ( $self->{'legend_label_values'} =~ /^both$/i ) {
        if ($data->[1][$_] =~ /\./) {
           $label = sprintf("%s %4.2f%% %.2f",$labels[$_], $data->[1][$_] / $dataset_sum * 100, $data->[1][$_]);
        }
        else {
           $label = sprintf("%s %4.2f%% %d",$labels[$_], $data->[1][$_] / $dataset_sum * 100, $data->[1][$_]);
        }
        $self->{'gd_obj'}->string($font, $x2, $y2, $label, $color);
    }
    else {
        $self->{'gd_obj'}->string($font, $x2, $y2, $labels[$_], $color);
    }

  }

  # mark off the used space
  $self->{'curr_x_min'} += $width;

  # and return
  return 1;
}


## put the legend on the bottom of the chart
sub _draw_bottom_legend {
  my $self = shift;
  my $data = $self->{'dataref'};
  my @labels =@{$data->[0]};
  my ($x1, $y1, $x2, $x3, $y2, $empty_width, $max_label_width, $cols, $rows, $color, $brush);
  my ($col_width, $row_height, $r, $c, $index, $x, $y, $w, $h);
  my $font = $self->{'legend_font'};
  my $max_label_len;
  my $l1 = 0;
  my $l2 = 0;
  my ($dataset_sum, $j);
  my $label;
  # make sure we're using a real font
  unless ((ref ($font)) eq 'GD::Font') {
    croak "The subtitle font you specified isn\'t a GD Font object";
  }

  # get the size of the font
  ($h, $w) = ($font->height, $font->width);

  # find the base x values
  $x1 = $self->{'curr_x_min'} + $self->{'graph_border'}  ;
         # + ($self->{'y_tick_label_length'} * $self->{'tick_label_font'}->width)
	 # + $self->{'tick_len'} + (3 * $self->{'text_space'});
  $x2 = $self->{'curr_x_max'} - $self->{'graph_border'};
  if ($self->{'y_label'}) {
    $x1 += $self->{'label_font'}->height + 2 * $self->{'text_space'};
  }
  if ($self->{'y_label2'}) {
    $x2 -= $self->{'label_font'}->height + 2 * $self->{'text_space'};
  }

  #find out what the sum of all datapoits is, needed for the Labels with percent
    for $j (0..$self->{'num_datapoints'}) {
        if(defined $data->[1][$j])
        {   $dataset_sum += $data->[1][$j];
          # $sum_total += $data->[1][$j];
        }
     }

  # find out how who wide the largest label text is, especially look what kind of
  # label is needed
  foreach (@labels) {
   if ( length($_) > $l1) {
     $l1 = length($_);
   }
  }
  for (my $i =0 ; $i < ($self->{'num_datapoints'}) ; $i++) {
   if ( length($data->[1][$i]) > $l2  ) {
      $l2 = length($data->[1][$i]);
   }
  }


  if ($self->{'legend_label_values'} =~ /^value$/i ) {
    $max_label_len = $l1 + $l2 +1;
  }
  elsif ($self->{'legend_label_values'} =~ /^percent$/i ) {
    $max_label_len = $l1 +7;
  }
  elsif ($self->{'legend_label_values'} =~ /^both$/i ) {
    $max_label_len = $l1 + $l2 +9;
  }
  else {
    $max_label_len = $l1;
  }
  
  # figure out how wide the columns need to be, and how many we
  # can fit in the space available
  $empty_width = ($x2 - $x1) - (2 * $self->{'legend_space'});
  $max_label_width = $max_label_len * $w
    #$self->{'max_legend_label'} * $w
    + (4 * $self->{'text_space'}) + $self->{'legend_example_size'};
  $cols = int ($empty_width / $max_label_width);
  unless ($cols) {
    $cols = 1;
  }
  $col_width = $empty_width / $cols;

  # figure out how many rows we need, remember how tall they are
  $rows = int ($self->{'num_datapoints'} / $cols);
  unless (($self->{'num_datapoints'} % $cols) == 0) {
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
        if ( $self->{'legend_label_values'} =~ /^value$/i ) {
           $self->{'gd_obj'}->string($font, $x, $y, $labels[$index].' '.$data->[1][$index], $color);
	 #$self->{'gd_obj'}->stringTTF($color, FONT, 10, 0, $x, $y+10, $labels[$index].' '.$data->[1][$index]);     ############
        }
        elsif ( $self->{'legend_label_values'} =~ /^percent$/i ) {
           $label = sprintf("%s %4.2f%%",$labels[$index], $data->[1][$index] / $dataset_sum * 100);
           $self->{'gd_obj'}->string($font, $x, $y, $label, $color);
        }
        elsif ( $self->{'legend_label_values'} =~ /^both$/i ) {
           if ($data->[1][$index] =~ /\./) {
              $label = sprintf("%s %4.2f%% %.2f",$labels[$index], $data->[1][$index] / $dataset_sum * 100, $data->[1][$index]);
           }
           else {
              $label = sprintf("%s %4.2f%% %d",$labels[$index], $data->[1][$index] / $dataset_sum * 100, $data->[1][$index]);
           }
            $self->{'gd_obj'}->string($font, $x, $y, $label, $color); ###
	   # $self->{'gd_obj'}->stringTTF($color, FONT, 10, 0, $x, $y, $label);
  
        }
        else {
           $self->{'gd_obj'}->string($font, $x, $y, $labels[$index], $color);
        }
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
  my $data = $self->{'dataref'};
  my ($max_label_len);
  my $l1 = 0;
  my $l2 = 0;
  my @labels = @{$data->[0]};
  my ($x1, $y1, $x2, $x3, $y2, $empty_width, $max_label_width, $cols, $rows, $color, $brush);
  my ($col_width, $row_height, $r, $c, $index, $x, $y, $w, $h, $dataset_sum, $label);
  my $font = $self->{'legend_font'};

  # make sure we're using a real font
  unless ((ref ($font)) eq 'GD::Font') {
    croak "The subtitle font you specified isn\'t a GD Font object";
  }

  # get the size of the font
  ($h, $w) = ($font->height, $font->width);

  #find out what the sum of all datapoits is, needed for the Labels with percent
    for my $j (0..$self->{'num_datapoints'}) {
        if(defined $data->[1][$j])
        {
           $dataset_sum += $data->[1][$j];
        }
     }
     
  # get some base x coordinates
  $x1 = $self->{'curr_x_min'}
          + $self->{'graph_border'};
         # + $self->{'y_tick_label_length'} * $self->{'tick_label_font'}->width
	 # + $self->{'tick_len'} + (3 * $self->{'text_space'});
  $x2 = $self->{'curr_x_max'} - $self->{'graph_border'};
  if ($self->{'y_label'}) {
    $x1 += $self->{'label_font'}->height + 2 * $self->{'text_space'};
  }
  if ($self->{'y_label2'}) {
    $x2 -= $self->{'label_font'}->height + 2 * $self->{'text_space'};
  }

  # find out how who wide the largest label text is
  foreach (@labels) {
   if ( length($_) > $l1) {
     $l1 = length($_);
   }
  }
  for (my $i =0 ; $i < ($self->{'num_datapoints'}) ; $i++) {
   if ( length($data->[1][$i]) > $l2  ) {
      $l2 = length($data->[1][$i]);
   }
  }

  if ($self->{'legend_label_values'} =~ /^value$/i ) {
    $max_label_len = $l1 + $l2 +1;
  }
  elsif ($self->{'legend_label_values'} =~ /^percent$/i ) {
    $max_label_len = $l1 +7;
  }
  elsif ($self->{'legend_label_values'} =~ /^both$/i ) {
    $max_label_len = $l1 + $l2 +9;
  }
  else {
    $max_label_len = $l1;
  }

  # figure out how wide the columns can be, and how many will fit
  $empty_width = ($x2 - $x1) - (2 * $self->{'legend_space'});
  $max_label_width = (4 * $self->{'text_space'})
   # + ($self->{'max_legend_label'} * $w)
    + $max_label_len * $w
    + $self->{'legend_example_size'};
  $cols = int ($empty_width / $max_label_width);
  unless ($cols) {
    $cols = 1;
  }
  $col_width = $empty_width / $cols;

  # figure out how many rows we need and remember how tall they are
  $rows = int ($self->{'num_datapoints'} / $cols);
  unless (($self->{'num_datapoints'} % $cols) == 0) {
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
        if ( $self->{'legend_label_values'} =~ /^value$/i ) {
         $self->{'gd_obj'}->string($font, $x, $y, $labels[$index].' '.$data->[1][$index], $color);
        }
        elsif ( $self->{'legend_label_values'} =~ /^percent$/i ) {
         $label = sprintf("%s %4.2f%%",$labels[$index], $data->[1][$index] / $dataset_sum * 100);
         $self->{'gd_obj'}->string($font, $x, $y, $label, $color);
        }
        elsif ( $self->{'legend_label_values'} =~ /^both$/i ) {
          if ( $data->[1][$index] =~ /\./) {
             $label = sprintf("%s %4.2f%% %.2f",$labels[$index], $data->[1][$index] / $dataset_sum * 100, $data->[1][$index]);
          }
          else {
             $label = sprintf("%s %4.2f%% %d",$labels[$index], $data->[1][$index] / $dataset_sum * 100, $data->[1][$index]);
          }
          $self->{'gd_obj'}->string($font, $x, $y, $label, $color);
        }
        else {
         $self->{'gd_obj'}->string($font, $x, $y, $labels[$index], $color);
        }
       }
    }
  }

  # mark off the space used
  $self->{'curr_y_min'} += ($rows * $row_height) + $self->{'text_space'}
			      + 2 * $self->{'legend_space'};

  # now return
  return 1;
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
  my $misccolor = $self->_color_role_to_index('misc');
  my $textcolor = $self->_color_role_to_index('text');
  my $background = $self->_color_role_to_index('background');
  my ($width, $height, $centerX, $centerY, $diameter);
  my $sum_total;
  my $dataset_sum;
  my ($start_degrees, $end_degrees, $label_degrees, $max_label_len);
  my ($pi, $font, $fontW, $fontH, $labelX, $labelY, $label_offset);
  my ($last_labelX, $last_labelY, $label, $max_val_len);
  my ($last_dlabelX, $last_dlabelY);
  my ($i, $j, $color);
  my ($label_length, $last_dlabel_length); 
  my ($label_width, $label_height);
  my @LABELS;

  # set up initial constant values
  $pi = 3.14159265;
  $start_degrees=0;
  $end_degrees=0;
  $font = $self->{'legend_font'};
  $font = 'label_font';
  $label_offset = .55;
  $fontW = $self->{'legend_font'}->width;
  $fontH = $self->{'legend_font'}->height;
  $last_labelX = $last_dlabelX = 0;
  $last_labelY = $last_dlabelY = 0;
  my $white = $self->{gd_obj}->colorAllocateAlpha(255,255,255,32);

  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  # find width and height
  $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
  $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};

  # find the longest label
  # first we need the length of the values
  $max_val_len = 1;
  for  (0..$self->{'num_datapoints'}) {   
     if (defined $data->[1][$_]) {
        if ( length($data->[1][$_]) > $max_val_len) {
         $max_val_len = length($data->[1][$_]);
     }
   }
 
  }
 
  # now the whole label
  $max_label_len = 1;
  for $j (0..$self->{'num_datapoints'}) {
     if(defined $data->[0][$j]) {
        if( length($data->[0][$j]) > $max_label_len) {
           $max_label_len = length($data->[0][$j]);
       }
     }
   
  }

  if ( defined $self->{'label_values'} ) {
    if ($self->{'label_values'} =~ /^value$/i) {
      $max_label_len += $max_val_len + 1;
    }
    elsif ( $self->{'label_values'} =~ /^both$/i ){
      $max_label_len += $max_val_len + 7;
    }
    elsif ( $self->{'label_values'} =~ /^percent$/i ) {
      $max_label_len += 6;
    }
  }
  $max_label_len *= $fontW;

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
   croak "I have calculated a negative diameter for the pie chart, maybe your labels are to long or the picture is to small.";
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
             croak "We need positiv data for a pie chart!";
           }
        }
   }
   
   for $j (0..($self->{'num_datapoints'}-1)) {
      # get the color for this datapoint, take the color of the datasets
      $color = $self->_color_role_to_index('dataset'.$j);
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
	
		($label_width, $label_height) = $self->_gd_string_dimensions($font,$label);
	
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
	$self->{'gd_obj'}->setAntiAliased($color);
	$self->_gd_arc($centerX,$centerY,
					$diameter,$diameter,
					$start_degrees, $end_degrees,
					gdAntiAliased,
					1);
 
 	# Add a border around the segment
	$self->{'gd_obj'}->setAntiAliased($misccolor);
    $self->_gd_arc($centerX,$centerY,
                    $diameter, $diameter,
                    $start_degrees, 360,
                    gdAntiAliased,
					0);

    # Figure out where to place the label
    $labelX = $centerX+$label_offset*$diameter*cos($label_degrees*$pi/180);
    $labelY = $centerY+$label_offset*$diameter*sin($label_degrees*$pi/180);

   
    # If label is to the left of the pie chart, make sure the label doesn't
    # bleed into the chart. So, back it up the length of the label
    if($labelX < $centerX)
    {
       $labelX -= $label_width;
    }

    # Same thing if the label is above the chart. Don't go too low.
    if($labelY < $centerY)
    {
       $labelY -= $label_height;
    }

    # Okay, if a bunch of very small datasets are close together, they can
    # overwrite each other. The following if statement is to help keep
    # labels of neighbor datasets from beong overlapped. It ain't perfect,
    # but it des a pretty good job.
	goto SKIP;
	if($label_degrees <= 90 || $label_degrees >= 270)
	{
       if(($labelY - $last_labelY) < $fontH                                      && 
          sqrt(($labelY-$last_labelY)**2 + ($labelX-$last_labelX)**2) < $fontH*2 &&
           $last_labelY > 0)
       {
          $labelY = $last_labelY + $fontH;
       }
    }
    else
    {
       if(($last_labelY - $labelY) < $fontH                                      &&
          sqrt(($labelY-$last_labelY)**2 + ($labelX-$last_labelX)**2) < $fontH*2 &&
          $last_labelY > 0)
       {
          $labelY = $last_labelY - $fontH;
       }
    }
	SKIP:

    # Now, draw the label for this pie slice
    
    # Is enought space inside the border for the labels?   
    
#warn "$self->{curr_x_min}/$self->{curr_x_max}/$self->{curr_y_min}/$self->{curr_y_max}";
#  while ($labelX-($label_length*$fontW)<$self->{'curr_x_min'}) {
#       $labelX+=1;
# 	}
  
#  while ($labelX+($label_length*$fontW)>$self->{'curr_x_max'}) {
#        $labelX-=1;
# 	}
  # Shift the label in if it falls outside of the drawing area
  if( $labelX < $self->{'curr_x_min'} ) {
	  $labelY += abs($self->{'curr_x_min'}-$labelX)*tan($label_degrees*$pi/180);
	  $labelX = $self->{'curr_x_min'};
  } elsif( ($labelX+$label_width) > $self->{'curr_x_max'} ) {
	  $labelY += abs(($labelX+$label_width)-$self->{'curr_x_max'})*tan($label_degrees*$pi/180);
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
	  $self->{'gd_obj'}->filledRectangle(
	  	$label{x},$label{y},
		$label{x}+$label{width},$label{y}+$label{height},
		$white
	  );
	  $self->_gd_string($textcolor, $font, 0, $label{x}, $label{y}, $label{label});
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

sub tan { sin($_[0]) / cos($_[0]) }

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
