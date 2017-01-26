package Treex::Block::W2A::RU::FixPronouns;
use utf8;
use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/any/;

extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;

    my $tag = $anode->tag;
    my $lemma = lc($anode->lemma);
    my $form = lc($anode->form);

    return if ($tag !~ /^[AN]/);

    my @form_ords = map {ord($_)} split(//, $anode->form);
    # if the word contains a letter in cyrilics, change all the latin letters to their same looking cyrilic variants
    if (any {$_ > 1000} @form_ords) {
        $form =~ s/o/о/g;
        $form =~ s/a/а/g;
        $form =~ s/e/е/g;
        $form =~ s/p/р/g;
        $form =~ s/c/с/g;
        $form =~ s/y/у/g;
        $form =~ s/x/х/g;
    }

    ############### SETTING POS AND SUBPOS ##################

    $tag =~ s/^../PP/ if ($form =~ /^(я|меня|мне|мной)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(ты|тебя|тебе|тобой)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(мы|нас|нам|нами)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(вы|вас|вам|вами)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(он|его|ему|им)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(она|её|ее|ей|ею)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(оно|его|ему|им)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(они|их|им|ими)$/);
    
    $tag =~ s/^../P5/ if ($form =~ /^н(ём|его|ему|им)$/);
    $tag =~ s/^../P5/ if ($form =~ /^н(ей|её|ее|ею)$/);
    $tag =~ s/^../P5/ if ($form =~ /^н(их|им|ими)$/);

    $tag =~ s/^../PS/ if ($form =~ /^(мо|тво)(й|я|ё|и|его|ю|их|ей|ему|им|ими|ём|ем)$/);
    $tag =~ s/^../PS/ if ($form =~ /^(наш|ваш)(а|е|и|его|у|их|ей|ему|им|ими|ем)$/);
    $tag =~ s/^../PS/ if ($form =~ /^(его|её|ее|их)$/);
   
    # TODO: what about reflexive verbs e.g. умываться
    $tag =~ s/^../P6/ if ($form =~ /^(себ(я|е|ой)|собой)$/);
    $tag =~ s/^../P8/ if ($form =~ /^сво(й|я|ё|е|и|его|ю|их|ей|ему|им|ими|ём|ем)$/);

    $tag =~ s/^../P4/ if ($lemma =~ /^(который|какой|чей)$/);
    $tag =~ s/^../PK/ if ($lemma =~ /^кто$/);
    $tag =~ s/^../PQ/ if ($lemma =~ /^что$/);
    $tag =~ s/^../PD/ if ($lemma =~ /^это$/);
    
    ############### SETTING POS AND SUBPOS ##################

    $tag =~ s/^(.......)[-X]/${1}1/ if ($lemma =~ /^(я|мой|мы|наш)$/);
    $tag =~ s/^(.......)[-X]/${1}2/ if ($lemma =~ /^(ты|твой|вы|ваш)$/);
    $tag =~ s/^(.......)[-X]/${1}3/ if ($lemma =~ /^(он|она|оно|ее|его|они|их)$/);
    
    $anode->set_tag($tag);
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::RU::FixPronouns

=head1 DESCRIPTION


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
