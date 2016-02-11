package Treex::Block::Coref::SupervisedBase;
use Moose::Role;
use Treex::Core::Common;

use Treex::Tool::Coreference::CorefFeatures;
use Treex::Tool::Coreference::AnteCandsGetter;

with 'Treex::Block::Filter::Node';

has 'anaphor_as_candidate' => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 1,
    documentation => 'joint anaphoricity determination and antecedent selection',
);

has '_feature_extractor' => (
    is          => 'ro',
    required    => 1,
    lazy        => 1,
    isa         => 'Treex::Tool::Coreference::CorefFeatures',
    builder     => '_build_feature_extractor',
);
has '_ante_cands_selector' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::AnteCandsGetter',
    lazy        => 1,
    builder     => '_build_ante_cands_selector',
);

sub _build_node_types {
    my ($self) = @_;
    log_fatal "method _build_node_types must be overriden in " . ref($self);
}
sub _build_feature_extractor {
    my ($self) = @_;
    log_fatal "method _build_feature_extractor must be overriden in " . ref($self);
}
sub _build_ante_cands_selector {
    my ($self) = @_;
    log_fatal "method _build_ante_cands_selector must be overriden in " . ref($self);
}

1;
#TODO extend documentation

__END__

=head1 NAME

Treex::Block::Coref::SupervisedBase

=head1 DESCRIPTION

This role is a basis for supervised coreference resolution.
Both the data printer and resolver should apply this role.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
