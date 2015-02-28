package Treex::Block::A2T::ProjectGazeteerInfo;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

use List::MoreUtils qw/none all/;

extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;

    my $alex = $tnode->get_lex_anode();
    return if (!defined $alex);

    return if (!defined $alex->wild->{gazeteer_entity_id});

    $tnode->wild->{gazeteer_entity_id} = $alex->wild->{gazeteer_entity_id};
    $tnode->wild->{matched_item} = $alex->wild->{matched_item};
    my $new_tlemma = join " ", @{$alex->wild->{matched_item}};
    $new_tlemma =~ s/\s+/_/g;
    $tnode->set_t_lemma($new_tlemma);
}



1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::Block::A2T::ProjectGazeteerInfo

=head1 DESCRIPTION

Project the information on gazeteer matches onto the t-layer.


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
