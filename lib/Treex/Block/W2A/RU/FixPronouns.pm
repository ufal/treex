package Treex::Block::W2A::RU::FixPronouns;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;

    my $tag = $anode->tag;
    my $lemma = lc($anode->lemma);
    my $form = lc($anode->form);

    return if ($tag !~ /^[AN]/);
    
    $tag =~ s/^../PP/ if ($form =~ /^(я|меня|мне|мной)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(ты|тебя|тебе|тобой)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(мы|нас|нам|нами)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(вы|вас|вам|вами)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(oн|его|ему|им)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(oнa|её|eй|ею)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(oнo|его|ему|им)$/);
    $tag =~ s/^../PP/ if ($form =~ /^(oни|их|им|ими)$/);
    
    $tag =~ s/^../P5/ if ($form =~ /^(нём|ней|них)$/);

    $tag =~ s/^../PS/ if ($form =~ /^(мо|тво)(й|я|ё|и|его|ю|их|ей|ему|им|ими|ём)$/);
    $tag =~ s/^../PS/ if ($form =~ /^(наш|ваш)(а|е|и|его|у|их|ей|ему|им|ими|ем)$/);
    $tag =~ s/^../PS/ if ($form =~ /^(его|её|их)$/);
    
    $tag =~ s/^../P8/ if ($form =~ /^сво(й|я|ё|и|его|ю|их|ей|ему|им|ими|ём)$/);

    $tag =~ s/^../P4/ if ($lemma =~ /^(который|какой|чей)$/);
    $tag =~ s/^../PK/ if ($lemma =~ /^кто$/);
    $tag =~ s/^../PQ/ if ($lemma =~ /^что$/);
    $tag =~ s/^../PD/ if ($lemma =~ /^это$/);
    
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
