package Treex::Block::Write::LemmatizedBitexts;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has to_language => ( is => 'ro', isa => 'Str', required => 1 );
has to_selector => ( is => 'ro', isa => 'Str', default  => '' );

has max_tokens => ( is => 'ro', isa => 'Int', default => 0 );

sub nodes_as_lemma_seq {
    my (@nodes) = @_;
    return join(
        " ",
        map { my $l = $_->lemma; $l =~ s/\s/_/g; $l; }
            @nodes
        );
}

sub process_atree {
    my ( $self, $a_root ) = @_;
    my $bundle = $a_root->get_bundle;

    my @l1_nodes = $a_root->get_descendants( { ordered => 1 } );
    my @l2_nodes = $bundle->get_tree( $self->to_language, 'a', $self->to_selector )->get_descendants( { ordered => 1 } );

    if ( $self->max_tokens > 0 && ( scalar(@l1_nodes) > $self->max_tokens || scalar(@l2_nodes) > $self->max_tokens ) ) {
        log_warn sprintf "No lemmatized output produced for '%s' due to maximum tokens number (%d) exceeded: %s=%d, %s=%d",
            $a_root->get_address,
            $self->max_tokens,
            $self->language,
            scalar(@l1_nodes),
            $self->to_language,
            scalar(@l2_nodes);
        return;
    }

    print { $self->_file_handle } $bundle->get_document->loaded_from . "-" . $bundle->id . "\t";
    print { $self->_file_handle } nodes_as_lemma_seq(@l1_nodes) . "\t";
    print { $self->_file_handle } nodes_as_lemma_seq(@l2_nodes) . "\n";
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LemmatizedBitexts

=head1 DESCRIPTION

Writer for a tab-separated format containing sentence id, source language sentence (lemmas), and target language
sentence (lemmas) for GIZA++ alignment.

=head1 PARAMETERS

=over 

=item C<encoding>

The output encoding, C<utf8> by default.

=item C<language>

The first sentence language.

=item C<selector>

The first sentence selector.

=item C<to_language>

The second sentence language.

=item C<to_selector>

The second sentence selector.

=item C<max_tokens>

Do not print sentences that exceed the maximum number of tokens per sentence.
This is tested on both sides of the bitext.
It should prevent GIZA++ from crashing due to too long sentences.

=back

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012,2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
