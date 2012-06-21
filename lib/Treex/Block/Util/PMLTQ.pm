package Treex::Block::Util::PMLTQ;
use Moose;
use Treex::Core::Common;

use Treex::Tool::PMLTQ::Query;

extends 'Treex::Core::Block';

# The PML-TQ query string
has 'query' => ( isa => 'Str', is => 'ro', required => 1 );

# Print just one address per match
has 'one_per_match' => ( isa => 'Bool', is => 'ro', default => 0 );

sub process_document {

    my ( $self, $document ) = @_;

    my $evaluator = Treex::Tool::PMLTQ::Query->new( $self->query, { treex_document => $document } );
    
    while ( my $res = $evaluator->find_next_match() ) {

        if ( $self->one_per_match ){
            print $res->[0]->get_address(), "\n";
        }
        else {
            print join "\t", map { $_->get_address(); } @{$res};
            print "\n";
        }
    }
}

1;

__END__

=head1 NAME

Treex::Block::Util::PMLTQ

=head1 SYNOPSIS

    # Display all nodes matching a PML-TQ query in ttred
    treex Read::Treex from=file.treex.gz \
        Util::PMLTQ query='t-node [ t_lemma = "být" ];' | ttred -l -

=head1 DESCRIPTION

Executes a PML-TQ query on the processed files and prints the addresses of all nodes found
(one match per line, tab-separated if more nodes belong to the same match and C<one_per_match>
is turned off).

This block uses the L<Treex::Tool::PMLTQ::Query> library which is a wrapper around
L<Tree_Query::BtredEvaluator>, which simulates a C<btred> environment.

=head1 PARAMETERS 

=over

=item query

The PML-TQ query. This parameter is required.

=item one_per_match

If set to C<1>, print only one node address per match, even if the match spans multiple nodes.
In the default setting (C<0>), multiple nodes from the same match are printed on the same line,
separated with tab characters.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
