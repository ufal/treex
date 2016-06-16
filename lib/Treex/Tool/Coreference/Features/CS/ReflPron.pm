package Treex::Tool::Coreference::Features::CS::ReflPron;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Lexicon::CS;

extends 'Treex::Tool::Coreference::Features::ReflPron';

my $UNDEF_VALUE = "undef";

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;

    my $anode = $node->get_lex_anode;
    $feats->{'lemma'} = defined $anode ? Treex::Tool::Lexicon::CS::truncate_lemma($anode->lemma) : $UNDEF_VALUE;
    $feats->{'subpos'} = defined $anode ? substr($anode->tag, 1, 1) : $UNDEF_VALUE;

    my $sub_feats = inner() || {};
    return { %$feats, %$sub_feats };
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::Features::CS::ReflPron

=head1 DESCRIPTION

A subclass of features for CR of Czech reflexive pronouns.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-16 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
