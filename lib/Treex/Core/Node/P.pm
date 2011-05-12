package Treex::Core::Node::P;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Node';

# dirty: merging terminal and nonterminal nodes' attributes

# common:

has [qw(is_head is_collins_head head_selection_rule index coindex)] => ( is => 'rw' );

# non-terminal specific

has [qw(form lemma tag)] => ( is => 'rw' );

# terminal specific

has [qw( phrase functions )] => ( is => 'rw' );

sub get_pml_type_name {
    my ($self) = @_;

    if ( $self->is_root() or $self->get_attr('phrase') ) {
        return 'p-nonterminal.type';
    }
    elsif ( $self->get_attr('tag') ) {
        return 'p-terminal.type';
    }
    else {
        return;
    }
}

# Nodes on the p-layer have no ordering attribute.
# (It is not needed, trees are projective,
#  the order is implied by the ordering of siblings.)
override 'get_ordering_value' => sub {
    my ($self) = @_;
    return;
};

sub create_nonterminal_child {
    my $self = shift @_;
    my $fs_file = $self->get_bundle->get_document()->_pmldoc;
    my $child = $self->create_child(@_);
    $child->set_type_by_name($fs_file->metaData('schema'), 'p-nonterminal.type');
#    Treex::PML::Factory->createTypedNode( 'p-nonterminal.type',$fs_file->metaData('schema'));
    $child->{'#name'} = 'nonterminal';
    return $child;
}

sub create_terminal_child {
    my $self = shift @_;
    my $fs_file = $self->get_bundle->get_document()->_pmldoc;
    my $child = $self->create_child(@_);
    $child->set_type_by_name($fs_file->metaData('schema'), 'p-terminal.type');
#    my $child = Treex::PML::Factory->createTypedNode( 'p-terminal.type',$fs_file->metaData('schema'));
    $child->{'#name'} = 'terminal';
    return $child;
}


sub create_from_mrg {
    my ($self, $mrg_string) = @_;

    # normalize spaces
    $mrg_string =~ s/([()])/ $1 /g;
    $mrg_string =~ s/\s+/ /g;
    $mrg_string =~ s/^ //g;
    $mrg_string =~ s/ $//g;

    # remove extra outer parenthesis (ROOT comes from Stanford, S1 comes from Charniak parser)
    $mrg_string =~ s/^\(( (ROOT|S1) )?(\(.+\)) \)$/$3/g;

    my @tokens = split / /,$mrg_string;

    _parse_mrg_nonterminal(\@tokens, $self);

}


sub _reduce {
    my ($tokens_rf,$expected_token) = @_;
    if ($tokens_rf->[0] eq $expected_token) {
        return shift @{$tokens_rf};
    }
    else {
        log_fatal "Unparsable mrg remainder: '$expected_token' is not at the beginning of: "
            .join(" ",@$tokens_rf);
    }
}

sub _parse_mrg_nonterminal {
    my ($tokens_rf, $parent_node) = @_;

#    print "Parsing non-terminal: ".join(' ',@$tokens_rf)."\n";

    _reduce($tokens_rf,"(");

    my $new_nonterminal = $parent_node->create_nonterminal_child;

    # phrase type and (optionally) a list of grammatical functions
    my $label = shift @{$tokens_rf};
    my @label_components = split /-/,$label;
    $new_nonterminal->set_phrase(shift @label_components);
    if (@label_components) {
        $new_nonterminal->set_functions(\@label_components);
    }

    while ($tokens_rf->[0] eq "(") {
        if ($tokens_rf->[2] eq "(") {
            _parse_mrg_nonterminal($tokens_rf, $new_nonterminal);
        }
        else {
            _parse_mrg_terminal($tokens_rf, $new_nonterminal);
        }
    }

    _reduce($tokens_rf,")");
}

sub _parse_mrg_terminal {
    my ($tokens_rf, $parent_node) = @_;

#    print "Parsing terminal: ".join(' ',@$tokens_rf)."\n";
    _reduce($tokens_rf,"(");

    my $tag = shift @{$tokens_rf};
    my $form = shift @{$tokens_rf};
    my $new_terminal = $parent_node->create_terminal_child();
    $new_terminal->set_form($form);
    $new_terminal->set_tag($tag);

    _reduce($tokens_rf,")");
}



sub stringify_as_mrg {
    my ($self) = @_;

}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Node::P

=head1 DESCRIPTION

Representation of nodes of phrase structure (constituency) trees.


=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>
Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
