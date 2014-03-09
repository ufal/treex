package Treex::Block::SemevalABSA::KnownAspect;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::SemevalABSA::BaseRule';

has forms => (
    isa => 'HashRef',
    is  => 'rw',
);

has lemmas => (
    isa => 'HashRef',
    is  => 'rw',
);

has aspect_file => (
    isa           => 'Str',
    is            => 'ro',
    required      => 1,
);

sub BUILD {
    my ( $self ) = @_;
    open( my $hdl, $self->{aspect_file} ) or log_fatal "$self->{aspect_file}: $!";
    while (<$hdl>) {
        chomp;
        my ( $form, $lemma, $tag ) = split /\|/;
        log_fatal "Bad format of line '$_' in $self->{aspect_file}" if ! $tag;
        $self->{forms}->{lc($form)} = 1;
        $self->{lemmas}->{$lemma} = 1;
    }
    close $hdl;
    return 1;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my @nodes = $atree->get_descendants( { ordered => 1 } );
    my @closest_polarities;

    my $closest_pos = -1;
    my $closest_pol = '0';
    my $pos = 0;

    # there
    for my $node ( @nodes ) {
        if ( $self->is_aspect_candidate( $node ) ) {
            $closest_pos = $pos;
            $closest_pol = $self->combine_polarities( $self->get_aspect_candidate_polarities( $node ) );
        } elsif ( $self->is_subjective( $node ) ) {
            $closest_pos = $pos;
            $closest_pol = $self->get_polarity( $node );
        }
        push @closest_polarities, { diff => abs($closest_pos - $pos), pol => $closest_pol };
        $pos++;
    }

    # back
    $closest_pos = scalar @nodes;
    $closest_pol = '0';
    $pos = $#nodes;

    for my $node ( reverse @nodes ) {
        if ( $self->is_aspect_candidate( $node ) ) {
            $closest_pos = $pos;
            $closest_pol = $self->combine_polarities( $self->get_aspect_candidate_polarities( $node ) );
        } elsif ( $self->is_subjective( $node ) ) {
            $closest_pos = $pos;
            $closest_pol = $self->get_polarity( $node );
        }
        my $prevdiff = $closest_polarities[$pos]->{diff};
        if (abs($closest_pos - $pos) < $prevdiff) {
            $closest_polarities[$pos] = { diff => abs($closest_pos - $pos), pol => $closest_pol };
        }
        $pos--;
    }

    $pos = 0;
    for my $node ( @nodes ) {
        if ( ( $self->{forms}->{ lc( $node->form ) } || $self->{lemmas}->{ $node->lemma } )
            && ! $self->is_aspect_candidate( $node ) ) {
            my $polarity = $closest_polarities[$pos]->{pol};
            $self->mark_node( $node, "known$polarity" );
        }

        $pos++;
    }

    return 1;
}

1;
