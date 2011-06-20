package Treex::Block::Read::Syntagrus;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();

    my @parents;
    my @nodes;
    my $aroot;

    foreach my $line ( split /\n/, $text ) {
        # what to do with generated nodes
        # so far, they have their surface form '#Fantom'
        $line =~ s/(<W[^>]+)\/>/$1>#Fantom<\/W>/;
        if ($line =~ /^<S\s.*>/) {
            my $bundle = $document->create_bundle();
            my $zone = $bundle->create_zone( $self->language, $self->selector );
            $aroot = $zone->create_atree();
            @parents = (0);
            @nodes = ($aroot);
        }
        elsif ($line =~ /<\/S>/) {
            foreach my $i (1 .. $#nodes) {
                $nodes[$i]->set_parent($nodes[$parents[$i]]);
            }
        }
        elsif ($line =~ /^(.*)<W\s(.+)>(.+)<\/W>(.*)$/) {
            my $punct_before = $1;
            my $punct_after = $4;
            my $word_form = $3;
            my %attr;
            map {m/(.+)=\"(.+)\"/; $attr{$1} = $2;} split(/\s/, $2);
            my $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($word_form);
            $newnode->set_lemma($attr{'LEMMA'});
            $newnode->set_tag($attr{'FEAT'});
            $newnode->set_conll_deprel($attr{'LINK'});
            $attr{'DOM'} = 0 if $attr{'DOM'} eq '_root';
            push @parents, $attr{'DOM'};
            push @nodes, $newnode;
        }
    }
    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::Syntagrus

=head1 DESCRIPTION

Document reader for SynTagRus dependency treebank.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

David Mareček

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
