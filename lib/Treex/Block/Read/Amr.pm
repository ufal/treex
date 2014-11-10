package Treex::Block::Read::Amr;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

has '_param2id' => ( is => 'rw', isa => 'HashRef' );

has '_doc' => ( is => 'rw' );

has '_comment_data' => ( is => 'rw', isa => 'HashRef' );

has 'debug' => ( is => 'rw', isa => 'Bool', default => 0 );

sub next_document {

    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my @chars = split( '', $text );

    my $state         = 'Void';    # what we are currently reading
    my $value         = '';
    my $word          = '';        # current concept
    my $modifier      = '';        # current AMR dependency label
    my $param         = '';        # name of the current AMR variable
    my $ord           = 0;         # current node's order
    my $bracket_depth = 0;
    my $sent_count    = 0;         # sentence count (not used, actually)

    my $cur_node;

    my $doc = $self->new_document();
    $self->_set_doc($doc);
    $self->_set_param2id(     {} );
    $self->_set_comment_data( {} );

    foreach my $arg (@chars) {

        # skipping named entities in quotes (may contain AMR special characters)
        if ( $state eq 'Quote' ) {
            if ( $arg ne '"' ) {
                $value .= $arg;
                next;
            }
        }

        # skipping commented-out lines
        elsif ( $state eq 'Comment' ) {

            if ( $arg eq "\n" ) {    # parse the comment at its end
                $self->_parse_comment($value);
                $value = '';
                $state = 'Void';
                next;
            }
            $value .= $arg;
            next;
        }

        # normal operation mode

        if ( $arg eq '(' ) {         # delving deeper (new node)
            if ( $state eq 'Void' ) {
                $cur_node = $self->_next_sentence();
                $ord      = 2;
            }
            $state = 'Param';
            $value = '';
            $bracket_depth++;
        }

        elsif ( $arg eq '/' ) {      # variable name / concept name
            if ( $state eq 'Param' && $value ) {
                $param = $value;
                $state = 'Word';
            }

            # TODO check if this doesn't break AMRs containing '/' in lemma
            $value = '';
        }

        elsif ( $arg eq ':' ) {
            if ($value) {
                if ( $state eq 'Word' ) {
                    $word = $value;
                }
                elsif ( $state eq 'Param' ) {
                    $param = $value;
                }
                $self->_fill_lemma( $cur_node, $param, $word );
                $self->_check_coref( $cur_node, $param );
                $param = '';
                $word  = '';
                $value = '';
                if ( $state eq 'Param' ) {
                    $cur_node = $cur_node->get_parent();
                }
            }
            $state = 'Modifier';
        }
        elsif ( $arg =~ /\s/ ) {
            if ( $state eq 'Modifier' && $value ) {
                $modifier = $value;
                $cur_node = $cur_node->create_child( { ord => $ord++ } );
                if ($modifier) {
                    $cur_node->wild->{modifier} = $modifier;
                    $modifier = '';
                }
                $value = '';
                $state = 'Param';
            }
        }

        elsif ( $arg eq '"' ) {    # NE constant values / concept names in quotes
            if ( $state eq 'Quote' && $value ) {    # ending
                $self->_fill_lemma( $cur_node, $param, '"' . $value . '"' );
                $value    = '';
                $state    = 'Word';
                $cur_node = $cur_node->get_parent();
            }
            elsif ( $state =~ /^(Param|Word)$/ ) {    # beginning
                $state = 'Quote';
            }
        }

        elsif ( $arg eq ')' ) {
            if ( $state eq 'Param' ) {
                $param = $value;
            }
            if ( $state eq 'Word' ) {
                $word = $value;
            }
            $self->_fill_lemma( $cur_node, $param, $word );
            $self->_check_coref( $cur_node, $param );

            if ( $state eq 'Param' ) {    # go up one more level for reentrancies
                $state    = 'Word';
                $cur_node = $cur_node->get_parent();
            }
            $cur_node = $cur_node->get_parent();
            $value    = '';
            $word     = '';
            $param    = '';
            $bracket_depth--;
            if ( $bracket_depth eq 0 ) {    # end of sentence
                $state = 'Void';
                $sent_count++;
                $self->_process_comment_data();
            }
        }

        elsif ( $arg eq '#' and $state eq 'Void' and $value =~ /(\s|^)$/ ) {
            $value = '';
            $state = 'Comment';
        }

        else {
            $value .= $arg;
        }
    }

    return $doc;
}

# Check for coreference -- add coreference link if the given variable name is
# a reentrancy (i.e., has a first-mention ID in the _param2id member). Otherwise
# remember the variable in _param2id for future reference.
sub _check_coref {

    my ( $self, $cur_node, $param ) = @_;

    return if ( !$param );

    if ( exists( $self->_param2id->{$param} ) ) {
        $cur_node->add_coref_text_nodes( $self->_doc->get_node_by_id( $self->_param2id->{$param} ) );
    }
    else {
        $self->_param2id->{$param} = $cur_node->id;
    }
    return;
}

# Fill in AMR lemma (consisting of variable name, and optionally, concept name)
sub _fill_lemma {
    my ( $self, $cur_node, $param, $word ) = @_;
    my $lemma = $param;
    if ($word) {
        $lemma .= ( $lemma ? '/' : '' ) . $word;
    }
    if ($lemma) {
        $cur_node->set_t_lemma($lemma);
    }
    return;
}

# Start a new sentence (create a new bundle and t-tree).
# Reset the coreference tracker (_param2id)
sub _next_sentence {

    my ($self) = @_;

    $self->_set_param2id( {} );    # reset coreference tracker

    # create a new bundle and tree
    my $bundle = $self->_doc->create_bundle;
    my $zone   = $bundle->create_zone( $self->language, $self->selector );
    my $ttree  = $zone->create_ttree();

    if ( $self->debug ) {
        log_info( 'Creating ' . $ttree->id );
    }

    my $cur_node = $ttree->create_child( { ord => 1 } );
    $cur_node->wild->{modifier} = 'root';

    return $cur_node;
}

# Process all comment data stored for the current sentence
# Currently supported: surface text (set zone sentence), surface tokens (will create a-tree)
sub _process_comment_data {

    my ($self) = @_;

    return if not %{ $self->_comment_data };

    my @bundles = $self->_doc->get_bundles();
    my $bundle  = $bundles[-1];
    my $zone    = $bundle->get_zone( $self->language, $self->selector );
    my $ttree   = $zone->get_ttree();

    # store raw data in t-tree root's wild
    $ttree->wild->{amr_comment_data} = $self->_comment_data;

    # process sentence text
    my $sent_text = $self->_comment_data->{snt} // $self->_comment_data->{sentence} // $self->_comment_data->{tok};
    if ($sent_text) {
        $zone->set_sentence($sent_text);
    }

    # process surface tokens
    my $token_text = $self->_comment_data->{tok} // $self->_comment_data->{snt} // $self->_comment_data->{sentence};
    if ($token_text) {
        my $atree = $zone->create_atree();
        foreach my $token ( split /\s+/, $token_text ) {
            my $anode = $atree->create_child( { form => $token } );
            $anode->shift_after_subtree($atree);
        }

        # process alignments if applicable
        if ( $self->_comment_data->{alignments} ) {
            $self->_process_alignments( $ttree, $atree, $self->_comment_data->{alignments} );
        }
    }

    if ( $self->debug and $sent_text ) {
        log_info( 'Sentence text: ' . $sent_text );
    }

    $self->_set_comment_data( {} );
    return;
}

sub _process_alignments {
    my ( $self, $ttree, $atree, $ali_data ) = @_;

    # mapping AMR address -> node, surface address (=1-based ord) -> node
    my %tnodes = ();
    my ($amr_root) = $ttree->get_children( { ordered => 1 } );
    $self->_get_amr_addresses( $amr_root, 0, \%tnodes );
    my %anodes = map { $_->ord => $_ } $atree->get_descendants( { ordered => 1 } );

    foreach my $ali ( split / /, $ali_data ) {

        next if $ali =~ /^\*/;    # TODO what's this?

        my ( $a_addrs, $t_addrs ) = split /\|/, $ali;

        # Jeff's zero-based spans (convert them to 1-based)
        if ( $a_addrs =~ /-/ ) {
            my ( $lo, $hi ) = split /-/, $a_addrs;
            $a_addrs = [ $lo + 1 .. $hi ];
        }

        # Ondrej's 1-based non-contiguous format
        else {
            $a_addrs = [ split /\+/, $a_addrs ];
        }

        # AMR node addresses are all the same
        $t_addrs = [ split /\+/, $t_addrs ];

        foreach my $t_addr (@$t_addrs) {

            # first goes to lex-anode
            $tnodes{$t_addr}->set_lex_anode( $anodes{ $a_addrs->[0] } );
            if ( @$a_addrs > 1 ) {    # others go to aux-anodes
                $tnodes{$t_addr}->set_aux_anodes( map { $anodes{$_} } @$a_addrs[ 1 .. $#$a_addrs ] );
            }
        }
    }
}

# Find out AMR node addresses (given a subtree root and its ID, recurse to all nodes in
# the subtree and save their addresses in $addr_data)
sub _get_amr_addresses {
    my ( $self, $troot, $node_id, $addr_data ) = @_;
    $addr_data->{$node_id} = $troot;
    my $child_no = 0;
    foreach my $tchild ( $troot->get_children( { ordered => 1 } ) ) {
        if ( $tchild->t_lemma !~ /^[a-zA-Z][0-9]*$/ ) {    # skip reentrancies
            $self->_get_amr_addresses( $tchild, $node_id . '.' . $child_no, $addr_data );
            $child_no++;
        }
    }
}

# Check if a comment contains meaningful data (introduced by ::xxx...) and store them
# in the _comment_data member, which will be processed just before introducing the next sentence.
sub _parse_comment {
    my ( $self, $comment ) = @_;

    $comment =~ s/^\s+|\s+$//g;    # trim
    return if ( $comment !~ /^::[a-z]{2,}/ );

    my @data = split /\s*::([a-z]{2,})\s+/, $comment;
    shift @data;                   # first will be empty

    while (@data) {
        my ( $key, $val ) = splice @data, 0, 2;
        $self->_comment_data->{$key} = $val;
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Read::Amr

=head1 DESCRIPTION

A reader for the AMR bracketed (Penman) file format.

We actually reuse the standard t-layer for AMR instead of creating a 
proper layer on its own.

=head1 ATTRIBUTES

=over

=item from

Space or comma separated list of filenames.

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 AUTHORS

Roman Sudarikov <sudarikov@ufal.mff.cuni.cz>

Ondřej Bojar <bojar@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
