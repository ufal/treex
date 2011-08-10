package Treex::Block::W2A::EN::TagLinguaEn;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Lingua::EN::Tagger;
has _tagger => (
    is            => 'ro',
    isa           => 'Lingua::EN::Tagger',
    builder       => '_build_tagger',
    lazy          => 1,
    init_arg      => undef,
    predicate     => '_tagger_builded',
    documentation => q{Tagger object},
);

sub _build_tagger {
    my $self   = shift;
    my $tagger = Lingua::EN::Tagger->new();
    return $tagger;
}

sub process_atree {
    my ( $self, $atree ) = @_;
    my @descendants = $atree->get_descendants();
    my @forms = map { $_->form } @descendants;

    # get tags
    my $joined = join ' ', @forms;
    my $tagged = $self->_tagger->add_tags($joined);
    my @tags   = split m{\s}, $tagged;
    if ( scalar @tags != scalar @forms ) {
        log_fatal("Different number of tokens and tags. TOKENS: @forms, TAGS: @tags");
    }

    # fill tags
    foreach my $a_node (@descendants) {
        $a_node->set_tag( shift @tags );
    }

    return 1;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::TagLinguaEn

=head1 VERSION

=head1 DESCRIPTION

Each node in analytical tree is tagged using C<Lingua::EN::Tagger> (Penn Treebank POS tags).
This block does NOT do lemmatization.

=head1 AUTHORS

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


