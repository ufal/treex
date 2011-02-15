package Treex::Block::T2T::EN2CS::TrLFTreeViterbi;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

use Report;
use TreeViterbi;

use Lexicon::Czech;
use LanguageModel::TreeLM;

sub BUILD {
    MyTreeViterbiState->set_tree_model( LanguageModel::TreeLM->new() );
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    MyTreeViterbiState->set_lm_weight( $self->get_parameter('LM_WEIGHT') );
    MyTreeViterbiState->set_formeme_weight( $self->get_parameter('FORMEME_WEIGHT') );
    MyTreeViterbiState->set_backward_weight( $self->get_parameter('BACKWARD_WEIGHT') );
    Report::progress();

    # Do the real work
    my $root = $bundle->get_tree('TCzechT');
    my ($root_state) = TreeViterbi::run( $root, \&get_states_of );
    my @states = @{ $root_state->get_backpointers() };

    # Now follow backpointers and fill new lemmas & formemes
    while (@states) {

        # Get first state from the queue and push in the queue its children
        my $state = shift @states;
        next if !$state;    #TODO jak se toto muze stat
        push @states, @{ $state->get_backpointers() };
        my $node = $state->get_node();

        # Change the lemma (only if different)
        my $new_lemma = $state->get_lemma();
        my $old_pos   = $node->get_attr('mlayer_pos') || '';
        my $new_pos   = $state->get_pos() || '';

        if ($new_lemma ne $node->t_lemma
            or
            ( $old_pos ne $new_pos and $new_lemma !~ /^(tisíc|ráno|večer)$/ )
            )
        {    # ??? tisic.C->tisic.N makes harm!!!
            $node->set_t_lemma($new_lemma);
            $node->set_attr( 'mlayer_pos', $state->get_pos );
            $node->set_t_lemma_origin( 'viterbi|' . $state->get_lemma_origin );
        }

        # Change the formeme
        my $new_formeme = $state->get_formeme();
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

    # only childless nodes can have possessive forms
    #    if ($node->get_children) {
    #        $fs_ref = [grep {$_->{formeme} ne "n:poss"} @$fs_ref];
    #    }

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

# Compatibility of lemma (its pos) and formeme (its semantic pos), and some other constraints
sub is_compatible {
    my ( $l_v, $f_v, $node ) = @_;

    # constraints required by possessive forms
    if (( $l_v->{'pos'} || '' ) eq 'N'    #TODO Why is pos undefined?
        and $f_v->{formeme} eq "n:poss"
        and (
            $node->get_children
            or not Lexicon::Czech::get_poss_adj( $l_v->{t_lemma} )
            or ( $node->get_attr('gram/number') || "" ) eq "pl"
        )
        )
    {

        #        print "Incompatible: $l_v->{t_lemma}\n";
        return 0;
    }

    # genitives are allowed only below a very limited set of verbs in Czech
    if ( $f_v->{formeme} eq "n:2" and ( $node->get_parent->get_attr('mlayer_pos') || "" ) eq "V" ) {

        #        print "Avoiding genitive below ".$node->get_parent->t_lemma."\n";
        return 0;
    }

    return LanguageModel::TreeLM::is_pos_and_formeme_compatible( $l_v->{'pos'}, $f_v->{formeme} )
}

#-------------------------------------------------------------
## no critic (ProhibitMultiplePackages);
# New class for our states.
# It's closely related to the block above
# so it is comfortable to define it in the same file.
package MyTreeViterbiState;
use base 'TreeViterbiState';

use LanguageModel::Lemma;

# Parameters
Readonly my $DEFAULT_LM_WEIGHT       => 0.5;
Readonly my $DEFAULT_FORMEME_WEIGHT  => 1;
Readonly my $DEFAULT_BACKWARD_WEIGHT => 0.3;
my ( $lm_weight, $formeme_weight, $backward_weight, $tree_model );
sub set_lm_weight       { return $lm_weight       = defined $_[1] ? $_[1] : $DEFAULT_LM_WEIGHT; }
sub set_formeme_weight  { return $formeme_weight  = defined $_[1] ? $_[1] : $DEFAULT_FORMEME_WEIGHT; }
sub set_backward_weight { return $backward_weight = defined $_[1] ? $_[1] : $DEFAULT_BACKWARD_WEIGHT; }
sub set_tree_model      { return $tree_model      = $_[1]; }

## no critic (ProhibitUnusedVariables);
## These are Class::Std attributes, not unused variables
my %lemma_v_of : ATTR( :get<lemma_v>   :init_arg<lemma_v> );
my %formeme_v_of : ATTR( :get<formeme_v> :init_arg<formeme_v> );
## use critic

sub get_lemma {
    my ($self) = @_;
    return $self->get_lemma_v()->{t_lemma};
}

sub get_pos {
    my ($self) = @_;
    return $self->get_lemma_v()->{'pos'};
}

sub get_formeme {
    my ($self) = @_;
    return $self->get_formeme_v()->{formeme};
}

sub get_lemma_origin {
    my ($self) = @_;
    return ( $self->get_lemma_v()->{origin} || "undef" );
}

sub get_logprob {
    my ($self) = @_;

    my $l = ( $backward_weight == 0 ? 0 : $backward_weight * $self->get_lemma_v()->{backward_logprob} )
        + ( 1 - $backward_weight ) * $self->get_lemma_v()->{logprob};

    my $f = $self->get_formeme_v()->{logprob};
    return $l + ( $formeme_weight * $f );
}

sub get_logprob_given_parent {
    my ( $self, $state ) = @_;
    my $my_formeme   = $self->get_formeme();
    my $my_lemma     = LanguageModel::Lemma->new( $self->get_lemma(), $self->get_pos() );
    my $parent_lemma = LanguageModel::Lemma->new( $state->get_lemma(), $state->get_pos() );

    my $logprob = $tree_model->get_logprob_LdFd_given_Lg( $my_lemma, $my_formeme, $parent_lemma );
    return $lm_weight * $logprob;
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrLFTreeViterbi

Apply Tree-Viterbi algorithm to find optimal choices of formemes and lemmas.

PARAMETERS:

=over

=item LM_WEIGHT = 0.5
Weight of tree language model (or transition) logprobs.

=item FORMEME_WEIGHT = 1
Weight of formeme forward logprobs.

=item BACKWARD_WEIGHT = 0.3
Weight of backward lemma logprobs - ie. logprob(src_lemma|trg_lemma).
This must be number from the [0,1] interval.
Weight of forward logprobs - ie. logprob(trg_lemma|src_lemma) is set to
1 - BACKWARD_WEIGHT.

=back

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
