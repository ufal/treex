package Treex::Block::W2A::DE::FixPronouns;
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

    return if ($tag !~ /^[PAN]/);

    # some lemmas "ihr" shoulf be "sie" in fact - its tag suggests so
    $lemma = "sie" if ($tag =~ /^PPFS3/ && $form eq "ihr");

    $tag =~ s/^(.......)[X-]/${1}1/ if ($lemma =~ /^unser/);
    $tag =~ s/^(.......)[X-]/${1}1/ if ($lemma =~ /^mein/);
    $tag =~ s/^(.......)[X-]/${1}2/ if ($lemma =~ /^euer/);
    $tag =~ s/^(.......)[X-]/${1}2/ if ($lemma =~ /^dein/);
    $tag =~ s/^(PS.....)[X-]/${1}3/ if ($lemma =~ /^sein/);
    $tag =~ s/^(PS.....)[X-]/${1}3/ if ($lemma =~ /^ihr/);
    
    $anode->set_tag($tag);
    $anode->set_lemma($lemma);
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::DE::FixPronouns

=head1 DESCRIPTION


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
