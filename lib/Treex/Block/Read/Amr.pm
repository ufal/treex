package Treex::Block::Read::Amr;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

sub next_document {

    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    $text =~ s/[\n|\s]+/ /g;

    my @chars = split( '', $text );

    my $state         = 'Void';    # what we are currently reading
    my $value         = '';
    my $lemma         = '';        # current t-lemma
    my $word          = '';
    my $modifier      = '';
    my $param         = '';        # name of the current AMR variable
    my %param2id      = {};        # AMR variable name -> node id, used for coreference
    my $ord           = 0;
    my $bracket_depth = 0;
    my $sent_count    = 0;         # sentence count (not used)

    my ( $bundle, $zone, $tree, $cur_node );

    my $doc = $self->new_document();

    foreach my $arg (@chars) {

        if ( $arg eq '(' ) {
            if ( $state eq 'Void' ) {
                %param2id = {};
                $bundle   = $doc->create_bundle;
                $zone     = $bundle->create_zone( $self->language, $self->selector );
                $tree     = $zone->create_ttree();

                $cur_node = $tree->create_child( { ord => $ord } );
                $cur_node->wild->{modifier} = 'root';
                $ord++;
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
            if ( $state eq 'Word' && $value ) {
                $lemma = '';
                $word  = $value;
                if ($param) {
                    $lemma = $param;
                }
                if ($lemma) {
                    $lemma .= '/' . $word;
                }
                else {
                    $lemma = $word;
                }
                if ($lemma) {
                    $cur_node->set_attr( 't_lemma', $lemma );
                }
                if ($param) {
                    if ( exists( $param2id{$param} ) ) {
                        $cur_node->add_coref_text_nodes( $doc->get_node_by_id( $param2id{$param} ) );
                    }
                    else {
                        $param2id{$param} = $cur_node->get_attr('id');
                    }
                }
                $param = '';
                $word  = '';
                $value = '';
            }
            if ( $state eq 'Param' && $value ) {
                $param = $value;
                if ($param) {
                    $cur_node->set_attr( 't_lemma', $param );
                }
                if ($param) {
                    if ( exists( $param2id{$param} ) ) {
                        $cur_node->add_coref_text_nodes( $doc->get_node_by_id( $param2id{$param} ) );
                    }
                    else {
                        $param2id{$param} = $cur_node->get_attr('id');
                    }
                }
                $cur_node = $cur_node->get_parent();
                $param    = '';
                $word     = '';
                $value    = '';
            }
            $state = 'Modifier';
        }
        elsif ( $arg eq ' ' ) {
            if ( $state eq 'Modifier' && $value ) {
                $modifier = $value;
                my $newNode = $cur_node->create_child( { ord => $ord } );
                $ord++;
                $cur_node = $newNode;
                if ($modifier) {
                    $cur_node->wild->{modifier} = $modifier;
                    $modifier = '';
                }
                $value = '';
                $state = 'Param';
            }
        }

        elsif ( $arg eq '"' ) {
            if ( $state eq 'Word' && $value ) {
                $cur_node->{t_lemma} = $value;
                $value               = '';
                $cur_node            = $cur_node->get_parent();
            }
            if ( $state eq 'Param' ) {
                $state = 'Word';
            }
        }

        elsif ( $arg eq ')' ) {
            $lemma = '';
            if ( $state eq 'Param' ) {
                $param = $value;
            }
            if ( $state eq 'Word' ) {
                $word = $value;
            }
            $lemma = $param;
            if ($word) {
                $lemma .= ( $lemma ? '/' : '' ) . $word;
            }
            if ($lemma) {
                $cur_node->set_attr( 't_lemma', $lemma );
            }
            if ($param) {
                if ( exists( $param2id{$param} ) ) {
                    $cur_node->add_coref_text_nodes( $doc->get_node_by_id( $param2id{$param} ) );
                }
                else {
                    $param2id{$param} = $cur_node->get_attr('id');
                }
            }

            $cur_node = $cur_node->get_parent();
            $value    = '';
            $word     = '';
            $param    = '';
            $bracket_depth--;
            if ( $bracket_depth eq 0 ) {
                $state = 'Void';
                $ord   = 0;
                $sent_count++;
            }
        }

        else {
            $value .= $arg;
        }
    }

    return $doc;
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
