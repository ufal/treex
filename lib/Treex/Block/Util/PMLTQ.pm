package Treex::Block::Util::PMLTQ;

use Moose;
use Treex::Core::Common;

use Treex::Tool::PMLTQ::Query;
use File::Slurp;

extends 'Treex::Core::Block';

# The PML-TQ query string
has 'query' => ( isa => 'Str', is => 'ro', builder => '_load_query', lazy_build => 1 );

has 'query_file' => ( isa => 'Maybe[Str]', is => 'ro' );

# Print just one address per match
has 'one_per_match' => ( isa => 'Bool', is => 'ro', default => 0 );

# Evaluate code on matched nodes
has 'action' => ( isa => 'Str', is => 'ro', default => '' );


sub _load_query {
    
    my ($self) = @_;
    
    if ( !defined($self->query_file) ){
        log_fatal('One of \'query\' or \'query_file\' must be defined!');
    }

    my $query = read_file( $self->query_file, binmode => ':utf8' );
    $query =~ s/\s+/ /g;    
    return $query;
}


sub process_document {

    my ( $self, $document ) = @_;

    my $evaluator = Treex::Tool::PMLTQ::Query->new( $self->query, { treex_document => $document } );
    my $code;

    if ( $self->action ne '' ){
        $code = $self->one_per_match ? 'my $node = $res->[0]; ' : 'my @nodes = @{$res}; ';
        $code .= $self->action . '; 1;';
    }

    while ( my $res = $evaluator->find_next_match() ) {

        if ( $self->action eq '' ) {
            if ( $self->one_per_match ) {
                print $res->[0]->get_address(), "\n";
            }
            else {
                print join "\t", map { $_->get_address(); } @{$res};
                print "\n";
            }
        }
        else {
            eval($code) or log_fatal "Eval error: $@";
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

The PML-TQ query may be specified either directly on the command line using
the C<query> parameter, or in a text file using the C<query_file> parameter.

This block uses the L<Treex::Tool::PMLTQ::Query> library which is a wrapper around
L<Tree_Query::BtredEvaluator>, which simulates a C<btred> environment.

=head1 PARAMETERS 

=over

=item query

The PML-TQ query.

=item query

A file containing the PML-TQ query.

=item one_per_match

If set to C<1>, print only one node address per match, even if the match spans multiple nodes.
In the default setting (C<0>), multiple nodes from the same match are printed on the same line,
separated with tab characters.

=item action

This may contain Perl code to be executed on matching nodes instead of printing out their addresses. 
The nodes of each match are accessible through the @nodes array. If one_per_match is set, 
the first matching node is accessible through the $node variable.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
