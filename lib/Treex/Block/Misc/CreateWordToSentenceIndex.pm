package Treex::Block::Misc::CreateWordToSentenceIndex;
use Moose;
use Treex::Core::Common;
use utf8;
use Data::Dumper;
extends 'Treex::Core::Block';

has tag_regex => ( is => 'rw', isa => 'Str', default => '^[NV]' );

has _index => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

my $SENT_MIN_LEN = 10;
my $SENT_MAX_LEN = 200;
my $WORD_MIN_LEN = 3;
my $WORD_MAX_LEN = 20;
my $WORD_MIN_COUNT = 10;
my $WORD_MAX_COUNT = 300;

override 'process_start' => sub {
    my ($self) = @_;
    super();

    $self->_index->{'sentences'} = [];
    $self->_index->{'lemma2sentid'} = {};

    return ;
};

sub process_zone {
    my ($self, $zone) = @_;

    my $sentid = scalar(@{$self->_index->{sentences}});
    push @{$self->_index->{sentences}}, $zone;

    my @nodes = grep { $_->tag =~ /$self->tag_regex/ } $zone->get_atree()->get_descendants();

    foreach my $node (@nodes) {
        # if ( length($node->lemma) < $WORD_MIN_LEN || length($node->lemma) > $WORD_MAX_LEN) { 
        # next;
        # }

        if ( !defined $self->_index->{'lemma2sentid'}->{$node->lemma}) {
           $self->_index->{'lemma2sentid'}->{$node->lemma} = [];
        }
        push @{$self->_index->{'lemma2sentid'}->{$node->lemma}}, $sentid;
    }

    return ;
}

override 'process_end' => sub {
    my ($self) = @_;
    super();

    foreach my $lemma (keys %{$self->_index->{'lemma2sentid'}} ) {
        if ( @{$self->_index->{'lemma2sentid'}->{$lemma}} < $WORD_MIN_COUNT ||
             @{$self->_index->{'lemma2sentid'}->{$lemma}} > $WORD_MAX_COUNT
        ) {
            delete $self->_index->{'lemma2sentid'}->{$lemma};
        }
    }

    print Dumper($self->_index);

    return ;
};

1;

=head1 NAME 

Treex::Block::Misc::CreateWordToSentenceIndex -- compute a mapping from word lemmas to sentences.

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

