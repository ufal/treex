package Treex::Block::Write::ParallelSentences;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has 'lang_sep' => ( isa => 'Str', is => 'ro', default => "\t" );

has 'sent_sep' => ( isa => 'Str', is => 'ro', default => "\n" );

has 'language2' => ( isa => 'Str', is => 'ro', lazy_build => 1 );

has 'selector2' => ( isa => 'Str', is => 'ro', default => '' );

sub _build_language2 {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->language2 && $self->selector eq $self->selector2 ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}


sub process_atree {
    my ( $self, $atree ) = @_;
    my $atree2 = $atree->get_bundle()->get_zone( $self->language2, $self->selector2 )->get_atree();

    my $tokens = join( ' ', map { $_->form } $atree->get_descendants( { ordered => 1 } ) );
    my $tokens2 = join( ' ', map { $_->form } $atree2->get_descendants( { ordered => 1 } ) );

    print { $self->_file_handle } $tokens, $self->lang_sep, $tokens2, $self->sent_sep;
}

1;

__END__

=head1 NAME

Treex::Block::Write::ParallelSentences

=head1 DESCRIPTION

Print tokenized parallel sentences (from two zones).

=head1 ATTRIBUTES

=over

=item language2 

Language of the 2nd zone.

=item selector2

Selector of the 2nd zone.

=item lang_sep

String to separate the sentences in two zones, defaults to tab.

=item sent_sep

String to separate different sentences, defaults to newline. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
