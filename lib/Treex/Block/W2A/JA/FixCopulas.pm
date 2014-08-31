package Treex::Block::W2A::JA::FixCopulas;

use strict;
use warnings;

use Moose;
use Treex::Core::Common;
use Encode;

extends 'Treex::Core::Block';


# TODO: "では" is actually tokenized as "で" and "は" (both tokens marked as particles). Where should we fix this?

sub process_atree {
    my ( $self, $a_root ) = @_;
    foreach my $child ( $a_root->get_children() ) {
        fix_subtree($child);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;
    my $lemma = $a_node->lemma;
 
    # we change lemma of "じゃ" and "では" 
    if ( $lemma eq "じゃ" || $lemma eq "では" ) {
        foreach my $child ( $a_node->get_children() ) {
            $a_node->set_lemma("です");
        }
    }
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::JA::FixCopulas - Fixes lemmatization of negative copula stems. 

=head1 DECRIPTION

Fixes lemma for copula forms, which are used when creating negation. 

=head1 AUTHOR

Dušan Variš <dvaris@seznam.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
