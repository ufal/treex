package Treex::Block::Read::Alpino;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
use Moose::Util qw(apply_all_roles);
use XML::Twig;

has bundles_per_doc => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );

has _twig => (
    isa    => 'XML::Twig',
    is     => 'ro',
    writer => '_set_twig',
);

sub BUILD {
    my ($self) = @_;
    if ( $self->bundles_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    $self->_set_twig( XML::Twig::->new() );
    return;
}

       
sub create_subtree {
    my ($xml_node, $treex_parent) = @_;
    if (defined $xml_node->{att}{cat}) { # the node is nonterminal
        my $nt = $treex_parent->create_nonterminal_child();
        $nt->set_phrase( $xml_node->{att}{cat} );
        $nt->set_index( $xml_node->{att}{index} ) if defined $xml_node->{att}{index};
        foreach my $attr (keys %{$xml_node->{att}}) {
            next if $attr =~ /^(cat|begin|end|id|index)$/;
            $nt->wild->{$attr} = $xml_node->{att}{$attr};
        }
        #foreach my $child (sort {$a->{att}{begin} <=> $b->{att}{begin}} $xml_node->children('node')) {
        foreach my $child ($xml_node->children('node')) {
            create_subtree($child, $nt);
        }
    }
    elsif (defined $xml_node->{att}{word}) { # the node is terminal
        my $t = $treex_parent->create_terminal_child();
        #$t->set_id( $xml_node->{att}{id} );
        $t->set_form( $xml_node->{att}{word} );
        $t->set_lemma( $xml_node->{att}{lemma} );
        $t->set_tag( $xml_node->{att}{pos} );
        $t->set_index( $xml_node->{att}{index} ) if defined $xml_node->{att}{index};
        $t->wild->{pord} = $xml_node->{att}{begin} + 1;
        foreach my $attr (keys %{$xml_node->{att}}) {
            next if $attr =~ /^(word|lemma|pos|begin|end|id|index)$/;
            $t->wild->{$attr} = $xml_node->{att}{$attr};
        }
    }
    elsif (defined $xml_node->{att}{index}) { # the node is a trace
        my $t = $treex_parent->create_terminal_child();
        my $trace = '*-'.$xml_node->{att}{index};
        $t->set_form($trace);
        $t->set_lemma($trace);
        $t->set_tag('-NONE-');
        foreach my $attr (keys %{$xml_node->{att}}) {
            next if $attr =~ /^(begin|end|id|index)$/;
            $t->wild->{$attr} = $xml_node->{att}{$attr};
        }
    }
}

sub next_document {
    my ($self) = @_;
    my $filename = $self->next_filename();
    return if !defined $filename;
    log_info "Loading $filename...";

    my $document = $self->new_document();
    $self->_twig->setTwigRoots(
        { alpino_ds => sub {
                my ( $twig, $sentence ) = @_;
                $twig->purge;
                my $bundle = $document->create_bundle;
                my $zone   = $bundle->create_zone( $self->language, $self->selector );
                my $ptree  = $zone->create_ptree;
                #foreach my $node (sort {$a->{att}{begin} <=> $b->{att}{begin}} $sentence->children('node')) {
                foreach my $node ($sentence->children('node')) {
                    create_subtree($node, $ptree);
                }
            }
        });
    $self->_twig->parsefile($filename);

    return $document;
}    # next_document

1;

__END__

=head1 NAME

Treex::Block::Read::Alpino

=head1 DESCRIPTION

Document reader for the XML-based Alpino format used for storing
Alpino and Lassy treebanks.

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 PARAMETERS

=over

none

=head1 SEE

L<Treex::Block::Read::BaseReader>

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
