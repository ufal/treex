package Treex::Block::Align::T::Supervised::Base;

use Moose::Role;

use Treex::Tool::ML::Ranker::Features;
use Treex::Tool::Align::Features;

has '_feat_extractor' => (is => 'ro', isa => 'Treex::Tool::ML::Ranker::Features', builder => '_build_feat_extractor');

sub _build_feat_extractor {
    my ($self) = @_;
    return Treex::Tool::Align::Features->new();
}

sub _get_candidates {
    my ($self, $tnode, $align_lang) = @_;
    my $aligned_ttree = $tnode->get_bundle->get_zone($align_lang, $self->selector)->get_ttree();
    my @candidates = $aligned_ttree->get_descendants({ordered => 1});
    
    # add the src node itself as a candidate -> it means no alignment
    unshift @candidates, $tnode;
    
    return @candidates;
}

1;

__END__

=head1 NAME

Treex::Block::Align::T::Supervised::Base

=head1 DESCRIPTION

This role shares the aspects of supervised alignment resolver shared by the Resolver class
and the PrintData class: feature selection, and candidate selection.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
