package Treex::Block::T2A::NL::Alpino::FixPrec;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # only apply to the non-coordination nodes with "en", "maar", "of" that have no children
    return if ( $tnode->formeme ne 'x' or $tnode->t_lemma !~ /^(en|maar|of)$/ or $tnode->is_coap_root );
    return if ( $tnode->get_children() );

    # require exactly 2nd depth level
    my $anode = $tnode->get_lex_anode() or return;
    my $aparent = $anode->get_parent();
    return if ( $aparent->is_root or !$aparent->get_parent->is_root() );

    $anode->set_parent( $aparent->get_parent() );
    $aparent->set_parent($anode);
    $aparent->wild->{adt_phrase_rel} = 'nucl';
    $anode->wild->{adt_term_rel}   = 'dlink';

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::FixPrec

=head1 DESCRIPTION

This rehangs the PREC/AuxY conjuctions (en, maar, of) that begin a sentence,
linking to previous text.

After the rehanging, these conjunctions will function as sentence roots
and will contain prepared "adt_phrase_rel" and "adt_term_rel" labels for "nucl" and "dlink". 

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

    
