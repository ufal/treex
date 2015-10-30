package Treex::Block::T2T::EN2PT::TrL_ITdomain;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my %QUICKFIX_TRANSLATION_OF => (


    q{settings}  => 'definições|X',
    q{setting}   => 'definições|X',
    q{menu}      => 'menu|X',
    q{touch}     => 'toque|X',
    q{tap}       => 'toque|X',
    q{tab}       => 'separador|X',
    q{tool}      => 'ferramenta|X',
    q{tools}     => 'ferramentas|X',
    q{site}      => 'site|X',
    q{key}       => 'tecla|X',
    q{folder}    => 'pasta|X',
    q{password}  => 'password|X',
    q{itunes}    => 'Itunes|X',
    q{wireless}  => 'wireless|X',
    q{search}    => 'pesquisa|X',
    q{link}      => 'link|X',
    q{file}      => 'ficheiro|X',

);


sub process_tnode {
    my ( $self, $pt_tnode ) = @_;

    # Skip nodes that were already translated by other rules
    # return if $pt_tnode->t_lemma_origin !~ /^(clone|lookup)/;

    my $en_tnode = $pt_tnode->src_tnode or return;
    my $lemma_and_pos = $self->get_lemma_and_pos( $en_tnode, $pt_tnode );
    if ( defined $lemma_and_pos ) {
        my ( $pt_tlemma, $m_pos ) = split /\|/, $lemma_and_pos;
        $pt_tnode->set_t_lemma($pt_tlemma);
        $pt_tnode->set_t_lemma_origin('rule-TrL_ITdomain');
        $pt_tnode->set_attr( 'mlayer_pos', $m_pos )
    }
    return;
}

sub get_lemma_and_pos {
    my ( $self, $en_tnode, $pt_tnode ) = @_;
    my ( $en_tlemma, $en_formeme ) = $en_tnode->get_attrs(qw(t_lemma formeme));

    # Prevent some errors/misses in dictionaries
    my $lemma_and_pos = $QUICKFIX_TRANSLATION_OF{lc $en_tlemma};
    return $lemma_and_pos if $lemma_and_pos;

    # If no rules match, get_lemma_and_pos has not succeeded.
    return undef;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2PT::TrL_ITdomain

Try to apply some hand written rules for t-lemma translation specific for IT domain.
If succeeded, t-lemma is filled and atributte C<t_lemma_origin> is set to I<rule>.

=back

=cut

# Copyright 2015 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

