package Treex::Block::A2T::SK::FixNumerals;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS::Numerals;


extends 'Treex::Block::A2T::CS::FixNumerals';

override '_lemma_and_tag' => sub {
    my ( $self, $anode ) = @_;
    # return PDT-style tag (non-strict encoding)
    return ( $anode->lemma, $anode->wild->{tag_cs_pdt} );
};

override '_check_noncongr_numeral' => sub {
    my ( $self, $anode ) = @_; 
    return Treex::Tool::Lexicon::CS::Numerals::is_noncongr_numeral( $self->_lemma_and_tag($anode) );
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::FixNumerals

=head1 DESCRIPTION

Swap all incongruent numerals with their "genitive attribute" which in fact is their parent 
on the t-layer.

Since the congruency behavior of numerals is basically the same in Czech and Slovak, 
this block is only a thin layer above L<Treex::Block::A2T::CS::FixNumerals> that ensures the same
format of a-node lemmas and tags.

TODO: Check if the tagset conversion works well enough.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
