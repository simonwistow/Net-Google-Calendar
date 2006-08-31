use strict;
use Module::Build;

my $build = Module::Build
  ->new( module_name  => "Net::Google::Calendar",
         license      => 'perl',
         script_files => [ ],
         requires     => {
                          'LWP::UserAgent'    => 0,
                          'XML::Atom'         => 0,
                          'Test::More'        => 0,
                          'DateTime'          => 0,
                          'URI'               => 0,
                        },
         recommended  => {
                          'Data::ICal'        => '0.07',
                        },
         create_makefile_pl => 'traditional',
       );

$build->create_build_script;

