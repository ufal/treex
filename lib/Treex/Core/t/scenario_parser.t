#!/usr/bin/env perl
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
done_testing();

END {
    map {unlink} @filenames;
}
