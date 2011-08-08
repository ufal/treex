#!/usr/bin/env perl
use strict;
use warnings;
use constant {
    OK     => 'ALL BLOCKS SUCCESSFULLY LOADED',
    CANNOT => 'Cannot parse',
};
my %contents = (

    #reported by Ondrej Dusek
    "Util::SetGlobal language=en\nRead::Text\n#cs_synthesis_a2w.scen"    => OK,
    "Util::SetGlobal language=en\nRead::Text\n# cs_synthesis_a2w.scen"   => OK,
    "Util::SetGlobal language=en\nRead::Text\n#cs_synthesis_a2w.scen\n"  => OK,
    "Util::SetGlobal language=en\nRead::Text\n# cs_synthesis_a2w.scen\n" => OK,

    #reported by Zdenek Zabokrtsky
    '\\'      => CANNOT,
    'aaa aaa' => CANNOT,
    'XXX XXX' => q{Can't use block Treex::Block::XXX},  #Scenario will be Treex::Block::XXX Treex::Block::XXX
);
my %create = (
    'cs_synthesis_pdt.scen' => <<'EOF',
Util::SetGlobal language=cs selector=T
cs_synthesis_goldt.scen
#cs_synthesis_t2a.scen
#cs_synthesis_a2w.scen
EOF
    'cs_synthesis_goldt' => <<'EOF',
EOF
);
my %files = (
    'cs_synthesis_pdt.scen' => OK,
);
use File::Slurp;
use Test::More;
use Test::Output;
my @filenames;
BEGIN { use_ok('Treex::Core::Scenario'); }
foreach my $content ( keys %contents ) {
    my $expected = $contents{$content};
    my $name = 'test' . int( rand(10000) ) . '.scen';
    SKIP: {
        push @filenames, $name;
        note("Writing '$content' to $name");
        write_file( $name, $content ) or skip "cannot write testing scenario to $name", 1;

        combined_like( sub { eval{Treex::Core::Scenario->new( from_file => $name )} }, qr/$expected/, "Output of parsing '$content' contains '$expected' " );

    }
}
foreach my $name (keys %create) {
    write_file( $name, $create{$name} );
    push @filenames, $name;
}
foreach my $file (keys %files) {
    my $expected = $files{$file};
    combined_like( sub { eval{Treex::Core::Scenario->new( from_file => $file )} }, qr/$expected/, "Output of parsing '$file' contains '$expected' " );
}
done_testing();

END {
    map {unlink} @filenames;
}
