package Treex::Block::Filter::SentenceNumber;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'nums' => ( isa => 'Str', is => 'ro', required => 1 );

has 'invert' => ( isa => 'Bool', is => 'ro', default => 0 );

# Hash of sentence numbers to be retained (or deleted, depending on the 'invert' setting
has '_nums_hash' => ( isa => 'HashRef', is => 'rw', lazy_build => 1, builder => '_build_nums_hash' );


sub process_document {
    
    my ( $self, $document ) = @_;
    
    my @bundles = $document->get_bundles();
    
    for (my $i = 0; $i < @bundles; ++$i){
        if ( !( ($self->_nums_hash->{$i} // 0) ^ $self->invert )){
            $bundles[$i]->remove;
        }
    }
    return 1;
}


sub _build_nums_hash {
    
    my ( $self ) = @_;
    
    # split and convert to 0-base
    my @nums = split /[,\s]+/, $self->nums;
    my %hash = ();
    foreach my $num (@nums){
        if ($num =~ /^([0-9]*)-([0-9]+)$/){
            my ($from, $to) = ($1, $2);
            if ($from > $to){
                log_fatal("Invalid number range $num.");
            } 
            for (my $i = $from; $i <= $to; ++$i){
                $hash{$i - 1} = 1;
            }
        }
        elsif ($num =~ /^[0-9]+/) {
            $hash{$num - 1} = 1;
        }
        else {
            log_fatal("Invalid number format $num.");
        }
    }
    return \%hash;  
}


1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::Filter::SentenceNumber

=head1 SYNOPSIS

 # Leave only first three bundles and the fifth one in the document
 Filter::SentenceNumber nums=1-3,5
  
 # Delete the first and the third bundle
 Filter::SentenceNumber nums=1,3 invert=1
 
=head1 DESCRIPTION

Filters out only specified sentences (useful for creating example files and similar).

=head1 ATTRIBUTES

=over

=item C<nums>

Comma-separated list of sentence numbers (starting from 1) which should be retained by the filter.


=item C<invert>

Inverts matching sense of C<nums>, i.e. if set to 1, all sentences listed in C<nums> are removed.

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
