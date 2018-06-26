package Treex::Block::HamleDT::FA::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToUD;
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    # The conversion to phrases and back should fix various issues such as
    # left-to-right conj or flat:foreign.
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToUD
    (
        'prep_is_head'           => 0,
        'coordination_head_rule' => 'first_conjunct'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
}



1;

=over

=item Treex::Block::HamleDT::FA::FixUD

A block to fix Persian UD. Currently only normalizes coordination, flat etc.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
