package Treex::Block::Coref::Write::SentencesWithMentions;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( required => 1 );

has '+extension' => ( default => '.txt' );


sub process_atree {
    my ( $self, $atree ) = @_;

    my @sent = ();
    foreach my $anode ($atree->get_descendants({ordered => 1})) {
        my $form = $anode->form;
        if (defined $anode->wild->{coref_mention_start}) {
            my @starts = @{$anode->wild->{coref_mention_start}};
            my $prefix = "";
            foreach my $start (@starts) {
                $prefix .= "[".$start;
            }
            $prefix .= "_";
            $form = $prefix . $form;
        }
        if (defined $anode->wild->{coref_mention_end}) {
            my @ends = @{$anode->wild->{coref_mention_end}};
            my $suffix = "_";
            foreach my $end (@ends) {
                $suffix .= $end."]";
            }
            $form .= $suffix;
        }
        push @sent, $form;
    }
    print {$self->_file_handle} join " ", @sent;
    print {$self->_file_handle} "\n";
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Write::SentencesWithMentions

=head1 DESCRIPTION

Document writer for plain text format, one sentence
(L<bundle|Treex::Core::Bundle>) per line with coreference mentions annotated.


=head1 ATTRIBUTES

=over

=item to

The name of the output file, STDOUT by default.

=back

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
