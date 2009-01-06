#====================================================================
#  Chart::Composite
#
#  written by david bonner
#  dbonner@cs.bu.edu
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: Composite.pm,v $ $Revision: 1.4 $ $Date: 2003/02/14 13:25:30 $
# $Author: dassing $
# $Log: Composite.pm,v $
# Revision 1.4  2003/02/14 13:25:30  dassing
# Circumvent division of zeros
#
#====================================================================

package Chart::Composite;

use Chart::Base 2.4;
use GD;
use Carp;
use strict;

use constant DEBUG => 0;
use constant TRUE => 1;
use constant FALSE => 0;

@Chart::Composite::ISA = qw(Chart::Base);
$Chart::Composite::VERSION = '2.4';

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#

## have to override set, so we can pass the options to the 
## sub-objects later
sub set {
  my $self = shift;
  my %opts = @_;

  $self->SUPER::set(%opts);
  
  # store the options they gave us to pass onto subs
  while(my( $key, $value ) = each %opts)
  {
	  $self->{'opts'}->{$key} = $value;
  }

  # now return
  return;
}


##  get the information to turn the chart into an imagemap
##  had to override it to reassemble the @data array correctly
sub imagemap_dump {
  my $self = shift;
  my ($i, $j);
  my @map;
  my $dataset_count = 0;
 
  # croak if they didn't ask me to remember the data, or if they're asking
  # for the data before I generate it
  unless ($self->{'imagemap'} && $self->{'imagemap_data'}) {
    croak "You need to set the imagemap option to true, and then call the png method, before you can get the imagemap data";
  }

  #make a copy of the imagemap data
  #this is the data of the first component
  for $i (1..$#{$self->{'sub_0'}->{'imagemap_data'}}) {
    for $j (0..$#{$self->{'sub_0'}->{'imagemap_data'}->[$i]}-1) {
       $map[$i][$j] = \@{$self->{'sub_0'}->{'imagemap_data'}->[$i][$j]} ;
    }
    $dataset_count++;
  }
  #and add the data of the second component
  for $i (1..$#{$self->{'sub_1'}->{'imagemap_data'}}) {
    for $j (0..$#{$self->{'sub_1'}->{'imagemap_data'}->[$i]}-1) {
      $map[$i+$dataset_count][$j] = \@{$self->{'sub_1'}->{'imagemap_data'}->[$i][$j]} ;
    }
  }
  

  # return their copy
  return \@map;

}

sub __print_array {
   my @a = @_;
   my $i;
   
   my $li = $#a;
   
   $li++;
   print STDERR "Anzahl der Elemente = $li\n"; $li--;
   
   for ($i=0; $i<=$li; $i++) {
      print STDERR "\t$i\t$a[$i]\n";
   }
}
   
#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

##  make sure the data isn't really weird
##  and collect some basic info about it
sub _check_data {
  my $self = shift;
  my $length = 0;
  my $font = 'tick_label_font';

  # first things first, make sure we got the composite_info
  unless (($self->{'composite_info'}) && ($#{$self->{'composite_info'}} == 1)) {
    croak "Chart::Composite needs to be told what kind of components to use";
  }

  # make sure we don't end up dividing by zero if they ask for
  # just one y_tick
  if ($self->{'y_ticks'} == 1) {
    $self->{'y_ticks'} = 2;
    carp "The number of y_ticks displayed must be at least 2";
  }

  # remember the number of datasets
  $self->{'num_datasets'} = $#{$self->{'dataref'}};

  # remember the number of points in the largest dataset
  $self->{'num_datapoints'} = 0;
  for (0..$self->{'num_datasets'}) {
    if (scalar(@{$self->{'dataref'}[$_]}) > $self->{'num_datapoints'}) {
      $self->{'num_datapoints'} = scalar(@{$self->{'dataref'}[$_]});
    }
  }

  # find the longest x-tick label
  $self->{'x_tick_label_width'} = 0;
  $self->{'x_tick_label_height'} = 0;
  for (@{$self->{'dataref'}->[0]}) {
        next if !defined($_);
		my ($w,$h) = $self->_gd_string_dimensions($font,$self->{f_x_tick}->($_));
        $self->{'x_tick_label_width'} = $w if $w > $self->{'x_tick_label_width'};
        $self->{'x_tick_label_height'} = $h if $h > $self->{'x_tick_label_height'};
  }
  if ( $length <= 0 ) { $length = 1; }    # make sure $length is positive and greater 0
  $self->{'x_tick_label_width'} = 1 if $self->{'x_tick_label_width'} <= 0;
  $self->{'x_tick_label_height'} = 1 if $self->{'x_tick_label_height'} <= 0;

  # now split the data into sub-objects
  $self->_split_data;

  return;
}


## create sub-objects for each type, store the appropriate
## data sets in each one, and stick the correct values into
## them (ie. 'gd_obj');
sub _split_data {
  my $self = shift;
  my @types = ($self->{'composite_info'}[0][0],$self->{'composite_info'}[1][0]);
  my ($i, $j);

## Already checked for number of components in _check_data, above.
#   # we can only do two at a time
#   if ($self->{'composite_info'}[2]) {
#     croak "Sorry, Chart::Composite can only do two chart types at a time";
#   }

  # load the individual modules
  require "Chart/".$types[0].".pm";
  require "Chart/".$types[1].".pm"; 

  # create the sub-objects
  $self->{'sub_0'} = ("Chart::".$types[0])->new();
  $self->{'sub_1'} = ("Chart::".$types[1])->new();

  # copy the color tables FIXME Moved from sub_update, not sure why this is necessary?
  # $sub0->{'color_table'} = { %{$self->{'color_table'}} };
  # $sub1->{'color_table'} = { %{$self->{'color_table'}} };

  # set the options (set the min_val, max_val, and y_ticks
  # options intelligently so that the sub-objects don't get
  # confused)
  $self->{'sub_0'}->set (%{$self->{'opts'}});
  $self->{'sub_1'}->set (%{$self->{'opts'}});
  if (defined ($self->{'opts'}{'min_val1'})) {
    $self->{'sub_0'}->set ('min_val' => $self->{'opts'}{'min_val1'});
  }
  if (defined ($self->{'opts'}{'max_val1'})) {
    $self->{'sub_0'}->set ('max_val' => $self->{'opts'}{'max_val1'});
  }
  if (defined ($self->{'opts'}{'min_val2'})) {
    $self->{'sub_1'}->set ('min_val' => $self->{'opts'}{'min_val2'});
  }
  if (defined ($self->{'opts'}{'max_val2'})) {
    $self->{'sub_1'}->set ('max_val' => $self->{'opts'}{'max_val2'});
  }
  if ($self->{'opts'}{'y_ticks1'}) {
    $self->{'sub_0'}->set ('y_ticks' => $self->{'opts'}{'y_ticks1'});
  } 
  if ($self->{'opts'}{'y_ticks2'}) {
    $self->{'sub_1'}->set ('y_ticks' => $self->{'opts'}{'y_ticks2'});
  }
  #  f_y_tick for left and right axis
  if (defined ($self->{'opts'}{'f_y_tick1'})) {
    $self->{'sub_0'}->set ('f_y_tick' => $self->{'opts'}{'f_y_tick1'});
  }
  if (defined ($self->{'opts'}{'f_y_tick2'})) {
    $self->{'sub_1'}->set ('f_y_tick' => $self->{'opts'}{'f_y_tick2'});
  }
  foreach my $setting (qw( y_axis_scale ))
  {
	  if( defined $self->{opts}->{"${setting}1"} ) {
		  $self->{'sub_0'}->set( $setting => $self->{opts}->{"${setting}1"} );
	  }
	  if( defined $self->{opts}->{"${setting}2"} ) {
		  $self->{'sub_1'}->set( $setting => $self->{opts}->{"${setting}2"} );
	  }
  }

  # replace the gd_obj fields
  $self->{'sub_0'}->{'gd_obj'} = $self->{'gd_obj'};
  $self->{'sub_1'}->{'gd_obj'} = $self->{'gd_obj'};

  # let the sub-objects know they're sub-objects
  $self->{'sub_0'}->{'component'} = TRUE;
  $self->{'sub_1'}->{'component'} = TRUE;

  # give each sub-object its data
  $self->{'component_datasets'} = [];
  for $i (0..1) {
    my @ref;
    $self->{'component_datasets'}[$i] = $self->{'composite_info'}[$i][1];
    push @ref, $self->{'dataref'}[0];
	my $k = 0;
    for $j (@{$self->{'composite_info'}[$i][1]}) {
	  # dataset colors
      $self->_color_role_to_index('dataset'.($j-1)); # allocate color index
      $self->{'sub_'.$i}{'color_table'}{'dataset'.$k} 
        = $self->{'color_table'}{'dataset'.($j-1)}; # apply to the appropriate series in the sub
	  # neg_dataset colors
	  if( $self->{'colors'}{'neg_dataset'.($j-1)} ) {
		$self->_color_role_to_index('neg_dataset'.($j-1)); # allocate color index
        $self->{'sub_'.$i}{'color_table'}{'neg_dataset'.$k} 
          = $self->{'color_table'}{'neg_dataset'.($j-1)}; # apply to the appropriate series in the sub
	  }
	  # series_label
	  $self->{'sub_'.$i}{'series_label'}[$k]
	  	= $self->{'series_label'}[$j-1];
	  $self->{'sub_'.$i}{'pointStyle'.($k+1)}
	    = $self->{'pointStyle'.$j};
	  # data
	  if( !defined $self->{'dataref'}[$j] )
	  {
		  croak "composite_info refers to non-existent dataset $j (".(@{$self->{'dataref'}}-1)." datasets defined)";
	  }
      push @ref, $self->{'dataref'}[$j];
	  $k++;
    }
    $self->{'sub_'.$i}->_copy_data (\@ref);
  }

  # and let them check it
  $self->{'sub_0'}->_check_data;
  $self->{'sub_1'}->_check_data;

  # realign the y-axes if they want
  if ($self->{'same_y_axes'}) {
    if ($self->{'sub_0'}{'min_val'} < $self->{'sub_1'}{'min_val'}) {
      $self->{'sub_1'}{'min_val'} = $self->{'sub_0'}{'min_val'};
    }
    else {
      $self->{'sub_0'}{'min_val'} = $self->{'sub_1'}{'min_val'};
    }

    if ($self->{'sub_0'}{'max_val'} > $self->{'sub_1'}{'max_val'}) {
      $self->{'sub_1'}{'max_val'} = $self->{'sub_0'}{'max_val'};
    }
    else {
      $self->{'sub_0'}{'max_val'} = $self->{'sub_1'}{'max_val'};
    }

    $self->{'sub_0'}->_check_data;
    $self->{'sub_1'}->_check_data;
  }
	
  # find out how big the y-tick labels will be from sub_0 and sub_1
  #$self->{'y_tick_label_length1'} = $self->{'sub_0'}->{'y_tick_label_length'};
  #$self->{'y_tick_label_length2'} = $self->{'sub_1'}->{'y_tick_label_length'};

  # now return
  return;
}

sub _draw_legend {
  my $self = shift;
  my ($length,$height);
  my $font = 'legend_font';

  # check to see if they have as many labels as datasets,
  # warn them if not
  if (($#{$self->{'legend_labels'}} >= 0) &&
       ((scalar(@{$self->{'legend_labels'}})) != $self->{'num_datasets'})) {
    carp "The number of legend labels and datasets doesn\'t match";
  }
 
  # init a field to store the length of the longest legend label
  unless ($self->{'max_legend_label_width'}) {
	$self->{'max_legend_label_width'} = 0;
    $self->{'max_legend_label_height'} = 0;
  }
 
  # fill in the legend labels, find the longest one
  for (1..$self->{'num_datasets'}) {
    unless ($self->{'legend_labels'}[$_-1]) {
      $self->{'legend_labels'}[$_-1] = "Dataset $_";
    }
    #$length = length($self->{'legend_labels'}[$_-1]);
    ($length,$height) = $self->_gd_string_dimensions($font,$self->{'legend_labels'}[$_-1]);
    if ($length > $self->{'max_legend_label_width'}) {
      $self->{'max_legend_label_width'} = $length;
      $self->{'max_legend_label_height'} = $height;
    }
  }

  # copy the current boundaries and colors into the sub-objects
  $self->_sub_update(); 
  # init the legend example height
  $self->_legend_example_height_init;

  # modify the dataset color table entries to avoid duplicating
  # dataset colors.
#  my ($n0, $n1) = map { scalar @{ $self->{'composite_info'}[$_][1] } } 0..1;
#  for (0..$n1-1) {
#    $self->{'sub_1'}{'color_table'}{'dataset'.$_} 
#      = $self->{'color_table'}{'dataset'.($_+$n0)};
#  }

  my $x1 = $self->{'curr_x_min'} + $self->{'graph_border'}
			+ $self->{'sub_0'}->{'y_tick_label_width'}
	  		+ $self->{'tick_len'} + (3 * $self->{'text_space'});
  my $x2 = $self->{'curr_x_max'} - $self->{'graph_border'}
			- $self->{'sub_1'}->{'y_tick_label_width'}
			- $self->{'tick_len'} - (3 * $self->{'text_space'});
  if ($self->{'y_label'}) {
	$x1 += $self->{'max_legend_label_height'} + 2 * $self->{'text_space'};
  }
  if ($self->{'y_label2'}) {
    $x2 -= $self->{'max_legend_label_height'} + 2 * $self->{'text_space'};
  }

  # different legend types
  if ($self->{'legend'} eq 'bottom') {
    $self->_draw_bottom_legend($x1,$x2);
  }
  elsif ($self->{'legend'} eq 'right') {
    $self->_draw_right_legend;
  }
  elsif ($self->{'legend'} eq 'left') {
    $self->_draw_left_legend;
  }
  elsif ($self->{'legend'} eq 'top') {
    $self->_draw_top_legend($x1,$x2);
  }
  elsif ($self->{'legend'} eq 'none') {
    # $self->_draw_none_legend;
  } else {
    carp "I can't put a legend there\n";
  }
 
  # and return
  return 1;
}

## draw the ticks and tick labels
sub _draw_ticks {
  my $self = shift;

  # draw the x ticks
  $self->_draw_x_ticks;

  # update the boundaries in the sub-objects
  $self->_boundary_update ($self, $self->{'sub_0'});
  $self->_boundary_update ($self, $self->{'sub_1'}); 

  # now the y ticks
  $self->_draw_y_ticks;

  # then return
  return;
}


## draw the x-ticks and their labels
sub _draw_x_ticks {
  my $self = shift;
  my $data = $self->{'dataref'};
  my $font = 'tick_label_font';
  my $textcolor = $self->_color_role_to_index('x_axis');
  $textcolor ||= $self->_color_role_to_index('text');
  my $misccolor = $self->_color_role_to_index('x_axis');
  $misccolor ||= $self->_color_role_to_index('misc');
  my ($h);
  my ($x1, $x2, $y1, $y2);
  my ($width, $delta);
  my ($stag);

  $self->{'grid_data'}->{'x'} = [];

  # get the height and width of the font
  #($h, $w) = ($font->height, $font->width);
  $h = $self->{'sub_0'}->{'y_tick_label_height'};

  # allow for the amount of space the y-ticks will push the
  # axes over to the right and to the left
## _draw_y_ticks allows 3 * text_space, not 2 * ;  this caused mismatch between
## the ticks (and grid lines) and the data.
#   $x1 = $self->{'curr_x_min'} + ($w * $self->{'y_tick_label_length1'})
#          + (2 * $self->{'text_space'}) + $self->{'tick_len'};
#   $x2 = $self->{'curr_x_max'} - ($w * $self->{'y_tick_label_length2'})
#          - (2 * $self->{'text_space'}) - $self->{'tick_len'};
  $x1 = $self->{'curr_x_min'} + $self->{'sub_0'}->{'y_tick_label_width'}
         + (3 * $self->{'text_space'}) + $self->{'tick_len'};
  $x2 = $self->{'curr_x_max'} - $self->{'sub_1'}->{'y_tick_label_width'}
         - (3 * $self->{'text_space'}) - $self->{'tick_len'};
  $y1 = $self->{'curr_y_max'} - $h - $self->{'text_space'};

  # get the delta value, figure out how to draw the labels
  $width = $x2 - $x1;
  $delta = $width / ( $self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1 );
  if ($delta <= $self->{'x_tick_label_width'}) {
    unless ($self->{'x_ticks'} =~ /^vertical$/i) {
      $self->{'x_ticks'} = 'staggered';
    }
  }

  # now draw the labels
  if ($self->{'x_ticks'} =~ /^normal$/i) { # normal ticks
    if ($self->{'skip_x_ticks'}) {
      for (0..int(($self->{'num_datapoints'}-1)/$self->{'skip_x_ticks'})) {
        $x2 = $x1 + ($delta/2) + ($delta*($_*$self->{'skip_x_ticks'})) 
	      - $self->_gd_string_width($font,$self->{'f_x_tick'}->($data->[0][$_* $self->{'skip_x_ticks'}])) / 2;
        $self->_gd_string($textcolor, $font, 0, $x2, $y1, 
	                          $self->{'f_x_tick'}->($data->[0][$_*$self->{'skip_x_ticks'}]));
      }
    }
    elsif ($self->{'custom_x_ticks'}) {
      for (@{$self->{'custom_x_ticks'}}) {
        $x2 = $x1 + ($delta/2) + ($delta*$_) - $self->_gd_string_width($font, $self->{'f_x_tick'}->($data->[0][$_])) / 2;
        $self->_gd_string($textcolor, $font, 0, $x2, $y1,
                                  $self->{'f_x_tick'}->($data->[0][$_]));
      }
    }
    else {
      for (0..$self->{'num_datapoints'}-1) {
        $x2 = $x1 + ($delta/2) + ($delta*$_) - $self->_gd_string_width($font, $self->{'f_x_tick'}->($data->[0][$_])) / 2;
        $self->_gd_string($textcolor, $font, 0, $x2, $y1, $self->{'f_x_tick'}->($data->[0][$_]));
      }
    }
  }
  elsif ($self->{'x_ticks'} =~ /^staggered$/i) { # staggered ticks
    if ($self->{'skip_x_ticks'}) {
      $stag = 0;
      for (0..int(($self->{'num_datapoints'}-1)/$self->{'skip_x_ticks'})) {
        $x2 = $x1 + ($delta/2) + ($delta*($_*$self->{'skip_x_ticks'})) 
	        - $self->_gd_string_width($font, $self->{'f_x_tick'}->($data->[0][$_*$self->{'skip_x_ticks'}])) / 2;
        if (($stag % 2) == 1) {
          $y1 -= $self->{'text_space'} + $h;
        }
        $self->_gd_string($textcolor, $font, 0, $x2, $y1, 
                                  $self->{'f_x_tick'}->($data->[0][$_*$self->{'skip_x_ticks'}]));
        if (($stag % 2) == 1) {
          $y1 += $self->{'text_space'} + $h;
        }
	$stag++;
      }
    }
    elsif ($self->{'custom_x_ticks'}) {
      $stag = 0;
      for (sort (@{$self->{'custom_x_ticks'}})) {
        $x2 = $x1 + ($delta/2) + ($delta*$_) - $self->_gd_string_width($font, $self->{'f_x_tick'}->($data->[0][$_])) / 2;
        if (($stag % 2) == 1) {
          $y1 -= $self->{'text_space'} + $h;
        }
        $self->_gd_string($textcolor, $font, 0, $x2, $y1,  $self->{'f_x_tick'}->($data->[0][$_]));
        if (($stag % 2) == 1) {
          $y1 += $self->{'text_space'} + $h;
        }
	$stag++;
      }
    }
    else {
      for (0..$self->{'num_datapoints'}-1) {
        $x2 = $x1 + ($delta/2) + ($delta*$_) - $self->_gd_string_width($font, $self->{'f_x_tick'}->($data->[0][$_])) / 2;
        if (($_ % 2) == 1) {
          $y1 -= $self->{'text_space'} + $h;
        }
        $self->_gd_string($textcolor, $font, 0, $x2, $y1,  $self->{'f_x_tick'}->($data->[0][$_]));
        if (($_ % 2) == 1) {
          $y1 += $self->{'text_space'} + $h;
        }
      }
    }
  }
  elsif ($self->{'x_ticks'} =~ /^vertical$/i) { # vertical ticks
    $y1 = $self->{'curr_y_max'} - $self->{'text_space'};
    if ( defined($self->{'skip_x_ticks'}) && $self->{'skip_x_ticks'} > 1) {
      for (0..int(($self->{'num_datapoints'}-1)/$self->{'skip_x_ticks'})) {
        $x2 = $x1 + ($delta/2) + ($delta*($_*$self->{'skip_x_ticks'})) - $h/2;
        $y2 = $y1 - ($self->{'x_tick_label_width'} 
	              - $self->_gd_string_width($font, $self->{'f_x_tick'}->($data->[0][$_*$self->{'skip_x_ticks'}])));
        $self->_gd_string($textcolor, $font, Chart::Base::ANGLE_VERTICAL, $x2, $y2, 
                                    $self->{'f_x_tick'}->($data->[0][$_*$self->{'skip_x_ticks'}]));
      }
    }
    elsif ($self->{'custom_x_ticks'}) {
      for (@{$self->{'custom_x_ticks'}}) {
        $x2 = $x1 + ($delta/2) + ($delta*$_) - $h/2;
        $y2 = $y1 - ($self->{'x_tick_label_width'} - $self->_gd_string_width($font, $self->{'f_x_tick'}->($data->[0][$_])));
        $self->_gd_string($textcolor, $font, Chart::Base::ANGLE_VERTICAL, $x2, $y2, 
                                    $self->{'f_x_tick'}->($data->[0][$_]));
      }
    }
    else {
      for (0..$self->{'num_datapoints'}-1) {
        $x2 = $x1 + ($delta/2) + ($delta*$_) - $h/2;
        $y2 = $y1 - ($self->{'x_tick_label_width'} - $self->_gd_string_width($font, $self->{'f_x_tick'}->($data->[0][$_])));
        $self->_gd_string($textcolor, $font, Chart::Base::ANGLE_VERTICAL, $x2, $y2, 
	                             $self->{'f_x_tick'}->($data->[0][$_]));
      }
    }
  }
  else { # error time
    carp "I don't understand the type of x-ticks you specified";
  }

  # update the current y-max value
  if ($self->{'x_ticks'} =~ /^normal$/i) {
     $self->{'curr_y_max'} -= $h + (2 * $self->{'text_space'});
  } 
  elsif ($self->{'x_ticks'} =~ /^staggered$/i) {
    $self->{'curr_y_max'} -= (2 * $h) + (3 * $self->{'text_space'});
  }
  elsif ($self->{'x_ticks'} =~ /^vertical$/i) {
    $self->{'curr_y_max'} -= $self->{'x_tick_label_width'}
                               + (2 * $self->{'text_space'});
  }

  # now plot the ticks
  $y1 = $self->{'curr_y_max'};
  $y2 = $self->{'curr_y_max'} - $self->{'tick_len'};
  if ($self->{'skip_x_ticks'}) {
    for (0..int(($self->{'num_datapoints'}-1)/$self->{'skip_x_ticks'})) {
      $x2 = $x1 + ($delta/2) + ($delta*($_*$self->{'skip_x_ticks'}));
      $self->_gd_line($x2, $y1, $x2, $y2, $misccolor);
      if ($self->{'grid_lines'} || $self->{'x_grid_lines'}) {
        $self->{'grid_data'}->{'x'}->[$_] = $x2;
      }
    }
  }
  elsif ($self->{'custom_x_ticks'}) {
    for (@{$self->{'custom_x_ticks'}}) {
      $x2 = $x1 + ($delta/2) + ($delta*$_);
      $self->_gd_line($x2, $y1, $x2, $y2, $misccolor);
      if ($self->{'grid_lines'} || $self->{'x_grid_lines'}) {
        $self->{'grid_data'}->{'x'}->[$_] = $x2;
      }
    }
  }
  else {
    for (0..$self->{'num_datapoints'}-1) {
      $x2 = $x1 + ($delta/2) + ($delta*$_);
      $self->_gd_line($x2, $y1, $x2, $y2, $misccolor);
      if ($self->{'grid_lines'} || $self->{'x_grid_lines'}) {
        $self->{'grid_data'}->{'x'}->[$_] = $x2;
      }
    }
  }

  # update the current y-max value
  $self->{'curr_y_max'} -= $self->{'tick_len'};

warn "_draw_x_ticks: curr_y_max=$self->{'curr_y_max'}" if DEBUG;

  # and return
  return;
}


## draw the y-ticks and their labels
sub _draw_y_ticks {
  my $self = shift;

  # let the first guy do his
  $self->{'sub_0'}->_draw_y_ticks ('left');

  # and update the other two objects
  $self->_boundary_update ($self->{'sub_0'}, $self);
  $self->_boundary_update ($self->{'sub_0'}, $self->{'sub_1'});

  # now draw the other ones
  $self->{'sub_1'}->_draw_y_ticks ('right');

  # and update the other two objects
  $self->_boundary_update ($self->{'sub_1'}, $self);
  $self->_boundary_update ($self->{'sub_1'}, $self->{'sub_0'});

  # then return
  return;
}


## finally get around to plotting the data
sub _draw_data {
  my $self = shift;

  # do a grey background if they want it
  if ($self->{'grey_background'}) {
    $self->_grey_background;
    $self->{'sub_0'}->{'grey_background'} = FALSE;
    $self->{'sub_1'}->{'grey_background'} = FALSE;
  }

  # draw grid again if necessary (if grey background ruined it..)
  unless ($self->{grey_background}) {
    $self->_draw_grid_lines if $self->{grid_lines};
    $self->_draw_x_grid_lines if $self->{x_grid_lines};
    $self->_draw_y_grid_lines if $self->{y_grid_lines};
    $self->_draw_y2_grid_lines if $self->{y2_grid_lines};
  }


  # do a final bounds update
  $self->_boundary_update ($self, $self->{'sub_0'});
  $self->_boundary_update ($self, $self->{'sub_1'});
  

  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  # now let the component modules go to work
  
  $self->{'sub_0'}->_draw_data;
  $self->{'sub_1'}->_draw_data;
      
  return;
}


## update all the necessary information in the sub-objects
sub _sub_update {
  my $self = shift;
  my $sub0 = $self->{'sub_0'};
  my $sub1 = $self->{'sub_1'};

  # update the boundaries
  $self->_boundary_update ($self, $sub0);
  $self->_boundary_update ($self, $sub1);

  # now return
  return;
}


## copy the current gd_obj boundaries from one object to another
sub _boundary_update {
  my $self = shift;
  my $from = shift;
  my $to = shift;

  $to->{'curr_x_min'} = $from->{'curr_x_min'};
  $to->{'curr_x_max'} = $from->{'curr_x_max'};
  $to->{'curr_y_min'} = $from->{'curr_y_min'};
  $to->{'curr_y_max'} = $from->{'curr_y_max'};

warn "_boundary_update ($from => $to): curr_y_max=$self->{'curr_y_max'}" if DEBUG;

  return;
}

sub _draw_y_grid_lines {
	my ($self) = shift;
	$self->{'sub_0'}->_draw_y_grid_lines();
	return;
}

sub _draw_y2_grid_lines {
	my ($self) = shift;
	$self->{'sub_1'}->_draw_y2_grid_lines();
	return;
}


# init the legend_example_height_values
sub _legend_example_height_init {
  my $self = shift;
  my $a = $self->{'num_datasets'};
  my ($b, $e) =(0,0);
  my $bis='..';
  
      
  if (!$self->{'legend_example_height'}) {
  
    for my $i (0..$a) {
    $self->{'legend_example_height'.$i} = 1;
    }
  }
 
  if ($self->{'legend_example_height'}) { 
 
   for my $i (0..$a) {
   
   if (defined($self->{'legend_example_height'.$i})) { }
   else { ($self->{'legend_example_height'.$i}) = 1;}   
  
   }

   for  $b (0..$a) {
    for  $e (0..$a) {
      my $anh = sprintf($b.$bis.$e);
       if (defined($self->{'legend_example_height'.$anh})) {
        if ($b>$e) {croak "Please reverse the datasetnumber in legend_example_height\n";}
       	  for (my $n=$b;$n<=$e;$n++) {
	    $self->{'legend_example_height'.$n} = $self->{'legend_example_height'.$anh};
	 }
        }
       }
    }
   }
 
  
  
}     

## be a good module and return 1
1;
