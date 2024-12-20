package Treex::Block::Write::UMR;
use Moose;
use Treex::Core::Common;
use experimental qw( signatures );

use Unicode::Normalize qw{ NFKD };

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.umr' );

has _curr_sentord => ( isa => 'Int', is => 'rw' );
has _skipped_sent_tally => ( isa => 'Int', is => 'rw', default => 0 );
has _used_variables => ( isa => 'ArrayRef[Int]', is => 'rw' );
has _id_cache => ( isa => 'HashRef[Str]', is => 'ro', default => sub { {} } );
has _buffer => ( isa => 'Str', is => 'rw', default => "" );
has _cataphora => ( isa => 'HashRef[HashRef[Str]]', is => 'rw',
                    default => sub { {} });

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
    unless ($utree->children) {
        $self->_set_skipped_sent_tally(1 + $self->_skipped_sent_tally);
        return
    }

    $self->_set_curr_sentord($sentord - $self->_skipped_sent_tally);
    $self->_clear_variables();

    $self->_add_to_buffer($self->_get_sent_header($utree));
    $self->_add_to_buffer($self->_get_sent_graph($utree));
    $self->_add_to_buffer($self->_get_alignment($utree));
    $self->_add_to_buffer($self->_get_doc_annot($utree));
    $self->_add_to_buffer($self->_get_sent_footer);
}

before process_document => sub ($self, @) {
    $self->_set_cataphora({});
};

after process_document => sub ($self, @) {
    print { $self->_file_handle } $self->_buffer;
    for my $k (keys %{ $self->_id_cache }) {
        warn "ID translation: $k ", $self->_id_cache->{$k}, "\n";
    }
};

sub _add_to_buffer($self, $string) {
    $self->_set_buffer($self->_buffer . $string);
    return
}

sub _format_index(@anodes) {
    my $minimal_length = length scalar @anodes;
    my $index = "";
    for my $anode (@anodes) {
        my $ord = $anode->ord;
        $index .= $ord;

        my $space_length = 1 + length($anode->form) - length($ord);
        $space_length += $minimal_length - length($anode->form)
            if length($anode->form) < $minimal_length;
        $index .= ' ' x $space_length;
    }
    return $index =~ s/ +$//r
}

sub _format_words(@anodes) {
    my $minimal_length = length scalar @anodes;
    my $words = join "",
                map { $_ . ' ' x ((length($_) < $minimal_length)
                                  ? $minimal_length
                                  : 1)
                } map $_->form,
                @anodes;
    return $words =~ s/ +$//r
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
    $text .= join "", 'Index: ', _format_index(@anodes);
    $text =~ s/ +$//;
    $text .= join "", "\nWords: ", _format_words(@anodes);
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

    my $concept = $unode->concept // '???';  # TODO
    my $var = $self->_id_cache->{ $unode->id };
    if (! defined $var) {
        $var = $self->_assign_variable($concept);
        $self->_id_cache->{ $unode->id } = $var;
    }

    if ('ref' eq ($unode->{nodetype} // "")) {
        my $ref = $unode->{'same_as.rf'};
        return $self->_id_cache->{$ref} if $self->_id_cache->{$ref};

        my $refered = (grep $ref eq $_->id, $unode->root->descendants)[0];
        die "No $ref from $unode->{id} ", $unode->concept,
                '.', $unode->parent->get_tnode->id
            unless $refered;

        return $self->_id_cache->{$ref}
               = $self->_assign_variable($refered->concept)
    }
    $umr_str .= "($var / " . $self->_printable($concept);

    for my $uchild ($unode->get_children({ordered => 1})) {
        $umr_str .= "\n" . $self->_get_node_indent($uchild);
        $umr_str .= ':' . $uchild->functor . ' ';
        $umr_str .= $self->_get_sent_subtree($uchild);
    }

    if ($unode->entity_refnumber) {
        $umr_str .= "\n" . $self->_get_node_indent($unode) . ' ' x 4;
        $umr_str .= ':refer-number ' . $unode->entity_refnumber;
    }

    if ($unode->entity_refperson) {
        $umr_str .= "\n" . $self->_get_node_indent($unode) . ' ' x 4;
        $umr_str .= ':refer-person ' . $unode->entity_refperson;
    }

    if ($unode->aspect) {
        $umr_str .= "\n" . $self->_get_node_indent($unode) . ' ' x 4;
        $umr_str .= ':aspect ' . $unode->aspect;
    }

    if ($unode->get_attr('polarity')) {
        $umr_str .= "\n" . $self->_get_node_indent($unode) . ' ' x 4;
        $umr_str .= ':polarity -';
    }

    if ($unode->modal_strength) {
        $umr_str .= "\n" . $self->_get_node_indent($unode) . ' ' x 4;
        $umr_str .= ':modal-strength ' . $unode->modal_strength;
    }

    $umr_str .= ')';
    return $umr_str
}

my %PRINT = ( ')' => '%rpar;');
sub _printable($self, $concept) {
    return $PRINT{$concept} if exists $PRINT{$concept};
    return $concept
}

sub _format_alignment($self, @ords) {
    @ords = sort { $a <=> $b } @ords;
    @ords = (0) unless @ords;
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
        next if 'ref' eq ($unode->nodetype // "");

        $alignment .= "\n" . $self->_id_cache->{ $unode->id } . ': ';
        if ($unode->get_alignment) {
            my @a_ords = map $_->ord,
                         grep $self->_is_same_tree($unode, $_),
                         $unode->get_alignment;
            $alignment .= $self->_format_alignment(@a_ords);
        } else {
            $alignment .= '0-0';
        }
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
        if (exists $self->_cataphora->{ $unode->id }) {
            for my $id2 (keys %{ $self->_cataphora->{ $unode->id } }) {
                push @coref, '(' . $self->_id_cache->{ $unode->id }
                             . ' :' . $self->_cataphora->{ $unode->id }{$id2}
                             . ' ' . $self->_id_cache->{$id2} . ')';
            }
        }

        if (my @node_coref = $unode->get_coref) {
            for my $node_coref (@node_coref) {
                my $id = $self->_id_cache->{ $node_coref->[0]->id };
                if (! defined $id) {
                    $self->add_cataphora($unode->id, $node_coref);
                } else {
                    push @coref, '(' . $self->_id_cache->{ $unode->id }
                                 . ' :' . $node_coref->[1] . ' '
                                 . $id . ')';
                }
            }
        }
    }
    return "\n    :coref (" . join("\n            ", @coref) . ')' if @coref;
    return ""
}

sub add_cataphora($self, $id, $coref) {
    my $id2 = $coref->[0]->id;
    die "Duplicate cataphora $id2 $id."
        if exists $self->_cataphora->{$id2}
        && exists $self->_cataphora->{$id2}{$id};
    $self->_cataphora->{$id2}{$id} = $coref->[1];
    return
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
