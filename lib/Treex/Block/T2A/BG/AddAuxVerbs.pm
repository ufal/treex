package Treex::Block::T2A::BG::AddAuxVerbs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    return if $tnode->formeme !~ /^v:.*fin/;
    my $anode = $tnode->get_lex_anode() or return;

    if (($tnode->gram_tense||'') eq 'post') {
        my $new_node = $anode->create_child({
            lemma => 'ще',
            form  => 'ще',
            afun  => 'AuxV',
        });
        $new_node->shift_before_node($anode);
        $new_node->iset->add( pos => 'part', verbtype => 'aux' );
        $tnode->add_aux_anodes($new_node);
    }

#     if (($tnode->gram_diathesis||'') eq 'pas') {
#         # TODO: the form depends on tense
#         # either do the inflection here or fill the correct iset features for GenerateWordforms
#         my $new_node = $anode->create_child({
#             lemma => 'е', # TODO 'съм',
#             form  => 'е',
#             afun  => 'AuxV',
#         });
#         $new_node->shift_before_node($anode);
#         $new_node->iset->add( pos => 'verb', verbtype => 'aux', verbform => 'fin' );
#         $tnode->add_aux_anodes($new_node);
#     }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::BG::AddAuxVerbs

=head1 DESCRIPTION

Add auxiliary verbs

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
