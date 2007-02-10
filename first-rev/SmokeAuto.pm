package SmokeAuto;

use strict;
use warnings;

use SmokeConf;
use Cwd;
use File::Spec;
use File::Path;
use File::Copy;

my $perl_version = SmokeConf::get_perl_version();
my $inst_path = SmokeConf::get_inst_path();
my $perl_dir = "perl-$perl_version";
my $perl_arc = "$perl_dir.tar.bz2";
my $perl_exe = "$inst_path/bin/perl";


sub install_perl
{
    print "Downloading perl\n";

    system ("wget", "-c", SmokeConf::get_primary_cpan_mirror() . "src/$perl_arc");

    print "Unpacking perl\n";

    system ("tar", "-xjvf", $perl_arc);

    compile();

    setup_CPAN_pm();
}

sub compile
{
    my $dir = getcwd();

    chdir($perl_dir);

    unlink("config.sh");
    unlink("Policy.sh");

    print "Configuring perl\n";

    system("sh", "Configure", "-Dprefix=$inst_path", "-de");

    print "Compiling perl\n";

    system("make");

    print "Installing perl\n";

    system("make", "install");

    chdir($dir);
}

sub setup_CPAN_pm
{
    open my $out, ">", "$inst_path/lib/5.8.8/CPAN/Config.pm";
    print {$out} get_CPAN_pm_contents();
    close($out);
}

sub install_cpanplus
{
    system($perl_exe, "-MCPAN", "-e", "install CPANPLUS");
}

sub install_module
{
    my $module = shift;
    my @args = ($perl_exe, "-MCPANPLUS", "-e", 'install("' . $module . '")');
    # print join(",",@args), "\n";
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    if (! (system(@args) == 0))
    {
        die "Failed at installing module '$module'!";
    }
}

sub install_smokers
{
    foreach my $m (qw(
        LWP::UserAgent
        YAML
        Mail::Send
        Module::Build
        CPANPLUS::Dist::Build
        Test::Reporter
        CPAN::YACSmoke
        ))
    {
        install_module($m);
    }
}

sub get_CPAN_pm_template
{
    return <<'EOF'
# This is CPAN.pm's systemwide configuration file. This file provides
# defaults for users, and the values can be changed in a per-user
# configuration file. The user-config file is being looked for as
# ~/.cpan/CPAN/MyConfig.pm.

$CPAN::Config = {
  'build_cache' => q[10],
  'build_dir' => q[${CPAN_HOME}/build],
  'cache_metadata' => q[1],
  'cpan_home' => q[${CPAN_HOME}],
  'dontload_hash' => {  },
  'ftp' => q[/usr/bin/ftp],
  'ftp_proxy' => q[],
  'getcwd' => q[cwd],
  'gpg' => q[/usr/bin/gpg],
  'gzip' => q[/bin/gzip],
  'histfile' => q[${CPAN_HOME}/histfile],
  'histsize' => q[100],
  'http_proxy' => q[],
  'inactivity_timeout' => q[0],
  'index_expire' => q[1],
  'inhibit_startup_message' => q[0],
  'keep_source_where' => q[${CPAN_HOME}/sources],
  'lynx' => q[/usr/bin/lynx],
  'make' => q[/usr/bin/make],
  'make_arg' => q[],
  'make_install_arg' => q[],
  'makepl_arg' => q[],
  'ncftpget' => q[/usr/bin/ncftpget],
  'no_proxy' => q[],
  'pager' => q[/usr/bin/less],
  'prerequisites_policy' => q[follow],
  'scan_cache' => q[atstart],
  'shell' => q[/bin/bash],
  'tar' => q[/bin/tar],
  'term_is_latin' => q[0],
  'unzip' => q[/usr/bin/unzip],
  'urllist' => [q[${PRI_MIRROR}], q[${SEC_MIRROR}]],
  'wget' => q[/usr/bin/wget],
};
1;
${END}
EOF
}

sub get_CPAN_pm_contents
{
    my $text = get_CPAN_pm_template();

    my $end_token = "__" . "END" . "__";
    my $cpan_home = SmokeConf::get_cpan_home();
    my $primary_cpan_mirror = SmokeConf::get_primary_cpan_mirror();
    my $secondary_cpan_mirror = SmokeConf::get_secondary_cpan_mirror();

    $text =~ s/\${END}/$end_token/g;
    $text =~ s/\${CPAN_HOME}/$cpan_home/g;
    $text =~ s/\${PRI_MIRROR}/$primary_cpan_mirror/g;
    $text =~ s/\${SEC_MIRROR}/$secondary_cpan_mirror/g;

    return $text;
}

sub install_all
{
    install_perl();
    install_cpanplus();
    install_smokers();
}

sub smoke
{
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    system($perl_exe, "-MCPAN::YACSmoke", "-e", "test");
}

1;
