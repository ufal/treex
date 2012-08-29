package Treex::Block::Print::Overall;
use Moose::Role;
use Treex::Core::Log;
use Storable qw(store retrieve);
use Scalar::Util qw(looks_like_number);

has 'overall' => ( is => 'ro', isa => 'Bool', default => 0 );

has 'dump_to_file' => ( is => 'ro', isa => 'Maybe[Str]' );

requires '_reset_stats';
requires '_print_stats';
requires 'process_bundle';
# TODO rozchodit BLEU -- requires '_dump_stats';
#requires '_merge_stats';

# Prints the whole statistics at the end of the process
sub process_end {

    my ($self) = @_;
    if ( $self->overall && !$self->dump_to_file ) {
        $self->_print_stats();
    }
    return;
}

override '_do_process_document' => sub {

    my ( $self, $document ) = @_;

    if ( !$self->overall ) {
        $self->_reset_stats();
    }

    foreach my $bundle ( $document->get_bundles() ) {
        $self->process_bundle($bundle);
    }

    if ( defined( $self->dump_to_file ) ) {
        store( $self->_dump_stats(), $self->dump_to_file . $document->file_stem . $document->file_number . '.pls' );
    }
    elsif ( !$self->overall ) {
        $self->_print_stats();
    }

    return;
};

sub load_and_print {
    
    my $self = shift;
    $self->_reset_stats();  
   
    foreach my $file (@_){
        $self->_merge_stats( retrieve($file) );        
    }
    
    $self->_print_stats();
}

sub merge_hashes {
    my ( $h1, $h2 ) = @_;

    foreach my $key ( keys %{$h2} ) {
        if ( exists( $h1->{$key} ) ) {
            if ( ref( $h1->{$key} ) eq 'HASH' ) {
                merge_hashes( $h1->{$key}, $h2->{$key} );
            }
            elsif ( ref( $h1->{$key} ) eq 'ARRAY' ) {
                push @{ $h1->{$key} }, @{ $h2->{$key} };
            }
            elsif ( looks_like_number( $h1->{$key} ) ) {
                $h1->{$key} += $h2->{$key};
            }
            else {
                $h1->{$key} .= $h2->{$key};
            }
        }
        else {
            $h1->{$key} = $h2->{$key};
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Print::Overall

=head1 DESCRIPTION

A Moose role for blocks that are able to print some results either for each single document
or overall for all documents processed.

=head1 ATTRIBUTES

=over

=item C<overall>

If this is set to 1, an overall statistics for all the processed documents is printed instead of a score for each single
document.

=item C<dump_to_file>

Set this variable to a file name prefix if you wish a statistics hash to be dumped into a .pls file for each processed 
document.

This is useful in parallel processing; the dumped hashes may be later retrieved and examined using the C<merge_hashes> 
method. 

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
