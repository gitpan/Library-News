use ExtUtils::MakeMaker;

WriteMakefile(
	      'NAME'	     => 'Library::News',
	      'VERSION_FROM' => 'News.pm',
	      'PREREQ_PM'    => {
				 'Library::MLang' => '0.03',
				 'XML::DT' => '0.19'
				},
	     );
