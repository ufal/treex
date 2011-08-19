package Treex::Block::Read::DGA;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
use XML::Simple;

has bundles_per_doc => (
    is => 'ro',
    isa => 'Int',
    default => 0,
);

has language      => ( isa => 'LangCode', is => 'ro', required => 1 );

has _buffer => (is=>'rw', default=> sub {[]});

sub BUILD {
    my ($self) = @_;
    if ( $self->bundles_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}


sub next_document {
    my ($self) = @_;
	if (!@{$self->_buffer}){
        my $filename = $self->next_filename();
        return if !defined $filename;
        log_info "Loading $filename...";
        my $xml_doc = XMLin($filename, forcearray=>[qw(s tok)]);
        $self->_set_buffer($xml_doc->{s});
    }

    my $document = $self->new_document();
    my $sent_num = 0;
    while (@{$self->_buffer}){
        $sent_num++;
        last if $self->bundles_per_doc && $sent_num > $self->bundles_per_doc;

        my $xml_sentence = shift @{$self->_buffer};
        my $bundle = $document->create_bundle();
        my $zone   = $bundle->create_zone( $self->language, $self->selector );
		my $atree  = $zone->create_atree();
        my $ord    = 1;
        foreach my $xml_tok (@{$xml_sentence->{tok}}){
            $atree->create_child({
                'ord' => $ord++,
                'form' => $xml_tok->{orth},
                'conll/pos' => $xml_tok->{ctag},
                'conll/deprel' => $xml_tok->{syn}{reltype},
            });
        }
        my @anodes = $atree->get_children();
        for my $i (0..$#anodes){
            my $parent_index = $xml_sentence->{tok}[$i]{syn}{head} - 1;
            if (!defined $parent_index || $parent_index < 0 && $parent_index > @anodes){
                log_fatal $self->current_filename . " contains invalid parent index: $parent_index";
            } elsif($parent_index == @anodes) {
                # in DGA, parent_index_of_root = last_assigned_index + 1
            } else {
                $anodes[$i]->set_parent($anodes[$parent_index]);
            }
        }
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::DGA

=head1 DESCRIPTION

Document reader for the XML-based DGA format (Dependency Grammar Annotator)
used for storing Romanian Dependency Treebank.

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 PARAMETERS

=over

=item bundles_per_doc

Maximum number of bundles for each document
(if the source file contains more sentences, several documents will be created).
Zero means unlimited. 

=back

=head1 SEE

L<Treex::Block::Read::BaseReader>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
