package SmokeConf;

use strict;
use warnings;

my $perl_version = "5.10.0";

sub get_perl_version
{
    return $perl_version;
}

sub get_inst_path
{
    return $ENV{'HOME'}."/apps/perl-$perl_version";
}

sub get_primary_cpan_mirror
{
    return "http://mirror.mirimar.net/cpan/";
}

sub get_secondary_cpan_mirror
{
    return "http://ftp.nluug.nl/pub/languages/perl/CPAN/";
    # return "http://www.mirror.ac.uk/mirror/ftp.funet.fi/pub/languages/perl/CPAN/";
    # return "http://cpan.initworld.com/";
}

sub get_cpan_home
{
    return $ENV{'HOME'} . "/.cpan";
}

sub get_email
{
    return 'shlomif@cpan.org';
}

1;

