package Treex::Block::T2T::EN2CS::MoveNounAttrAfterNouns;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ($self, $tnode) = @_;

    if (is_noun_attr($tnode)
        && (($tnode->get_parent->formeme || "") =~ /^n/)
        && $tnode->precedes($tnode->get_parent)
        && !$tnode->get_children
        && !$tnode->get_siblings
       ) 
    {
        $tnode->shift_after_node($tnode->get_parent);
    }
}

sub is_noun_attr {
    my ($tnode) = @_;
    return (defined $tnode->wild->{gazeteer_entity_id}) && (($tnode->formeme || "") eq "n:1");
}


1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::Block::T2T::EN2CS::MoveNounAttrAfterNouns

=head1 DESCRIPTION


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
