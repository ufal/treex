package Treex::Tool::Clustering::GoogleNGrams;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::Storage::Storable';

has '_model' => (
    is => 'ro',
    isa => 'HashRef[HashRef[Num]]',
    writer => '_set_model',
);

sub clusters_for_phrase {
    my ($self, $phrase) = @_;
    my $clusters = $self->_model->{$phrase};
    if (!defined $clusters) {
        return {};
    }
    return $clusters;
}

######################### IO methods #########################

sub load_from_table {
    my ($self, $filename) = @_;

    my $clusters_hash = {};

    open DATA, "<:gzip:encoding(UTF-8)", $filename;
    while (<DATA>) {
        chomp $_;
        my ($word, %clusters) = split /\t/, $_;
        $clusters_hash->{$word} = \%clusters;
    }
    $self->_set_model( $clusters_hash );
}

sub thaw {
    my ($self, $buffer) = @_;
    $self->_set_model( $buffer );
}

sub freeze {
    my ($self) = @_;
    return $self->_model;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Clustering::GoogleNGrams

=head1 DESCRIPTION

Accessor to Google NGrams clusters (http://old-site.clsp.jhu.edu/~sbergsma/PhrasalClusters).

=head1 METHODS

=over

=item clusters_for_phrase

Returns 20 clusters for a given phrase accompanied with a weight for each cluster.

=item load_from_table

Load clusters from a list in the original format described here http://old-site.clsp.jhu.edu/~sbergsma/PhrasalClusters.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
