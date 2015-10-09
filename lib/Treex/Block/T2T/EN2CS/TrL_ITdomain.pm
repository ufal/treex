package Treex::Block::T2T::EN2CS::TrL_ITdomain;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my %QUICKFIX_TRANSLATION_OF => (
    q{Wi-Fi}      => 'Wi-Fi|X',
    q{WiFi}       => 'WiFi|X',
    q{wi-fi}      => 'Wi-Fi|X',
    q{sm}         => 'SMS|X',
    q{Start}      => 'Start|X',
    q{Windows}    => 'Windows|X',
    q{Word}       => 'Word|X',
    q{Chrome}     => 'Chrome|X',
    q{gbp}        => 'Gb/s|X',
    q{mbp}        => 'Mb/s|X',
    q{10.04}      => '10.04|X',
    q{ruler}      => 'pravítko|N',
    q{right-click}=> 'pravým tlačítkem myši klikněte|V',
);

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by other rules
    return if $cs_tnode->t_lemma_origin !~ /^(clone|lookup)/;

    my $en_tnode = $cs_tnode->src_tnode or return;
    my $lemma_and_pos = $self->get_lemma_and_pos( $en_tnode, $cs_tnode );
    if ( defined $lemma_and_pos ) {
        my ( $cs_tlemma, $m_pos ) = split /\|/, $lemma_and_pos;
        $cs_tnode->set_t_lemma($cs_tlemma);
        $cs_tnode->set_t_lemma_origin('rule-TrL_ITdomain');
        $cs_tnode->set_attr( 'mlayer_pos', $m_pos )
    }
    return;
}

sub get_lemma_and_pos {
    my ( $self, $en_tnode, $cs_tnode ) = @_;
    my ( $en_tlemma, $en_formeme ) = $en_tnode->get_attrs(qw(t_lemma formeme));

    # Prevent some errors/misses in dictionaries
    my $lemma_and_pos = $QUICKFIX_TRANSLATION_OF{$en_tlemma};
    return $lemma_and_pos if $lemma_and_pos;
   
    # Imperative "go" in IT instructions is "přejděte" rather than "pojďte".
    if ( $en_tlemma eq 'go' && defined $en_tnode->gram_verbmod){
        return 'přejít|V';
    }

    # Windows may be tagged as NNS (instead of NNP)
    return 'Windows|X' if $en_tlemma eq 'window' && $en_tnode->get_lex_anode->form eq 'Windows';
    
    # imperatives
    if (($en_tnode->gram_verbmod || '') eq 'imp'){
        return 'stisknout|V' if $en_tlemma eq 'press';
        return 'kliknout|V'  if $en_tlemma eq 'click';    
        return 'přihlásit|V' if $en_tlemma eq 'access' && any {$_->t_lemma =~ /^(profile|account)$/} $en_tnode->get_echildren();
        return 'vstoupit|V'  if $en_tlemma eq 'access';
    }

    if ( $en_tlemma eq 'email'){
        return 'e-mailový|A' if ($en_tnode->get_parent->formeme ||'') =~ /^n:/;
        return 'e-mail|N';
    }

    # If no rules match, get_lemma_and_pos has not succeeded.
    return undef;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrL_ITdomain

Try to apply some hand written rules for t-lemma translation specific for IT domain.
If succeeded, t-lemma is filled and atributte C<t_lemma_origin> is set to I<rule>.

=back

=cut

# Copyright 2015 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

