use Chart::Lines;
print "1..1\n";

$g = Chart::Lines->new();
my @data;
for(1..1000) {
	push @{$data[0]}, $_;
	push @{$data[1]}, 10 ** ($_/100);
}

$g->set(
		f_x_tick => sub { "10<sup>$_[0]</sup>" },
		'xy_plot' => 'true',
		'y_axes' => 'left',
		'x_ticks' => 'staggered',
		'y_axis_scale' => 'logarithmic',
		'title' => 'Logarithmic Scale Demo',
		'grid_lines' => 'true',
		'grid_lines' =>'true',
		'legend' => 'none',
		'colors' => {
			'text' => 'blue',
			'misc' => 'blue',
			'background' => 'grey',
			'grid_lines' => 'light_blue',
			'dataset0' => [40,200,0],
			'dataset1' => [200,0,100],
		},
);

$g->png ("samples/y_axis_scale_2.png", \@data);

print "ok 1\n";

exit (0);

