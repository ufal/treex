package Treex::Block::T2T::CS2RU::TrLTryRules;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my %QUICKFIX_TRANSLATION_OF => (
    q{Rusko} => 'Россия',
);

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # Skip nodes that were already translated by other rules
    return if $tnode->t_lemma_origin !~ /^clone/;

    my $src_tnode = $tnode->src_tnode or return;

    if ( my $lemma = $self->get_lemma( $src_tnode, $tnode ) ) {
        $tnode->set_t_lemma($lemma);
        $tnode->set_t_lemma_origin('rule-TrLTryRules');
    }
    return;
}

sub get_lemma {
    my ( $self, $src_tnode, $tnode ) = @_;
    my $src_tlemma = $src_tnode->t_lemma;

    # Don't translate t-lemma substitutes (like #PersPron, #Cor, #QCor, #Rcp)
    return $src_tlemma if $src_tlemma =~ /^#/;

    # Both left and right quotes are lemmatized to "
    if ( $src_tlemma eq q{"} ) {
        return $src_tnode->get_lex_anode()->form eq q{„} ? q{«} : q{»};
    }

    # Prevent some errors/misses in dictionaries
    return $QUICKFIX_TRANSLATION_OF{$src_tlemma};
}

1;

__END__

=over

=item Treex::Block::T2T::CS2RU::TrLTryRules

Try to apply some hand written rules for t-lemma translation.
If succeeded, t-lemma is filled and atributte C<t_lemma_origin> is set to I<rule>.

=back

=cut

# Copyright 2012 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
