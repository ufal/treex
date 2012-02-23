package Treex::Block::T2T::EN2CS::PruneVariants;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has attribute => (
    is            => 'ro',
    isa           => enum( [qw(t_lemma formeme)] ),
    required      => 1,
    documentation => 'Should we prune lemmas or formemes?',
);

has [qw(count count_per_pos)] => (
    is            => 'ro',
    isa           => 'Int',
    default       => 0,
    documentation => 'Retain at most this number of translation variants. 0 means infinity.'
);

has [qw(prob_sum prob_sum_per_pos)] => (
    is            => 'ro',
    isa           => 'Num',
    default       => 1,
    documentation => 'Retain at most N translation variants,'
        . ' where N is the smallest number so that a sum of N first probabilities'
        . ' is higher (or equal) than this parameter.'
);

sub process_tnode {
    my ( $self, $node ) = @_;

    my $att_name    = 'translation_model/' . $self->attribute . '_variants';
    my $variants_rf = $node->get_attr($att_name);
    return if !$variants_rf;

    my $sum      = $self->prob_sum;
    my $sum_pp   = $self->prob_sum_per_pos;
    my $count    = $self->count;
    my $count_pp = $self->count_per_pos;
    my $is_lemma = $self->attribute eq 't_lemma';

    my ( %prob_pp, %n_pp, @pruned );
    my ( $prob, $n ) = ( 0, 0 );
    foreach my $variant ( @{$variants_rf} ) {
        my $p = 2**$variant->{logprob};
        my $postag;
        if ($is_lemma) {
            $postag = $variant->{'pos'};
        }
        else {
            ($postag) = $variant->{formeme} =~ /^(.)/;
        }

        # First, check constraints per PoS tags.
        # (prob_sum is checked *before* increasing, cf. its definition)
        next if ( $prob_pp{$postag} || 0 ) >= $sum_pp;
        $prob_pp{$postag} += $p;
        $n_pp{$postag}++;
        next if $count_pp && $n_pp{$postag} > $count_pp;

        # Second, check general constraints.
        # Here, we can safely exit the loop.
        last if $prob >= $sum;
        $prob += $p;
        $n++;
        last if $count && $n > $count;

        push @pruned, $variant;
    }

    $node->set_attr( $att_name, \@pruned );
    return;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::T2T::EN2CS::PruneVariants - delete less probable translations

=head1 DESCRIPTION

Utility block that deletes some translation variants of t-lemmas or formemes
stored in C<translation_model/t_lemma_variants> and
C<translation_model/formeme_variants> attributes.
Generally, only the most probable variants are retained,
but using I<per_pos> parameters you can enforce that the final pruned variants
will include various part-of-speech tags.

Conditions are evaluated in conjunction, for example, if count=3 and prob_sum=0.6

 nodeA: prob1=0.5 prob2=0.2 prob3=0.1             ... 2 variants left (sum=0.7)
 nodeB: prob1=0.3 prob2=0.1 prob3=0.1 prob4=0.05  ... 3 variants left (sum=0.5)


=head1 PARAMETERS

=head2 attribute

Can be either C<t_lemma> or C<formeme>.

=head2 count

At most C<count> variants (the most probable ones) are left.

=head2 prob_sum

Retain at most N translation variants,
where N is the smallest number so that a sum of N first probabilities
is higher (or equal) than this parameter.

=head2 count_per_pos

Same as C<count>, but there is a separate counter for each part-of-speech tag.
For example, if C<count_per_pos=5> then there can be up to 5 nouns, 5 verbs etc.
The part-of-speech must be encoded as the first letter of formemes (syntpos)
and as the C<translation_model/t_lemma_variants/[*]/pos> attribute for lemmas.

=head2 prob_sum_per_pos

Same as C<prob_sum>, but there is a separate counter for each part-of-speech tag.

=cut

# Copyright 2008-2012 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
