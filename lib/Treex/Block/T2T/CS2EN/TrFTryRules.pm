package Treex::Block::T2T::CS2EN::TrFTryRules;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


Readonly my %RULE_TRANSL => (
    'drop'       => 'n:subj',  # pro-dropped Czech personal pronouns are always expressed in English
    'n:podle+2'  => 'n:according_to+X', # instead of n:attr or n:accord_to+X
);

sub process_tnode {
    my ( $self, $en_tnode ) = @_;

    # Skip nodes that were already translated by other rules
    return if $en_tnode->formeme_origin ne 'clone';

    my $cs_tnode = $en_tnode->src_tnode;
    return if !$cs_tnode;

    my $en_formeme = formeme_for_tnode( $cs_tnode, $en_tnode );
    if ( defined $en_formeme ) {
        $en_tnode->set_formeme($en_formeme);
        $en_tnode->set_formeme_origin('rule-Translate_F_try_rules');
    }
    return;
}

sub formeme_for_tnode {
    my ( $cs_tnode,  $en_tnode ) = @_;
    
    my $cs_formeme = $cs_tnode->formeme;

    return $RULE_TRANSL{$cs_formeme};
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::CS2EN::TrFTryRules

=head1 DESCRIPTION

Simple formeme translation rules that are tried before the dictionary translation
(and have thus higher priority). They are intended to be temporary fixes.

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
