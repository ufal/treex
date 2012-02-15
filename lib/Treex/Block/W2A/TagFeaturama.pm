package Treex::Block::W2A::TagFeaturama;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'lemmatize' => ( is => 'ro', isa => 'Bool', default => 0 );

has '+language' => ( required => 1 );

has '_tagger' => (
    is            => 'ro',
    isa           => 'Treex::Tool::Tagger::Featurama',
    builder       => '_build_tagger',
    lazy          => 1,
    init_arg      => undef,
    predicate     => '_tagger_built',
    documentation => q{Tagger object},
);


sub _build_tagger {

    my $self   = shift;
    my $tagger_package = 'Treex::Tool::Tagger::Featurama::' . uc( $self->language );
    ( my $file = $tagger_package ) =~ s|::|/|g;
    require $file . '.pm';

    my $tagger = $tagger_package->new();
    return $tagger;
}

sub process_atree {
    
    my ( $self, $atree ) = @_;
    my @anodes = $atree->get_descendants();
    my @forms = map { $_->form } @anodes;

    # get tags and lemmas
    my ($tags_rf, $lemmas_rf) = $self->_tagger->tag_sentence( \@forms );
    if ( scalar @{$tags_rf} != scalar @forms ) {
        log_fatal("Different number of tokens and tags. TOKENS: @forms, TAGS: @{$tags_rf}");
    }

    # fill tags
    foreach my $anode (@anodes) {
        $anode->set_tag( shift @{$tags_rf} );
    }
    
    # fill lemmas, if required to
    if ( $self->lemmatize ){
        foreach my $anode (@anodes) {
            $anode->set_lemma( shift @{$lemmas_rf} );
        }
    }

    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TagFeaturama

=head1 DESCRIPTION

Each node in the analytical tree is tagged using the L<Treex::Tool::Tagger::Featurama|Featurama> tagger trained 
for the current language. Lemmatization is performed as well if the C<lemmatize> parameter is set and the
tagger model for the current language supports it. 

Currently, L<Treex::Tool::Tagger::Featurama::CS|Czech> (including lemmatization) and 
L<Treex::Tool::Tagger::Featurama::CS|English> (tagging only) are supported.

=head1 PARAMETERS

=over

=item C<lemmatize>

If this parameter is set to C<1>, the lemmas provided by the Featurama tagger are assigned to the nodes in the 
a-tree (lemmatization may not be supported by the trained tagger model; in such case, setting this parameter has no
effect). 

Default value: C<0>.

=back

=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
