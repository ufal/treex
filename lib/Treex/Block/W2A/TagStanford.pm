package Treex::Block::W2A::TagStanford;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Tagger::Stanford;

has '+language' => ( required => 1 );

has 'model' => ( is => 'ro', isa => 'Str', required => 1 );

has '_tagger' => ( is => 'ro', isa => 'Treex::Tool::Tagger::Stanford', writer => '_set_tagger' );

sub BUILD {
    my ($self) = @_;
    $self->_set_tagger( Treex::Tool::Tagger::Stanford->new( { model => $self->model } ) );
}

sub process_atree {

    my ( $self, $atree ) = @_;
    my @anodes = $atree->get_descendants( { ordered => 1 } );
    my @forms = map { $_->form } @anodes;

    # get tags
    my @tags = $self->_tagger->tag_sentence( @forms );

    if ( scalar @tags != scalar @forms ) {
        log_fatal("Different number of tokens and tags. TOKENS: @forms, TAGS: @tags");
    }

    # fill tags
    foreach my $anode (@anodes) {
        $anode->set_tag( shift @tags );
    }

    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TagStanford

=head1 DESCRIPTION

This block loads L<Treex::Tool::Tagger::Stanford> (a wrapper for the Stanford tagger) with 
the given C<model>,  feeds it with all the input tokenized sentences, and fills the C<tag> 
parameter of all a-nodes with the tagger output. 

=head1 PARAMETERS

=over

=item C<model>

The path to the tagger model within the shared directory. This parameter is required.

=back

=head1 SEE ALSO

L<Treex::Block::W2A::EN::TagStanford>, L<Treex::Block::W2A::DE::TagStanford>

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
