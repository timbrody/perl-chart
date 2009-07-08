use Chart::LinesPoints;

print "1..1\n";

srand(0);

$g = Chart::LinesPoints->new;
$g->add_dataset ('foo', 'bar', 'junk', 'ding', 'bat');
for(1..8)
{
	my @data;
	for(1..5)
	{
		push @data, rand(9)+1;
	}
	$g->add_dataset( @data );
}

$g->set ('title' => 'Lines and Points Chart');
$g->set ('sub_title' => 'All point styles');
$g->set ('legend' => 'bottom');

$g->png ("samples/linespoints.png");

print "ok 1\n";

exit (0);

