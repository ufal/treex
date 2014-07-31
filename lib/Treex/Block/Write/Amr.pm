package Treex::Block::Write::Amr;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.amr' );

has '+language' => (
    isa => 'Maybe[Str]'
);

has '+selector' => (
    isa => 'Maybe[Str]'
);

sub process_ttree {
    my ( $self, $ttree ) = @_;
    print { $self->_file_handle } "# ::id " . $ttree->get_document()->file_stem . '.' . $ttree->id . "\n";
    print { $self->_file_handle } "# ::snt " . ( $ttree->get_zone()->sentence // '' ) . "\n";

    # determine top AMR node
    # (only child of the tech. root / tech. root in case of more root children)
    my @ttop_children = $ttree->get_children();
    return if ( !@ttop_children );    # skip empty t-trees (TODO handle them somehow?)
    my $tamr_top = @ttop_children > 1 ? $ttree : $ttop_children[0];

    $self->_print_ttree($tamr_top);
}

# Prints one AMR-like tree (given its top t-node, which is either a technical root
# if it has more children, or the only child of the technical root)
sub _print_ttree {
    my ( $self, $tamr_top ) = @_;

    # print the AMR graph
    my $tamr_top_lemma = ( $tamr_top->t_lemma // 'a99/and' );    # add fake lemma 'and' to tech. root
    $tamr_top_lemma =~ s/\// \/ /;
    print { $self->_file_handle } '(', $tamr_top_lemma;
    foreach my $child ( $tamr_top->get_children( { ordered => 1 } ) ) {
        $self->_process_tnode( $child, '    ' );
    }
    print { $self->_file_handle } ")\n\n";                       # separate with two newlines
}

# Prints one AMR-like node.
sub _process_tnode {
    my $formeme_separator = '_#*&&*#_';
    my $partofspeech_separator = '_#(^^)#_';
    my ( $self, $tnode, $indent ) = @_;
    my $lemma = $self->_get_lemma($tnode);
    if ($lemma) {
        $lemma =~ s/\// \/ /;
        print { $self->_file_handle } "\n" . $indent;
        my $modifier = $tnode->wild->{'modifier'} || $tnode->functor || 'no-modifier';
        if ($modifier ne "root" && $indent ne "" ) {
            print { $self->_file_handle } ':' . $modifier;
        }
        print { $self->_file_handle } ( $lemma =~ /\// ? " (" : " " ), $lemma;
    }
    foreach my $child ( $tnode->get_children( { ordered => 1 } ) ) {
        $self->_process_tnode( $child, $indent . '    ' );
    }
    print { $self->_file_handle } ( $lemma =~ /\// ? ")" : "" );
}

# Returns the t-node's lemma/label
sub _get_lemma {
    my ( $self, $tnode ) = @_;
    return $tnode->t_lemma;
}


1;

__END__

=head1 NAME

Treex::Block::Write::Amr

=head1 DESCRIPTION

Document writer for amr-like format.

=head1 ATTRIBUTES

=over

=item language

Language of tree


=item selector

Selector of tree

=back


=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
