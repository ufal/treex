package Treex::Block::T2T::CS2EN::TrLFTreeViterbi;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'lm_weight' => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.2,
    documentation => 'Weight of tree language model (or transition) logprobs.',
);

has 'formeme_weight' => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.9,
    documentation => 'Weight of formeme forward logprobs.',
);

has 'backward_weight' => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0,
    documentation => 'Weight of backward lemma logprobs'
        . ' - ie. logprob(src_lemma|trg_lemma).'
        . ' This must be number from the [0,1] interval.'
        . ' Weight of forward logprobs - ie. logprob(trg_lemma|src_lemma)'
        . ' is set to 1 - BACKWARD_WEIGHT.',
);

has lm_dir => (
    is      => 'ro',
    isa     => 'Str',
    default => 'en.czeng',
);

use Treex::Tool::Algorithm::TreeViterbi;
use Treex::Tool::Lexicon::CS;
use Treex::Tool::LM::TreeLM;

sub BUILD {
    my ($self) = @_;

    return;
}

sub process_start
{
    my ($self) = @_;

    my $lm_rel_path = 'data/models/language/' . $self->lm_dir;
    my ( $lm_fn1, $lm_fn2, $lm_ids ) = $self->require_files_from_share( "$lm_rel_path/c_LgFdLd.pls.gz", "$lm_rel_path/c_PgFdLd.pls.gz", "$lm_rel_path/lemma_id.pls.gz" );
    my $lm_abs_path = $lm_fn1;
    $lm_abs_path =~ s/c_LgFdLd.pls.gz//;
    MyTreeViterbiState->set_tree_model( Treex::Tool::LM::TreeLM->new( { dir => $lm_abs_path } ) );
    MyTreeViterbiState->set_lm_weight( $self->lm_weight );
    MyTreeViterbiState->set_formeme_weight( $self->formeme_weight );
    MyTreeViterbiState->set_backward_weight( $self->backward_weight );
    MyTreeViterbiState->set_lemma_id_file($lm_ids);

    $self->SUPER::process_start();

    return;
}

sub process_ttree {
    my ( $self, $root ) = @_;
    Treex::Core::Log::progress();

    # Do the real work
    my ($root_state) = Treex::Tool::Algorithm::TreeViterbi::run( $root, \&get_states_of );
    my @states = @{ $root_state->backpointers };

    # Now follow backpointers and fill new lemmas & formemes
    while (@states) {

        # Get first state from the queue and push in the queue its children
        my $state = shift @states;
        next if !$state;    #TODO jak se toto muze stat
        push @states, @{ $state->backpointers };
        my $node = $state->node;

        # Change the lemma (only if different)
        my $new_lemma = $state->lemma;
        my $old_pos   = $node->get_attr('mlayer_pos') || '';
        my $new_pos   = $state->pos || '';

        if ( $new_lemma ne $node->t_lemma ) {
            $node->set_t_lemma($new_lemma);
            $node->set_attr( 'mlayer_pos', $state->pos );
            $node->set_t_lemma_origin( 'viterbi|' . $state->lemma_origin );
        }

        # Change the formeme
        my $new_formeme = $state->formeme;
        if ( $new_formeme ne $node->formeme ) {
            $node->set_formeme($new_formeme);
            $node->set_formeme_origin('viterbi');
        }
    }
    return;
}

# This function is passed as a hook to TreeViterbi algorithm
sub get_states_of {
    my ($node) = @_;

    # Root is a special case
    if ( $node->is_root() ) {
        my $fake = { t_lemma => '_ROOT', formeme => '_ROOT', logprob => 0, backward_logprob => 0 };
        return MyTreeViterbiState->new( { node => $node, lemma_v => $fake, formeme_v => $fake } );
    }

    # Get lemma/formeme variants filled in previous blocks
    my $ls_ref = $node->get_attr('translation_model/t_lemma_variants');
    my $fs_ref = $node->get_attr('translation_model/formeme_variants');

    # Sometimes there are no variants but only the attribute (if translated by rules)
    if ( !defined $ls_ref ) { $ls_ref = [ { t_lemma => $node->t_lemma, pos => $node->get_attr('mlayer_pos'), logprob => 0, backward_logprob => 0 } ]; }
    if ( !defined $fs_ref ) { $fs_ref = [ { formeme => $node->formeme, logprob => 0, backward_logprob => 0 } ]; }

    # States are the Cartesian product of lemmas and formemes
    # However, for efficiency output only the compatible lemmas&formemes.
    my @states = ();
    foreach my $l_v ( @{$ls_ref} ) {
        foreach my $f_v ( @{$fs_ref} ) {
            next if !is_compatible( $l_v, $f_v, $node );
            push @states, MyTreeViterbiState->new(
                { node => $node, lemma_v => $l_v, formeme_v => $f_v }
            );
        }
    }

    # If no combination of lemma and formeme is compatible
    # let's output all combinations.
    # However, usually these cases are "lost" (parser errors etc).
    if ( !@states ) {
        foreach my $l_v ( @{$ls_ref} ) {
            foreach my $f_v ( @{$fs_ref} ) {
                push @states, MyTreeViterbiState->new(
                    { node => $node, lemma_v => $l_v, formeme_v => $f_v }
                );
            }
        }
    }
    return @states;
}

## Compatibility of lemma (its pos) and formeme (its semantic pos), and some other constraints
#sub is_compatible {
#    my ( $l_v, $f_v, $node ) = @_;
#
#    # constraints required by possessive forms
#    if (( $l_v->{'pos'} || '' ) eq 'N'    #TODO Why is pos undefined?
#        and $f_v->{formeme} eq "n:poss"
#        and (
#            $node->get_children
#            or not Treex::Tool::Lexicon::CS::get_poss_adj( $l_v->{t_lemma} )
#            or ( $node->gram_number || "" ) eq "pl"
#        )
#        )
#    {
#
#        #        print "Incompatible: $l_v->{t_lemma}\n";
#        return 0;
#    }
#
#    # genitives are allowed only below a very limited set of verbs in Czech
#    if ( $f_v->{formeme} eq "n:2" and ( $node->get_parent->get_attr('mlayer_pos') || "" ) eq "V" ) {
#
#        #        print "Avoiding genitive below ".$node->get_parent->t_lemma."\n";
#        return 0;
#    }
#
#    return Treex::Tool::LM::TreeLM::is_pos_and_formeme_compatible( $l_v->{'pos'}, $f_v->{formeme} )
#}

sub is_compatible {
    my ( $pos, $formeme, $tnode ) = @_;

    return 1 if ( $pos eq 'verb'                       and $formeme =~ /^v/ );
    return 1 if ( $pos =~ /^(noun|adj|num)$/           and $formeme =~ /^n/ );
    return 1 if ( $pos =~ /^(adj|num)$/                and $formeme =~ /^adj/ );
    return 1 if ( $pos eq 'adv'                        and $formeme =~ /^adv/ );
    return 1 if ( $pos =~ /^(conj|part|int|punc|sym)$/ and $formeme eq 'x' );

    return 0;
}

#-------------------------------------------------------------
## no critic (ProhibitMultiplePackages);
# New class for our states.
# It's closely related to the block above
# so it is comfortable to define it in the same file.
package MyTreeViterbiState;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Algorithm::TreeViterbiState';

use Treex::Tool::LM::Lemma;

has [qw(lemma_v formeme_v)] => ( is => 'rw' );

# Global attributes of all states
my ( $lm_weight, $formeme_weight, $backward_weight, $tree_model );
sub set_lm_weight       { return $lm_weight       = $_[1]; }
sub set_formeme_weight  { return $formeme_weight  = $_[1]; }
sub set_backward_weight { return $backward_weight = $_[1]; }
sub set_tree_model      { return $tree_model      = $_[1]; }
sub set_lemma_id_file   { return Treex::Tool::LM::Lemma::init( $_[1] ); }

sub lemma {
    my ($self) = @_;
    return $self->lemma_v->{t_lemma};
}

sub pos {
    my ($self) = @_;
    return $self->lemma_v->{pos};
}

sub formeme {
    my ($self) = @_;
    return $self->formeme_v->{formeme};
}

sub lemma_origin {
    my ($self) = @_;
    return ( $self->lemma_v->{origin} || 'undef' );
}

sub get_logprob {
    my ($self) = @_;

    my $l = ( $backward_weight == 0 ? 0 : $backward_weight * $self->lemma_v->{backward_logprob} )
        + ( 1 - $backward_weight ) * $self->lemma_v->{logprob};

    my $f = $self->formeme_v->{logprob};
    return $l + ( $formeme_weight * $f );
}

sub get_logprob_given_parent {
    my ( $self, $state ) = @_;
    my $my_formeme   = $self->formeme;
    my $my_lemma     = Treex::Tool::LM::Lemma->new( $self->lemma, $self->pos );
    my $parent_lemma = Treex::Tool::LM::Lemma->new( $state->lemma, $state->pos );

    my $logprob = $tree_model->get_logprob_LdFd_given_Lg( $my_lemma, $my_formeme, $parent_lemma );
    return $lm_weight * $logprob;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrLFTreeViterbi

Apply Tree-Viterbi algorithm to find optimal choices of formemes and lemmas.

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
