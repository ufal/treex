package Treex::Block::T2T::CS2RU::RuleBasedFormemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use utf8;

# nezarazeno назад вроде

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
    qw(n:pro+4) => qw(n:для+2), # 1714
    qw(n:s+7) => qw(n:с+7), # 1569
    qw(v:že+fin) => qw(v:что+fin), # 1511
    qw(n:k+3) => qw(n:к+3), # 1390
    qw(n:o+6) => qw(n:о+6), # 1382 # nebo об ?
    qw(n:na+6) => qw(n:на+6), # 1179
    qw(n:do+2) => qw(n:до+2), # 1067
    #qw(n:do+2) => qw(n:в+4), ????TODO try it
    qw(v:aby+fin) => qw(v:чтобы+fin), # 718
    qw(n:za+4) => qw(n:за+4), # 624
    qw(n:o+4) => qw(n:о+4), # 597
    qw(n:po+6) => qw(n:по+6), # 483 # nebo после ?
    qw(n:podle+2) => qw(n:по+3), # TODO 469 или в соответствии с+7(podle planu)
    # qw(n:6) => qw(), # 458
    qw(v:pokud+fin) => qw(v:если+fin), # 454
    qw(n:od+2) => qw(n:от+2), # 417
    qw(n:mezi+7) => qw(n:между+7), # 409
    # qw(n:5) => qw(), # 403
    qw(n:u+2) => qw(n:у+2), # 383
    qw(n:při+6) => qw(n:при+6), # 380
    qw(v:když+fin) => qw(v:когда+fin), # 354
    qw(v:až+fin) => qw(v:когда+fin),
    qw(n:před+7) => qw(n:перед+7), # 274
    qw(n:v+4) => qw(n:в+4), # 196
    qw(n:v_souladu_s+7) => qw(в_соответствии_с+7), # 185
    qw(n:proti+3) => qw(n:против+2), # 172
    qw(n:bez+2) => qw(n:без+2), # 166
    qw(v:li+fin) => qw(v:если+fin), # 161 reordering needed: Prijde-li Если он прийдет
    qw(n:s_ohledem_na+4) => qw(n:с_учётом+2), # 157
    # qw(n:na_základě+2) => qw(), # 156
    qw(n:na_základě+2) => qw(n:на_основании+2),
    qw(n:v_rámci+2) => qw(в_рамках+2), # 149
    qw(v:protože+fin) => qw(v:потому_что+fin), # 131
    qw(n:nad+7) => qw(n:над+7), # 112
    qw(n:včetně+2) => qw(включая+4), 
    qw(v:zda+fin) => qw(v:если+fin), # 108 reordering needed Nevim zda prijde - не знаю прийдет ли он
    qw(v:jestliže+fin) => qw(v:если+fin), # 106
    qw(n:za+7) => qw(n:за+7), # 103
    qw(n:za+2) => qw(n:за+2), # 98
    qw(v:kdyby+fin) => qw(v:если_бы+fin), # 97
    qw(n:vzhledem_k+3) => qw(n:учитывая+1), # 97
    qw(n:v_případě+2) => qw(n:в_случае+2), # 90
    qw(v:jestli+fin) => qw(v:если+fin), # 89
    qw(n:během+2) => qw(n:в_течение+2), # 88
    qw(n:pod+7) => qw(n:под+7), # 87
    qw(v:než+fin) => qw(v:чем+fin), # 84
    qw(n:než+1) => qw(n:чем+1), # 84
    qw(n:prostřednictvím+2) => qw(n:посредством+2), # 77
    qw(n:kromě+2) => qw(n:кроме+2), # 76
    qw(v:takže+fin) => qw(v:так+fin), # 74
    qw(n:než+X) => qw(n:чем+X), # 70
    qw(n:po+4) => qw(n:по+4), # 67
    qw(n:přes+4) => qw(n:через+4), # 65
    qw(n:jako+1) => qw(n:как+1), # 62
    qw(n:mimo+4) => qw(n:мимо+4), # 60
    # qw(v:aniž+fin) => qw(), # 53 tady by melo byt (i_dazhe_ne) negation=0
    qw(n:v_oblasti+2) => qw(в_области+2), # 50
    qw(n:vůči+3) => qw(по_отношению_к+3),
    qw(n:spolu_s+7) => qw(n:вместе_с+7), # 47
    qw(n:kvůli+3) => qw(n:из-за+3), # 45
    qw(n:kolem+2) => qw(n:вокруг+2), # 45
    # qw(n:v_souvislosti_s+7) => qw(), # 43
    qw(n:v_souvislosti_s+7) => qw(n:в_связи_с+7),
    qw(n:ohledně+2) => qw(n:относительно+2), # 43
    qw(v:až+fin) => qw(v:пока+fin), # 42
    qw(v:co+fin) => qw(v:что+fin), # 41
    qw(n:v_důsledku+2) => qw(n:в_следствие+2), # 40
    #qw(n:pomocí+2) => qw(), # 39
     qw(n:pomocí+2) => qw(n:с_помощью+2), 
    qw(adj:7) => qw(adj:7), # 39
     qw(n:za_účelem+2) => qw(n:с_целью+2), # 33
    qw(v:jelikož+fin) => qw(v:потому_что), # 32
    qw(n:než+4) => qw(n:чем+4), # 30
    qw(adj:4) => qw(adj:4), # 30
    qw(n:pod+4) => qw(n:под+4), # 29
    qw(n:díky+3) => qw(n:благодаря+3), # 29  # nebo ...+2
    qw(n:mezi+4) => qw(n:между+4), # 27
    qw(n:místo+2) => qw(n:вместо+2), # 26
    qw(v:jako+fin) => qw(v:как+fin), # 25
    qw(v:zatímco+fin) => qw(v:в_то_время_как+fin), # 24
    qw(n:bez_ohledu_na+4) => qw(n:не_смотря_на+4), # 24
    qw(n:vedle+2) => qw(n:возле+2), # 23
    qw(n:na+X) => qw(n:на+X), # 23
    qw(v:ačkoli+fin) => qw(v:хотя+fin), # 22
    qw(n:ve_formě+2) => qw(n:в_форме+2), # 22
    #qw(v:jakmile+fin) => qw(), # 21
    qw(v:jakmile+fin) => qw(v:как_только+fin),
     qw(n:v_průběhu+2) => qw(n:в_течение+2), # 20
     # qw(n:ohledem_na+4) => qw(), # 20
     qw(n:s_výjimkou+2) => qw(n:с_исключением+2), # 19
     qw(n:v_zájmu+2) => qw(n:в_интересах+2), # 17
     qw(n:společně_s+7) => qw(n:вместе_с+7), # 17
     qw(v:že+rc) => qw(v:что+rc), # 15
     qw(n:nad+4) => qw(n:над+4), # 15
     qw(n:di+X) => qw(n:di+X), # 15
     qw(n:že+4) => qw(n:что+4), # 14
     qw(n:z+X) => qw(n:из+X), # 14
     qw(n:v_rozporu_s+7) => qw(n:вразрез_с+7), # 14
     qw(n:ve_srovnání_s+7) => qw(n:по_сравнению_с+7), # 14
     qw(n:v+X) => qw(n:в+X), # 13
     qw(n:že+1) => qw(n:что+1), # 12
     qw(n:ve_spojení_s+7) => qw(n:в_связи_с+7), # 12
     qw(n:souladu_s+7) => qw(n:в_согласии_с+7), # 12
     qw(n:směrem_k+3) => qw(n:по_направлению_к+3), # 12
     qw(v:přestože+fin) => qw(v:хотя+fin), # 11
     qw(v:dokud+fin) => qw(n:покa+fin), # 11
     qw(n:z_hlediska+2) => qw(n:с_точки_зрения+2), # 11
    # qw(n:závislosti_na+6) => qw(), # 11
     qw(n:o+X) => qw(n:o+X), # 11
     qw(n:oproti+3) => qw(n:по_сравнению_с+7), # 11
     qw(n:než_v+6) => qw(n:чем_в+6), # 11
    qw(n:uprostřed+2) => qw(n:среди+2), # 10
    qw(n:namísto+2) => qw(n:вместо+2), # 10
    qw(n:dle+2) => qw(n:для+2), # 10 stejne jako podle - TODO
     qw(v:že+inf) => qw(v:что+fin), # 9
     qw(v:jak+fin) => qw(v:как+fin), # 9
     qw(n:z_důvodu+2) => qw(n:по_причине+2), # 9
     qw(n:ve_vztahu_k+3) => qw(n:по_отношению_к+3), # 9
     qw(n:ve_smyslu+2) => qw(n:в_смысле+2), # 9
     qw(n:na_rozdíl_od+2) => qw(n:в_отличие_от+2), # 9
     qw(v:než_aby+fin) => qw(v:чем_чтобы+fin), # 8
     qw(v:ledaže+fin) => qw(v:разве_что+fin), # 8
     qw(n:že+X) => qw(n:что+X), # 8
     qw(n:za+X) => qw(n:за+X), # 8
    # qw(n:v_s+6) => qw(), # 8
    qw(n:uvnitř+2) => qw(n:внутри+2), # 8
    qw(n:podél+2) => qw(n:вдоль+2), # 8
    qw(n:navzdory+3) => qw(n:наперекор+3), # 8
     qw(n:k+X) => qw(n:к+X), # 8
     qw(v:ať+fin) => qw(v:пусть+fin), # 7
     qw(n:ve_prospěch+2) => qw(n:на_пользу+3), # 7
     qw(n:s+X) => qw(n:с+X), # 7
     qw(n:pro+X) => qw(n:для+X), # 7
     qw(n:jako+X) => qw(n:как+X), # 7
     qw(v:než+inf) => qw(n:чем+inf), # 6
     # qw(n:zatímco+2) => qw(), # 6
     qw(n:v_závislosti_na+6) => qw(n:в_зависимости_от+2), # 6
     qw(n:vyjma+2) => qw(n:исключая+4), # 6
    # qw(n:v_podobě+2) => qw(), # 6
     qw(n:ve_spolupráci_s+7) => qw(n:при_взаимодействии_с+7), # 6
     qw(n:u+X) => qw(), # 6
    # qw(n:s+4) => qw(), # 6
    # qw(n:spojení+2) => qw(), # 6
    qw(n:před+4) => qw(n:перед+4), # 6
    # qw(n:podle+X) => qw(), # 6
     qw(n:než+2) => qw(n:чем+2), # 6
     qw(n:mezi+X) => qw(n:между+X), # 6
     qw(n:jako+2) => qw(n:как+2), # 6
    # qw(n:di+1) => qw(), # 6
     qw(n:ze_strany+2) => qw(n:со_стороны+2), # 5
    # qw(n:takže+1) => qw(), # 5
    qw(n:skrz+4) => qw(n:сквозь+4), # 5
    # qw(n:pokud+1) => qw(), # 5
    qw(n:okolo+2) => qw(n:около+2), # 5
     qw(n:než_u+2) => qw(n:чем_у+2), # 5
     qw(n:následkem+2) => qw(n:в_следствие+2), # 5
     # qw(n:naproti+3) => qw(), # 5
     qw(n:jak+X) => qw(n:как+X), # 5
    # qw(n:aby+1) => qw(), # 5
    # qw(n:) => qw(), # 5
    # qw(adj:na+poss) => qw(), # 5
    # qw(v:než+rc) => qw(), # 4
    # qw(v:jako_kdyby+fin) => qw(), # 4
     qw(n:s_ohledem_na+X) => qw(n:с учётом+X), # 4
     qw(n:pokud+X) => qw(n:пока+X), # 4
     qw(n:od+X) => qw(n:от+X), # 4
    # qw(n:li+1) => qw(), # 4
    # qw(n:když+X) => qw(), # 4
     qw(n:jako_v+6) => qw(n:как_в+6), # 4
     qw(n:do+X) => qw(n:в+X), # 4
    # qw(n:aby+4) => qw(), # 4
    # qw(n:že+7) => qw(), # 3
    # qw(n:že+2) => qw(), # 3
    # qw(n:zpod+2) => qw(), # 3
     qw(n:vstříc+3) => qw(n:навстречу+3), # 3
     qw(n:v_rámci+X) => qw(n:в_рамках+X), # 3
     qw(n:souvislosti_s+7) => qw(n:в_связи_с+7), # 3
     qw(n:rozporu_s+7) => qw(n:вразрез_с+7), # 3
    # qw(n:pokud+) => qw(), # 3
    # qw(n:než_s+7) => qw(), # 3
    # qw(n:na_v+4) => qw(), # 3
    # qw(n:mimo+1) => qw(), # 3
    # qw(n:když+1) => qw(), # 3
     qw(n:jménem+2) => qw(n:от_имени+2), # 3
    # qw(n:de+1) => qw(), # 3
    # qw(n:aby_na+6) => qw(), # 3
    # qw(v:takže_jestli+fin) => qw(), # 2

);


sub process_tnode {
    my ( $self, $tnode ) = @_;

    if (defined $cs2ru{$tnode->formeme}) {
        $tnode->set_formeme($cs2ru{$tnode->formeme});
        $tnode->set_formeme_origin('rule-CS2RU::RuleBasedFormemes');
    }
    return;
}



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
