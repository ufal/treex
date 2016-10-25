package Treex::Block::Coref::EntityEvent::CS::DemonPron::Base;
use Moose::Role;
use Treex::Core::Common;

use Treex::Tool::Coreference::AnteCandsGetter;
use Treex::Tool::Coreference::Features::CS::AllMonolingual;

with 'Treex::Block::Coref::SupervisedBase' => {
    -excludes => [ '_build_feature_extractor', '_build_ante_cands_selector' ],
};

has 'aligned_feats' => ( is => 'ro', isa => 'Bool', default => 0 );

sub _build_node_types {
    return 'demonpron';
}
sub _build_special_classes {
    return [ "c^__OTHER__" ];
}

sub _build_feature_extractor {
    my ($self) = @_;
    my $cs_fe = Treex::Tool::Coreference::Features::CS::AllMonolingual->new();
    return $cs_fe;
}

sub _build_ante_cands_selector {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::AnteCandsGetter->new({
        cand_types => [ 'noun', 'verb', 'coord' ],
        prev_sents_num => 1,
        preceding_only => 1,
        cands_within_czeng_blocks => 1,
        max_size => 100,
    });
    return $acs;
}

1;

#TODO extend documentation

__END__

=head1 NAME

Treex::Block::Coref::CS::DemonPron::Base

=head1 DESCRIPTION

This role is a basis for supervised coreference resolution of Czech demonstrative  pronouns.
Both the data printer and resolver should apply this role.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
