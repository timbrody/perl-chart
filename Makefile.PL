use ExtUtils::MakeMaker;

#  make the samples directory
mkdir ('samples', 00755);

#  write the makefile
WriteMakefile ( 'NAME' => 'Chart',
		'PREREQ_PM' => {
			'Cairo' => 1,
			'Pango' => 1.0,
		},
		'dist' => { 'COMPRESS' => 'gzip', 'SUFFIX' => 'gz' },
		'VERSION_FROM' => 'Chart/Base.pm' )
