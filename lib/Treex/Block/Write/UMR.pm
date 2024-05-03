package Treex::Block::Write::UMR;
use Moose;
use Treex::Core::Common;
use experimental qw( signatures );

use Unicode::Normalize qw{ NFKD };

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.umr' );

has _curr_sentord => ( isa => 'Int', is => 'rw' );
has _used_variables => ( isa => 'ArrayRef[Int]', is => 'rw' );
has _id_cache => ( isa => 'HashRef[Str]', is => 'ro', default => sub { {} } );

sub _clear_variables($self) {
    $self->_set_used_variables([(0) x (ord("z") - ord("a") + 1)]);
}

sub _assign_variable($self, $concept) {
    my $concept_norm = NFKD($concept);
    $concept_norm =~ s/\p{NonspacingMark}//g;
    $concept_norm = lc $concept_norm;

    my $varletter = $concept_norm =~ /^([a-z])/ ? $1 : "x";
    my $varord = $self->_used_variables->[ord($varletter) - ord("a")]++;

    return "s" . $self->_curr_sentord . $varletter . ($varord + 1)
}

sub process_utree($self, $utree, $sentord) {
    $self->_set_curr_sentord($sentord);
    $self->_clear_variables();

    print { $self->_file_handle } $self->_get_sent_header($utree);
    print { $self->_file_handle } $self->_get_sent_graph($utree);
    print { $self->_file_handle } $self->_get_alignment($utree);
    print { $self->_file_handle } $self->_get_doc_annot($utree);
    print { $self->_file_handle } $self->_get_sent_footer;
}

sub _get_sent_header($self, $utree) {
    my $text = '#' x 80;
    $text .= "\n# sent_id = " . $utree->id . "\n";
    my $troot = $utree->get_troot;
    $text .= "# :: snt" . $self->_curr_sentord . "\n";
    my @anodes = $troot->get_bundle
                       ->get_zone($troot->language)
                       ->get_atree
                       ->get_descendants({ordered => 1});
    $text .= join "", 'Index: ', map $_->ord . (' ' x (length($_->form) - length($_->ord) + 1)), @anodes;
    $text .= join ' ', "\nWords:", map $_->form, @anodes;
    $text .= "\n\n";
    return $text
}

sub _get_sent_footer($self) { "\n\n\n" }

sub _get_sent_graph($self, $utechroot) {
    my $text = "# sentence level graph:\n";

    my @uroots = $utechroot->get_children();
    if (@uroots) {
        if (@uroots > 1) {
            log_warn('Multiple root U-nodes for the sentence = '
                     . $utechroot->id
                     . ". Printing the first root only.\n");
        }
        $text .= $self->_get_sent_subtree($uroots[0]);
    }
    $text .= "\n";
    return $text
}

sub _get_node_indent($self, $unode) {
    return ' ' x (4 * $unode->get_depth)
}

sub _get_sent_subtree($self, $unode) {
    my $umr_str = "";

    my $concept = $unode->concept;
    my $var = $self->_assign_variable($concept);
    $self->_id_cache->{ $unode->id } = $var;

    $umr_str .= "($var / $concept";

    for my $uchild ($unode->get_children({ordered => 1})) {
        $umr_str .= "\n" . $self->_get_node_indent($uchild);
        $umr_str .= ':' . $uchild->functor . ' ';
        $umr_str .= $self->_get_sent_subtree($uchild);
    }

    if ($unode->entity_refnumber) {
        $umr_str .= "\n" . $self->_get_node_indent($unode) . ' ' x 4;
        $umr_str .= ':refer-number ' . $unode->entity_refnumber;
    }
    $umr_str .= ')';
    return $umr_str
}

sub _format_alignment($self, @ords) {
    @ords = sort { $a <=> $b } @ords;
    my $string = "";
    for my $i (0 .. $#ords) {
        my $follows_prev = $i > 0      && $ords[$i] == $ords[ $i - 1 ] + 1;
        my $next_follows = $i < $#ords && $ords[$i] == $ords[ $i + 1 ] - 1;
        next if $follows_prev && $next_follows;

        $string .= $ords[$i]
                 . ($follows_prev  ? ','
                   : $next_follows ? '-'
                                   :  "-$ords[$i],");
    }
    return $string =~ s/,$//r
}

sub _is_same_tree($self, $unode, $anode) {
    $anode->get_bundle->get_position == $unode->get_bundle->get_position
}

sub _get_alignment($self, $utree) {
    my $alignment = "\n# alignment:";
    for my $unode ($utree->descendants) {
        $alignment .= "\n" . $self->_id_cache->{ $unode->id } . ': ';
        my @a_ords = map $_->ord,
                     grep $self->_is_same_tree($unode, $_),
                     $unode->get_tnode->get_anodes;
        $alignment .= $self->_format_alignment(@a_ords);
    }

    $alignment .= "\n";
    return $alignment
}

sub _get_doc_annot($self, $utree) {
    my $doc_annot = "\n# document level annotation:\n(s"
                  . $self->_curr_sentord . "s0 / sentence";
    $doc_annot .= $self->_coref($utree);
    $doc_annot .= ')';
    return $doc_annot
}

sub _coref($self, $utree) {
    my @coref;
    for my $unode ($utree->descendants) {
        if (my @node_coref = $unode->get_coref) {
            for my $node_coref (@node_coref) {
                push @coref, '(' . $self->_id_cache->{ $unode->id }
                             . ' :' . $node_coref->[1] . ' '
                             . $self->_id_cache->{ $node_coref->[0]->id }
                             . ')';
            }
        }
    }
    return "\n    :coref (" . join("\n            ", @coref) . ')' if @coref;
    return ""
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Write::UMR

=head1 DESCRIPTION

Document writer of the U-layer into the UMR format.

=head1 ATTRIBUTES

=over

=item language

Language of the trees to be printed.

=item selector

Selector of the trees to be printed.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

Jan Štěpánek <stepanek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2024 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
