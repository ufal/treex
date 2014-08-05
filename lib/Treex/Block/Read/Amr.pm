package Treex::Block::Read::Amr;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

has '_param2id' => ( is => 'rw', isa => 'HashRef' );

has '_doc' => ( is => 'rw' );

sub next_document {

    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    $text =~ s/[\n|\s]+/ /g;

    my @chars = split( '', $text );

    my $state         = 'Void';    # what we are currently reading
    my $value         = '';
    my $word          = '';
    my $modifier      = '';
    my $param         = '';        # name of the current AMR variable
    my $ord           = 0;         # current node's order
    my $bracket_depth = 0;
    my $sent_count    = 0;         # sentence count (not used, actually)

    my $cur_node;

    my $doc = $self->new_document();
    $self->_set_doc($doc);
    $self->_set_param2id( {} );

    foreach my $arg (@chars) {

        if ( $state eq 'Quote' ) {    # skipping named entities in quotes (may contain AMR special characters)
            if ( $arg ne '"' ) {
                $value .= $arg;
                next;
            }
        }

        if ( $arg eq '(' ) {          # delving deeper (new node)
            if ( $state eq 'Void' ) {
                $cur_node = $self->_next_sentence();
                $ord      = 1;
            }
            $state = 'Param';
            $value = '';
            $bracket_depth++;
        }

        elsif ( $arg eq '/' ) {
            if ( $state eq 'Param' && $value ) {
                $param = $value;
                $state = 'Word';
            }
            $value = '';    # TODO check if this doesn't break AMRs containing '/' in lemma
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
        elsif ( $arg eq ' ' ) {
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

        elsif ( $arg eq '"' ) {    # NE constant values
            if ( $state eq 'Quote' && $value ) {    # ending
                $cur_node->set_t_lemma( '"' . $value . '"' );
                $value    = '';
                $state    = 'Word';
                $cur_node = $cur_node->get_parent();
            }
            if ( $state eq 'Param' ) {              # beginning
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

            if ( $state eq 'Param' ) {
                $state    = 'Word';
                $cur_node = $cur_node->get_parent();
            }
            $cur_node = $cur_node->get_parent();
            $value    = '';
            $word     = '';
            $param    = '';
            $bracket_depth--;
            if ( $bracket_depth eq 0 ) {
                $state = 'Void';
                $sent_count++;
            }
        }

        else {
            $value .= $arg;
        }
    }

    return $doc;
}

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

sub _next_sentence {

    my ($self) = @_;

    $self->_set_param2id( {} );

    my $bundle = $self->_doc->create_bundle;
    my $zone   = $bundle->create_zone( $self->language, $self->selector );
    my $tree   = $zone->create_ttree();

    my $cur_node = $tree->create_child( { ord => 0 } );
    $cur_node->wild->{modifier} = 'root';

    return $cur_node;
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
