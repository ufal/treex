package Treex::Block::Print::MutualInformation;
use Moose;

use Treex::Core::Common;
use Treex::Block::Print::AttributeArrays;

extends 'Treex::Core::Block';
with 'Treex::Block::Print::Overall';

has '+language' => ( required => 1 );

has 'layer' => ( isa => enum( [ 'a', 't', 'p', 'n' ] ), is => 'ro', required => 1 );

has 'attr_x' => ( isa => 'Str', is => 'ro', required => 1 );
has 'attr_y' => ( isa => 'Str', is => 'ro', required => 1 );

# Helper objects used for getting the attribute values
has '_extract_x' => ( isa => 'Object', is => 'rw', lazy_build => 1 );
has '_extract_y' => ( isa => 'Object', is => 'rw', lazy_build => 1 );

# Counts of both kinds of attributes and their co-occurences
has '_stats_x'  => ( isa => 'HashRef', is => 'rw', default => sub { {} } );
has '_stats_y'  => ( isa => 'HashRef', is => 'rw', default => sub { {} } );
has '_stats_xy' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

# Total count of nodes examined
has '_count' => ( isa => 'Int', is => 'rw', default => 0 );

sub _build__extract_x {

    my ($self) = @_;
    return Treex::Block::Print::AttributeArrays->new( { layer => $self->layer, attributes => $self->attr_x } );
}

sub _build__extract_y {

    my ($self) = @_;
    return Treex::Block::Print::AttributeArrays->new( { layer => $self->layer, attributes => $self->attr_y } );
}

sub process_bundle {

    my ( $self, $bundle ) = @_;
    my $zone = $bundle->get_zone( $self->language, $self->selector );

    log_fatal('Zone does not exist!') if ( !$zone );

    my @vals_x  = @{ $self->_extract_x->process_zone($zone) };
    my @vals_y  = @{ $self->_extract_y->process_zone($zone) };
    my @vals_xy = map { $vals_x[$_] . "\n" . $vals_y[$_] } ( 0 .. $#vals_x );

    # record the statistics for entropy computation
    my ( $stats_x, $stats_y, $stats_xy ) = ( $self->_stats_x, $self->_stats_y, $self->_stats_xy );

    for ( my $i = 0; $i < @vals_x; ++$i ) {

        $stats_x->{ $vals_x[$i] } = 0 if ( !$stats_x->{ $vals_x[$i] } );
        $stats_x->{ $vals_x[$i] }++;
        $stats_y->{ $vals_y[$i] } = 0 if ( !$stats_y->{ $vals_y[$i] } );
        $stats_y->{ $vals_y[$i] }++;
        $stats_xy->{ $vals_xy[$i] } = 0 if ( !$stats_xy->{ $vals_xy[$i] } );
        $stats_xy->{ $vals_xy[$i] }++;
    }
    
    # increase the total count
    $self->_set_count( $self->_count + @vals_x );

    return;
}

sub _reset_stats {

    my ($self) = @_;
    $self->_set_stats_x(  {} );
    $self->_set_stats_y(  {} );
    $self->_set_stats_xy( {} );
    $self->_set_count(0);
}

sub _print_stats {

    my ($self) = @_;
    my $total  = $self->_count;
    my $mi     = 0.0;

    # I(X,Y) = sum_x sum_y p(x,y) log_2 ( p(x,y) / p(x)p(y) )
    foreach my $x ( keys %{ $self->_stats_x } ) {
        foreach my $y ( keys %{ $self->_stats_y } ) {

            my $p_x = $self->_stats_x->{$x} / $total;
            my $p_y = $self->_stats_y->{$y} / $total;

            if ( $self->_stats_xy->{ $x . "\n" . $y } ) {
                my $p_xy = $self->_stats_xy->{ $x . "\n" . $y } / $total;
                $mi += $p_xy * ( log( $p_xy / ( $p_x * $p_y ) ) / log(2) );
            }
        }
    }

    print "Mutual information of " . $self->attr_x . " and " . $self->attr_y;
    printf " = %.4f \n", $mi;

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::Entropy

=head1 DESCRIPTION

This block prints the mutual information of two given attributes (or two groups of attributes) on a document or a 
set of documents.

=head1 PARAMETERS

=over

=item C<layer>

The layer at which this block should be applied, e.g. C<t> or C<a>. This parameter is required.

=item C<attr_x>

The first attribute or group of attributes whose values should be examined for mutual information. This parameter is required.

=item C<attr_y>

The second attribute or group of attributes whose values should be examined for mutual information. This parameter is required.

=item C<overall>

If this is set to 1, an overall score for all the processed documents is printed instead of a score for each single
document.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
