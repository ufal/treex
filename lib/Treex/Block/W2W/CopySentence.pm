package Treex::Block::W2W::CopySentence;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', lazy_build => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );

sub _build_source_selector {
    my ($self) = @_;
    return $self->selector;
}

sub _build_source_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->source_language && $self->selector eq $self->source_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}

sub process_document {

    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {

        my $source_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
        my $target_zone = $bundle->get_or_create_zone( $self->language, $self->selector );

        $target_zone->set_sentence( $source_zone->sentence() );
    }

}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2W::CopySentence

=head1 DESCRIPTION

This simply copies the plain text sentence from one zone (identified by a language and a selector)
to another. 

=head1 PARAMETERS

=over

=item C<language>

The current language. This parameter is required.

=item C<source_language>

The source language from which the sentences should be copied. Defaults to current C<language> setting. 
The C<source_language> and C<source_selector> must differ from C<language> and C<selector>.

=item C<source_selector>

The source selector from which the sentences should be copied. Defaults to current C<selector> setting.
The C<source_language> and C<source_selector> must differ from C<language> and C<selector>.

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
