#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Treex::Tool::Align::MonolingualGreedy;

my $hyp = 'Najednou|najednou|!........... ztuhl|ztuhnout|VpIS...3..AA .|.|Z-----------
Z|z|R----------- koutku|koutek|N.IS2.....A. svého|svůj|P8NS2....... oka|oko|N.NS2.....A. myslel|myslet|VpIS...3..AA ,|,|Z----------- že|že|J----------- zachytil|zachytit|VpIS...3..AA nepatrný|patrný|A.IS4....1N. pohyb|pohyb|N.IS4.....A. .|.|Z-----------
Ale|ale|!........... ten|ten|P.IS1....... musela|muset|VpFS...3..AA být|být|Vf........A. iluze|iluze|N.FS1.....A. .|.|Z-----------';

my $ref = 'Najednou|najednou|Db------------- ztuhl|ztuhnout_:W|VpYS---XR-AA--1 .|.|Z:-------------
Měl|mít|VpYS---XR-AA--- dojem|dojem|NNIS4-----A---- ,|,|Z:------------- že|že-1|J,------------- koutkem|koutek|NNIS7-----A---- oka|oko|NNNS2-----A---- zpozoroval|zpozorovat_:W|VpYS---XR-AA--- nějaký|nějaký|PZIS4---------- sotva|sotva|Db------------- postřehnutelný|postřehnutelný_^(*6out)|AAIS4----1A---- pohyb|pohyb|NNIS4-----A---- .|.|Z:-------------
Určitě|určitě_^(*1ý)|Dg-------1A---- to|ten|PDNS1---------- však|však|J^------------- byla|být|VpQW---XR-AA--- halucinace|halucinace|NNFS1-----A---- .|.|Z:-------------';

my $expected_alignment = '0-0 1-1 2-2
1-4 3-5 4-6 5-2 6-3 8-9 9-10 10-11
0-0 1-1 2-2 3-3 4-4 5-5';

my $greedy = Treex::Tool::Align::MonolingualGreedy->new();
ok($greedy, 'Treex::Tool::Align::MonolingualGreedy created');

my @hyps   = split /\n/, $hyp;
my @refs   = split /\n/, $ref;
my @alis   = split /\n/, $expected_alignment;

for my $i ( 0 .. $#hyps ) {
    my $r_line   = $refs[$i];
    my $h_line   = $hyps[$i];
    my @r_tokens = map { [ split /\|/, $_ ] } split /\s/, $r_line;
    my @h_tokens = map { [ split /\|/, $_ ] } split /\s/, $h_line;
    my $args     = {
        hforms  => [ map { $_->[0] } @h_tokens ],
        rforms  => [ map { $_->[0] } @r_tokens ],
        hlemmas => [ map { $_->[1] } @h_tokens ],
        rlemmas => [ map { $_->[1] } @r_tokens ],
        htags   => [ map { $_->[2] } @h_tokens ],
        rtags   => [ map { $_->[2] } @r_tokens ],
    };

    # The main work is done here
    my $alignment = $greedy->align_sentence($args);

    my $ali = join ' ', map { $alignment->[$_] == -1 ? () : $_ . '-' . $alignment->[$_] } ( 0 .. $#h_tokens );
    my $expected_alignment = $alis[$i];

    is( $ali, $expected_alignment, 'Alignment of sentence ' . ( $i + 1 ) );

    # To debug, you can print aligned forms and/or alignment indices
    #say join ' ', map {$alignment->[$_] == -1 ? () : $h_tokens[$_][0] . '-' . $r_tokens[$alignment->[$_]][0]} (0..$#h_tokens);
    #say $ali;
}

done_testing();
