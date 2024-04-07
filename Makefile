install:
	cpan install Dist::Zilla
	dzil authordeps --missing | cpanm
test:
	dzil test
	dzil xtest

