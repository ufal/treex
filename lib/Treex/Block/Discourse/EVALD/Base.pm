package Treex::Block::Discourse::EVALD::Base;
use Moose::Role;
use Treex::Core::Common;

use Treex::Tool::Discourse::EVALD::Features;

has 'target' => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'target classification set, three possible values: L1 for native speakers, L2 for second language learners, referat for the referat dataset',
);
has 'ns_filter' => ( is => 'ro', isa => 'Str' );
has '_feat_extractor' => ( is => 'ro', isa => 'Treex::Tool::Discourse::EVALD::Features', builder => '_build_feat_extractor', lazy => 1 );

sub BUILD {
    my ($self) = @_;
    $self->_feat_extractor;
}

sub _build_feat_extractor {
    my ($self) = @_;
    return Treex::Tool::Discourse::EVALD::Features->new({ target => $self->target, language => $self->language, selector => $self->selector, ns_filter => $self->ns_filter });
}

1;

__END__

=head1 NAME

Treex::Block::Discourse::EVALD::Base

=head1 DESCRIPTION

Base class for EVALD resolver.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>
Jiří Mírovský <mirovsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016-17 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
