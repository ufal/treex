package Treex::Block::T2T::CS2RU::RuleBasedFormemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use utf8;

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;


}

# kam назад ради вроде возле

my %cs2ru = (
    # qw(adj:attr) => qw(), # 33981
    # qw(n:1) => qw(), # 28680
    # qw(v:fin) => qw(), # 20142
    # qw(n:2) => qw(), # 17522
    # qw(adv) => qw(), # 13019
    # qw(x) => qw(), # 12606
    # qw(n:4) => qw(), # 11973
    # qw(n:X) => qw(), # 11354
    # qw(drop) => qw(), # 10340
    qw(n:v+6) => qw(n:в+6), # 4485
    # qw(n:7) => qw(), # 2950
    # qw(n:3) => qw(), # 2687
    # qw(v:inf) => qw(), # 2668
    # qw(v:rc) => qw(), # 2353
    qw(n:na+4) => qw(n:на+4), # 2299
    # qw(adj:poss) => qw(), # 2224
    # qw(???) => qw(), # 2134
    # qw(adj:1) => qw(), # 1958
    qw(n:z+2) => qw(n:из+2), # 1781
    qw(n:pro+4) => qw(n:про+2), # 1714
    qw(n:s+7) => qw(n:с+7), # 1569
    # qw(v:že+fin) => qw(), # 1511
    qw(n:k+3) => qw(n:к+3), # 1390
    qw(n:o+6) => qw(n:о+6), # 1382 # nebo об ?
    qw(n:na+6) => qw(n:на+6), # 1179
    qw(n:do+2) => qw(n:до+2), # 1067
    # qw(v:aby+fin) => qw(), # 718
    qw(n:za+4) => qw(n:за+4), # 624
    qw(n:o+4) => qw(n:о+4), # 597
    qw(n:po+6) => qw(n:по+6), # 483 # nebo после ?
    qw(n:podle+2) => qw(n:для+2), # 469
    # qw(n:6) => qw(), # 458
    # qw(v:pokud+fin) => qw(), # 454
    qw(n:od+2) => qw(n:от+2), # 417
    qw(n:mezi+7) => qw(n:между+7), # 409
    # qw(n:5) => qw(), # 403
    qw(n:u+2) => qw(n:у+2), # 383
    qw(n:při+6) => qw(n:при+6), # 380
    # qw(v:když+fin) => qw(), # 354
    qw(n:před+7) => qw(n:перед+7), # 274
    qw(n:v+4) => qw(n:в+4), # 196
    # qw(n:v_souladu_s+7) => qw(), # 185
    qw(n:proti+3) => qw(n:против+3), # 172
    qw(n:bez+2) => qw(n:без+2), # 166
    # qw(v:li+fin) => qw(), # 161
    # qw(n:s_ohledem_na+4) => qw(), # 157
    # qw(n:na_základě+2) => qw(), # 156
    # qw(n:v_rámci+2) => qw(), # 149
    # qw(v:protože+fin) => qw(), # 131
    qw(n:nad+7) => qw(n:над+7), # 112
    # qw(n:včetně+2) => qw(), # 111
    # qw(v:zda+fin) => qw(), # 108
    # qw(v:jestliže+fin) => qw(), # 106
    # qw(n:za+7) => qw(), # 103
    # qw(n:za+2) => qw(), # 98
    # qw(v:kdyby+fin) => qw(), # 97
    # qw(n:vzhledem_k+3) => qw(), # 97
    # qw(n:v_případě+2) => qw(), # 90
    # qw(v:jestli+fin) => qw(), # 89
    # qw(n:během+2) => qw(), # 88
    qw(n:pod+7) => qw(n:под+7), # 87
    # qw(v:než+fin) => qw(), # 84
    # qw(n:než+1) => qw(), # 84
    # qw(n:prostřednictvím+2) => qw(), # 77
    qw(n:kromě+2) => qw(n:кроме+2), # 76
    # qw(v:takže+fin) => qw(), # 74
    # qw(n:než+X) => qw(), # 70
    # qw(n:po+4) => qw(), # 67
    qw(n:přes+4) => qw(n:через+4), # 65
    # qw(n:jako+1) => qw(), # 62
    qw(n:mimo+4) => qw(n:мимо+4), # 60
    # qw(v:aniž+fin) => qw(), # 53
    # qw(n:v_oblasti+2) => qw(), # 50
    # qw(n:vůči+3) => qw(), # 47
    # qw(n:spolu_s+7) => qw(), # 47
    # qw(n:kvůli+3) => qw(), # 45
    qw(n:kolem+2) => qw(n:вокруг+2), # 45
    # qw(n:v_souvislosti_s+7) => qw(), # 43
    # qw(n:ohledně+2) => qw(), # 43
    # qw(v:až+fin) => qw(), # 42
    # qw(v:co+fin) => qw(), # 41
    # qw(n:v_důsledku+2) => qw(), # 40
    # qw(n:pomocí+2) => qw(), # 39
    # qw(adj:7) => qw(), # 39
    # qw(n:za_účelem+2) => qw(), # 33
    # qw(v:jelikož+fin) => qw(), # 32
    # qw(n:než+4) => qw(), # 30
    # qw(adj:4) => qw(), # 30
    qw(n:pod+4) => qw(n:под+4), # 29
    qw(n:díky+3) => qw(n:благодаря+3), # 29  # nebo ...+2
    qw(n:mezi+4) => qw(n:между+4), # 27
    qw(n:místo+2) => qw(n:вместо+2), # 26
    # qw(v:jako+fin) => qw(), # 25
    # qw(v:zatímco+fin) => qw(), # 24
    # qw(n:bez_ohledu_na+4) => qw(), # 24
    # qw(n:vedle+2) => qw(), # 23
    # qw(n:na+X) => qw(), # 23
    # qw(v:ačkoli+fin) => qw(), # 22
    # qw(n:ve_formě+2) => qw(), # 22
    # qw(v:jakmile+fin) => qw(), # 21
    # qw(n:v_průběhu+2) => qw(), # 20
    # qw(n:ohledem_na+4) => qw(), # 20
    # qw(n:s_výjimkou+2) => qw(), # 19
    # qw(n:v_zájmu+2) => qw(), # 17
    # qw(n:společně_s+7) => qw(), # 17
    # qw(v:že+rc) => qw(), # 15
    # qw(n:nad+4) => qw(), # 15
    # qw(n:di+X) => qw(), # 15
    # qw(n:že+4) => qw(), # 14
    # qw(n:z+X) => qw(), # 14
    # qw(n:v_rozporu_s+7) => qw(), # 14
    # qw(n:ve_srovnání_s+7) => qw(), # 14
    # qw(n:v+X) => qw(), # 13
    # qw(n:že+1) => qw(), # 12
    # qw(n:ve_spojení_s+7) => qw(), # 12
    # qw(n:souladu_s+7) => qw(), # 12
    # qw(n:směrem_k+3) => qw(), # 12
    # qw(v:přestože+fin) => qw(), # 11
    # qw(v:dokud+fin) => qw(), # 11
    # qw(n:z_hlediska+2) => qw(), # 11
    # qw(n:závislosti_na+6) => qw(), # 11
    # qw(n:o+X) => qw(), # 11
    # qw(n:oproti+3) => qw(), # 11
    # qw(n:než_v+6) => qw(), # 11
    qw(n:uprostřed+2) => qw(n:среди+2), # 10
    qw(n:namísto+2) => qw(n:вместо+2), # 10
    qw(n:dle+2) => qw(n:для+2), # 10
    # qw(v:že+inf) => qw(), # 9
    # qw(v:jak+fin) => qw(), # 9
    # qw(n:z_důvodu+2) => qw(), # 9
    # qw(n:ve_vztahu_k+3) => qw(), # 9
    # qw(n:ve_smyslu+2) => qw(), # 9
    # qw(n:na_rozdíl_od+2) => qw(), # 9
    # qw(v:než_aby+fin) => qw(), # 8
    # qw(v:ledaže+fin) => qw(), # 8
    # qw(n:že+X) => qw(), # 8
    # qw(n:za+X) => qw(), # 8
    # qw(n:v_s+6) => qw(), # 8
    qw(n:uvnitř+2) => qw(n:внутри+2), # 8
    qw(n:podél+2) => qw(n:вдоль+2), # 8
    # qw(n:navzdory+3) => qw(), # 8
    # qw(n:k+X) => qw(), # 8
    # qw(v:ať+fin) => qw(), # 7
    # qw(n:ve_prospěch+2) => qw(), # 7
    # qw(n:s+X) => qw(), # 7
    # qw(n:pro+X) => qw(), # 7
    # qw(n:jako+X) => qw(), # 7
    # qw(v:než+inf) => qw(), # 6
    # qw(n:zatímco+2) => qw(), # 6
    # qw(n:v_závislosti_na+6) => qw(), # 6
    # qw(n:vyjma+2) => qw(), # 6
    # qw(n:v_podobě+2) => qw(), # 6
    # qw(n:ve_spolupráci_s+7) => qw(), # 6
    # qw(n:u+X) => qw(), # 6
    # qw(n:s+4) => qw(), # 6
    # qw(n:spojení+2) => qw(), # 6
    qw(n:před+4) => qw(n:перед+4), # 6
    # qw(n:podle+X) => qw(), # 6
    # qw(n:než+2) => qw(), # 6
    # qw(n:mezi+X) => qw(), # 6
    # qw(n:jako+2) => qw(), # 6
    # qw(n:di+1) => qw(), # 6
    # qw(n:ze_strany+2) => qw(), # 5
    # qw(n:takže+1) => qw(), # 5
    qw(n:skrz+4) => qw(n:сквозь+4), # 5
    # qw(n:pokud+1) => qw(), # 5
    qw(n:okolo+2) => qw(n:около+2), # 5
    # qw(n:než_u+2) => qw(), # 5
    # qw(n:následkem+2) => qw(), # 5
    # qw(n:naproti+3) => qw(), # 5
    # qw(n:jak+X) => qw(), # 5
    # qw(n:aby+1) => qw(), # 5
    # qw(n:) => qw(), # 5
    # qw(adj:na+poss) => qw(), # 5
    # qw(v:než+rc) => qw(), # 4
    # qw(v:jako_kdyby+fin) => qw(), # 4
    # qw(n:s_ohledem_na+X) => qw(), # 4
    # qw(n:pokud+X) => qw(), # 4
    # qw(n:od+X) => qw(), # 4
    # qw(n:li+1) => qw(), # 4
    # qw(n:když+X) => qw(), # 4
    # qw(n:jako_v+6) => qw(), # 4
    # qw(n:do+X) => qw(), # 4
    # qw(n:aby+4) => qw(), # 4
    # qw(n:že+7) => qw(), # 3
    # qw(n:že+2) => qw(), # 3
    # qw(n:zpod+2) => qw(), # 3
    # qw(n:vstříc+3) => qw(), # 3
    # qw(n:v_rámci+X) => qw(), # 3
    # qw(n:souvislosti_s+7) => qw(), # 3
    # qw(n:rozporu_s+7) => qw(), # 3
    # qw(n:pokud+) => qw(), # 3
    # qw(n:než_s+7) => qw(), # 3
    # qw(n:na_v+4) => qw(), # 3
    # qw(n:mimo+1) => qw(), # 3
    # qw(n:když+1) => qw(), # 3
    # qw(n:jménem+2) => qw(), # 3
    # qw(n:de+1) => qw(), # 3
    # qw(n:aby_na+6) => qw(), # 3
    # qw(v:takže_jestli+fin) => qw(), # 2

);


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2RU::RuleBasedFormemes
 -- manually constructed formeme translation

=head1 DESCRIPTION

One formeme translation equivalent is provided for most frequent
Czech formemes extracted from CzEng.


=back

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
