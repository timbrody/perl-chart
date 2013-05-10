use Chart::Bars;
print "1..1\n";

$g = Chart::Bars->new();
$g->add_dataset ('foo', 'bar', 'junk', 'ding', 'bat');
$g->add_dataset (2,10,5,200,42);
$g->add_dataset (1,1250,230,50,10);

$g->set(
		'legend_labels' => ['1st Quarter', '2nd Quarter'],
		'y_axes' => 'both',
		'y_axis_scale' => 'logarithmic',
		'title' => 'Logarithmic Scale Demo',
		'grid_lines' => 'true',
		'grid_lines' =>'true',
		'legend' => 'bottom',
		'legend_example_size' => 20,
		'series_label0' => 'horizontal',
		'series_label1' => 'vertical',
		'colors' => {
			'text' => 'blue',
			'misc' => 'blue',
			'background' => 'grey',
			'grid_lines' => 'light_blue',
			'dataset0' => [40,200,0],
			'dataset1' => [200,0,100],
		},
);

$g->png ("samples/y_axis_scale.png");

print "ok 1\n";

exit (0);

