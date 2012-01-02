package Treex::Block::Print::Entropy;
use Moose;

use Treex::Core::Common;
use Treex::Block::Print::AttributeArrays;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Print::Overall';

has '+language' => ( required => 1 );

has 'layer' => ( isa => enum( [ 'a', 't', 'p', 'n' ] ), is => 'ro', required => 1 );

has 'skip_empty' => ( isa => 'Bool', is => 'ro', default => 0 );

has 'attributes' => ( isa => 'Str', is => 'ro', required => 1 );
has 'conditions' => ( isa => 'Str', is => 'ro' );

# Helper objects used for getting the attribute values
has '_extract_attributes' => ( isa => 'Object',        is => 'rw', lazy_build => 1 );
has '_extract_conditions' => ( isa => 'Maybe[Object]', is => 'rw', lazy_build => 1 );

# Counts of conditioned values and the target values
has '_stats' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

# Total count of nodes examined
has '_count' => ( isa => 'Int', is => 'rw', default => 0 );

sub _build__extract_attributes {

    my ($self) = @_;
    return Treex::Block::Print::AttributeArrays->new( { layer => $self->layer, attributes => $self->attributes } );
}

sub _build__extract_conditions {

    my ($self) = @_;
    return if ( !$self->conditions );
    return Treex::Block::Print::AttributeArrays->new( { layer => $self->layer, attributes => $self->conditions } );
}

sub process_bundle {

    my ( $self, $bundle ) = @_;
    my $zone = $bundle->get_zone( $self->language, $self->selector );

    log_fatal('Zone does not exist!') if ( !$zone );

    my @attr_vals = @{ $self->_extract_attributes->process_zone($zone) };
    my @cond_vals;

    if ( $self->conditions ) {
        @cond_vals = @{ $self->_extract_conditions->process_zone($zone) };
    }
    else {
        @cond_vals = map {''} @attr_vals;
    }

    # record the statistics for entropy computation
    my $stats = $self->_stats;
    my $count = 0;

    for ( my $i = 0; $i < @attr_vals; ++$i ) {

        next
            if (
            $self->skip_empty && (
                !defined( $attr_vals[$i] )
                || $attr_vals[$i] eq ''
                || ( $self->conditions && ( !defined( $cond_vals[$i] ) || $cond_vals[$i] eq '' ) )
            )
            );

        $stats->{ $cond_vals[$i] } = {} if ( !defined( $stats->{ $cond_vals[$i] } ) );
        $stats->{ $cond_vals[$i] }->{ $attr_vals[$i] } = 0 if ( !$stats->{ $cond_vals[$i] }->{ $attr_vals[$i] } );
        $stats->{ $cond_vals[$i] }->{ $attr_vals[$i] }++;
        $count++;
    }

    # increase the total count
    $self->_set_count( $self->_count + $count );

    return;
}

sub _reset_stats {

    my ($self) = @_;
    $self->_set_stats( {} );
    $self->_set_count(0);
}

sub _print_stats {

    my ($self)  = @_;
    my $total   = $self->_count;
    my $entropy = 0.0;

    # H(Y|X) = sum_x,y  p(x,y) * log_2( p(y|x) )
    while ( my ( $condition, $attributes ) = each %{ $self->_stats } ) {

        my $cond_total = 0;
        map { $cond_total += $attributes->{$_} } keys %{$attributes};

        while ( my ( $attribute, $count ) = each %{$attributes} ) {

            # p(x,y) * log_2( p(y|x) )
            $entropy -= ( $count / $total ) * ( log( $count / $cond_total ) / log(2) );
        }
    }

    print "Entropy of " . $self->attributes;
    print " conditioned on " . $self->conditions if ( $self->conditions );
    printf " = %.4f (Perplexity = %.4f)\n", $entropy, 2**$entropy;

    return;
}

sub _dump_stats {
    my ($self) = @_;
    return { 'count' => $self->_count, 'stats' => $self->_stats };
}

sub _merge_stats {
    my ( $self, $stats ) = @_;

    $self->_set_count( $self->_count + $stats->{count} );
    merge_hashes( $self->_stats, $stats->{stats} );
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::Entropy

=head1 DESCRIPTION

Prints the entropy of the given attribute(s) or the conditional entropy, if some other attributes are already known.

=head1 PARAMETERS

=over

=item C<layer>

The layer at which this block should be applied, e.g. C<t> or C<a>. This parameter is required.

=item C<attributes>

The attributes whose values should be examined for entropy. This parameter is required.

=item C<conditions>

The attributes whose values are to be taken as known for the conditional entropy (leave blank for non-conditional
entropy).

=item C<overall>

If this is set to 1, an overall score for all the processed documents is printed instead of a score for each single
document.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
