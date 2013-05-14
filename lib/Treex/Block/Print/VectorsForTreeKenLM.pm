package Treex::Block::Print::VectorsForTreeKenLM;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my ($t_parent) = $t_node->get_eparents( { or_topological => 1 } ); # use the first effective parent
    my $a_node   = $t_node->get_lex_anode();
    my $a_parent = $t_parent->get_lex_anode();
    my $Lg = getlemma($t_parent);
    my $Pg = !$a_parent || $a_parent->is_root ? '#' : substr( $a_parent->tag, 0, 1 ) // '#';
    my $Fd = $t_node->formeme;
    my $Pd = !$a_node || $a_node->is_root ? '#' : substr( $a_node->tag, 0, 1 ) // '#';
    my $Ld = getlemma($t_node);
    $Fd = 'n:1' if $Fd eq 'drop';
    $Pd = 'P' if $Ld eq '#PersPron';
    say { $self->_file_handle } "Lg=$Lg Pg=$Pg Fd=$Fd Pd=$Pd Ld=$Ld";
    return;
}

sub getlemma {
    my ($tnode) = @_;
    return '_root' if $tnode->is_root;
    my $lemma = lc ($tnode->t_lemma // '_NO');
    $lemma =~ s/\d+/<digit>/g;
    $lemma =~ s/ /&#32;/g;
    return $lemma;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::VectorsForTreeKenLM – print training vectors for TreeLM

=head1 DESCRIPTION

Prints the following information about each node (edge), space-separated, one node (edge) per line:

=over
=item Lg=parent t-lemma
=item Pg=parent PoS tag
=item Fd=formeme
=item Pd=PoS tag
=item Ld=t-lemma
=back 

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
