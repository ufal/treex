package Treex::Block::Misc::FindSentences;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'file'     => ( is => 'ro',  ); # file name
has '_sentences'     => ( is => 'rw', isa => 'HashRef', default  => sub {return {}} );

sub BUILD {
    my ($self) = @_;
    open my $SENTENCES, "<:utf8",$self->file or log_fatal($!);
    while (<$SENTENCES>) {
        chomp;
        $self->_sentences->{$_} = 1;
    }

    log_info("Number of searched sentences: ".scalar(keys %{$self->_sentences}));

}


sub process_zone {
    my ( $self, $zone ) = @_;

    if ($self->_sentences->{$zone->sentence}) {
        print "XXXX: ".$zone->get_atree->get_address."\n";
    }
    else {
        print "This sentence is not on the list: ".$zone->sentence."\n";
    }
}

1;

=head1 NAME

Treex::Block::Misc::FindSentences;

=head1 DESCRIPTION

Print addresses of a-trees which contain a sentence from the given file.

=head1 AUTHOR

Zdenek Zabokrtsky

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
