use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME                => 'MultipleSignalHandlers',
	AUTHOR              => q{belden.lyman@gmail.com},
	VERSION_FROM        => 'lib/MultipleSignalHandlers.pm',
	ABSTRACT            => 'Allow multiple handlers to subscribe to the same signal in %SIG',
	LICENSE             => 'perl',
	dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean               => { FILES => 'multiple-signal-handlers-*' },
);
