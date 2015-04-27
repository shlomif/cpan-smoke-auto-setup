package SmokeAuto;

use strict;
use warnings;

use SmokeConf;
use Cwd;
use File::Spec;
use File::Path;
use File::Copy;

use base 'Exporter';

our @EXPORT = (qw(
    configure_cpanplus
    install_after_perl
    install_all
    install_cpanplus
    install_first_smokers
    install_more_smokers
    install_perl
    smoke
    )
);

my $perl_version = SmokeConf::get_perl_version();
my $inst_path = SmokeConf::get_inst_path();
my $perl_dir = "perl-$perl_version";
# my $perl_arc = "$perl_dir.tar.bz2";
my $perl_arc = "$perl_dir.tar.gz";
my $perl_exe = "$inst_path/bin/perl";
my $yacsmoke = "CPANPLUS::YACSmoke";

sub exec_program
{
    my @args = @_;

    if (system(@args))
    {
        die "Cannot exec " . join(" ", map { qq{"$_"} } @args);
    }

    return;
}

sub run_in_env
{
    my $callback = shift;
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    local $ENV{PATH} = "$inst_path/bin:".$ENV{PATH};
    $callback->();
}

sub install_perl
{
    run_in_env(sub {
    print "Downloading perl\n";

    exec_program ("wget", "-c", SmokeConf::get_primary_cpan_mirror() . "src/$perl_arc");

    print "Unpacking perl\n";

    exec_program ("tar", "-xvf", $perl_arc);

    compile();

    setup_CPAN_pm();
    });
}

sub compile
{
    my $dir = getcwd();

    chdir($perl_dir);

    unlink("config.sh");
    unlink("Policy.sh");

    print "Configuring perl\n";

    exec_program("sh", "Configure", "-Dprefix=$inst_path", "-de");

    print "Compiling perl\n";

    exec_program("make");

    print "Installing perl\n";

    exec_program("make", "install");

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
    run_in_env(
        sub {
            # CPANPLUS does not handle downloads without LWP properly
            # so we need to install LWP::UserAgent at this stage.
            foreach my $module (qw(LWP::UserAgent IPC::Cmd CPANPLUS))
            {
                exec_program($perl_exe, "-MCPAN", "-e", "install('$module')");
            }
        }
    );
}

sub install_module
{
    my $module = shift;
    my @args =
    (
        $perl_exe, "-MCPANPLUS", "-e",
        'exit(!install("' . $module . '"))'
    );
    # print join(",",@args), "\n";
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    exec_program(@args);
}

sub install_first_smokers
{
    run_in_env(sub {
    foreach my $m (qw(
        YAML::Tiny
        Test::Reporter
        ))
    {
        install_module($m);
    }
    });
}

sub install_more_smokers
{
    run_in_env(sub {
    foreach my $m (qw(
        LWP::UserAgent
        YAML
        Mail::Send
        ExtUtils::CBuilder
        Module::Build
        CPANPLUS::Dist::Build
        ),
        $yacsmoke,
    )
    {
        install_module($m);
    }
    });
}

sub get_CPAN_pm_template
{
    return <<'EOF'
# This is CPAN.pm's exec_programwide configuration file. This file provides
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

sub _get_mirror
{
    my ($id, $url) = @_;
    if (my ($scheme, $host, $path) = $url =~ m{\A(http|ftp)://([^/]+)(/.*)\z}ms)
    {
        return
        {
            "${id}_scheme" => $scheme,
            "${id}_host" => $host,
            "${id}_path" => $path,
        };
    }
    else
    {
        die "Incorrect URL id = $id ; url = $url";
    }
}

sub configure_cpanplus
{
    run_in_env(sub {
        my %mirrors = (
            %{_get_mirror('m0', SmokeConf::get_primary_cpan_mirror())},
            %{_get_mirror('m1', SmokeConf::get_secondary_cpan_mirror())},
        );
        exec_program($perl_exe, "-MCPANPLUS::Configure", "-e",
            q/my %p = @ARGV;
              my $conf = CPANPLUS::Configure->new();
              $conf->set_conf(email => $p{'email'});
              $conf->set_conf(cpantest => 1);
              $conf->set_conf(verbose => 1);
              $conf->set_conf("hosts",
                [map
                    {
                        +{
                            path => $p{$_ . "_path"},
                            scheme => $p{$_ . "_scheme"},
                            host => $p{$_ . "_host"},
                         }
                    }
                  (map { "m".$_ } 0 .. 1)
                  ]
                  );
              $conf->save();
              /,
              ('email' => SmokeConf::get_email(), %mirrors),
          );
    });
}

sub install_after_perl
{
    run_in_env(sub {
        install_cpanplus();
        install_first_smokers();
        configure_cpanplus();
        install_more_smokers();
    });
}

sub install_all
{
    run_in_env(sub {
    install_perl();
    install_after_perl();
    }
    );
}

sub smoke
{
    run_in_env(sub {
        exec_program(
            $perl_exe, "-M".$yacsmoke, "-e", $yacsmoke."::test()"
        );
    });
}

1;

=head1 COPYRIGHT & LICENSE

Copyright 2015 by Shlomi Fish

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut
