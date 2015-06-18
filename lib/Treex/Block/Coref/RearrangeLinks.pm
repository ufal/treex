package Treex::Block::Coref::RearrangeLinks;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::Utils;

extends 'Treex::Core::Block';

has 'retain_cataphora' => (
    isa => 'Bool',
    is => 'ro',
    default => 0,
    required => 1,
);

sub _sort_chain {
    my ($self, $chain) = @_;

    if ($self->retain_cataphora) {

        my @no_cataphors = ();
        foreach my $anaph (@$chain) {
            if (any {$_->wild->{doc_ord} > $anaph->wild->{doc_ord}} $anaph->get_coref_nodes) {
                
                my @antes = grep {$_->wild->{doc_ord} < $anaph->wild->{doc_ord}} $anaph->get_coref_nodes;
                $anaph->remove_coref_nodes( @antes );
            }
            else {
                push @no_cataphors, $anaph;
            }
        }
        $chain = \@no_cataphors;
    }
    my @ordered_chain = sort {$a->wild->{doc_ord} <=> $b->wild->{doc_ord}} @$chain;

    my $ante = shift @ordered_chain;
    while (my $anaph = shift @ordered_chain) {

        my @gram_antes = $anaph->get_coref_gram_nodes;
        
        # replace the current antecedent with a direct predecessor
        $anaph->remove_coref_nodes( $anaph->get_coref_nodes );
        if (@gram_antes > 0) {
            $anaph->add_coref_gram_nodes( $ante );
        }
        else {
            $anaph->add_coref_text_nodes( $ante );
        }

        $ante = $anaph;
    }
}

sub process_document_one_zone_at_time {
    my ($self, $doc) = @_;

    my @ttrees = map { $_->get_tree($self->language,'t',$self->selector) } $doc->get_bundles;
    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(@ttrees);

    foreach my $chain (@chains) {
        $self->_sort_chain( $chain );
    }
    return;
}

sub process_document {
    my ($self, $doc) = @_;
    $self->_apply_function_on_each_zone($doc, \&process_document_one_zone_at_time, $self, $doc);
    return;
}


1;

=head1 NAME

Treex::Block::A2T::RearrangeLinks

=head1 DESCRIPTION

This block rearrange the coreference links so that they form a chain.
The only exceptions may be cataphors, which then points to some entity
within the chain but nothing refers to them.

=head1 ATTRIBUTES

=over

=item retain_cataphora

If enabled, cataphors are removed from the rearranging.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
