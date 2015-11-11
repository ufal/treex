package Treex::Block::Coref::PrepareSpecializedEval;

use Moose;
use Treex::Core::Common;
use 5.010;    # operator //

use Treex::Tool::Coreference::NodeFilter::PersPron;
use Treex::Tool::Coreference::NodeFilter::RelPron;

use List::MoreUtils qw/all/;

use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

has '+selector' => (default => 'ref');
has 'response_selector' => ( is => 'ro', isa => 'Str', default => 'src' );
has 'category' => ( is => 'ro', isa => enum([qw/text gram centrpron zero relpron/]), default => 'text');

my $MONO_ALIGN_FILTER = {rel_types => ['monolingual']};

sub remove_non_category_links {
    my ($ttrees, $category) = @_;

    foreach my $ttree (@$ttrees) {
        foreach my $tnode ($ttree->get_descendants()) {
            my @antes = $tnode->get_coref_nodes;
            next if (!@antes);
            if (!_is_in_category($tnode, $category)) {
                $tnode->remove_coref_nodes(@antes);
            }
        }
    }
}

sub process_document {
    my ($self, $doc) = @_;

    my @ref_ttrees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
    my @ref_chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ref_ttrees);


    # label or nodes belonging to the specified category
    foreach my $ref_chain (@ref_chains) {
        foreach my $ref_mention (@$ref_chain) {
            $ref_mention->wild->{in_coref_category} = _is_in_category($ref_mention, $self->category);
        }
    }
    
    my @src_ttrees = map {$_->get_tree($self->language, 't', $self->response_selector)} $doc->get_bundles;
    
    # remove all coreference links from src that do not comply to the specified category
    remove_non_category_links(\@src_ttrees, $self->category);
    
    my @src_chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@src_ttrees);

    # all the nodes, which are involved in coreference in src are included in evaluation
    foreach my $src_chain (@src_chains) {
        foreach my $src_mention (@$src_chain) {
            my ($ref_aligned_mention) = Treex::Tool::Align::Utils::aligned_transitively([$src_mention], [$MONO_ALIGN_FILTER]);
            if (defined $ref_aligned_mention) {
                $ref_aligned_mention->wild->{in_coref_category} = $ref_aligned_mention->wild->{in_coref_category} || 0;
            }
        }
    }

    foreach my $ref_chain (@ref_chains) {
        my @in_coref_defined = grep {defined $_->wild->{in_coref_category}} @$ref_chain;
        
        # unlabel all mentions in the chains that contain no mention belonging to the specified category
        my $in_category = grep {$_->wild->{in_coref_category} == 1} @in_coref_defined;
        if (!$in_category) {
            foreach my $entity (@in_coref_defined) {
                $entity->wild->{in_coref_category} = undef;
            }
            next;
        }

        # include the very first node in the chain
        #   if it is unlabeled
        #   && there is no labeled node before the first mention belonging to the specified category
        if (!defined $ref_chain->[0]->wild->{in_coref_category} && $in_coref_defined[0]->wild->{in_coref_category} == 1) {
            $ref_chain->[0]->wild->{in_coref_category} = 0;
        }
    }

    #my $chain_idx = 1;
    foreach my $ref_chain (@ref_chains) {
        #print STDERR "PROCESSING CHAIN no. $chain_idx\n";
        my $last_ante;
        foreach my $entity (@$ref_chain) {
            #print STDERR "ENTITY_ID: " . $entity->get_address . "\n";
            #print STDERR "LAST_ANTE: " . ($last_ante ? $last_ante->id : "undef") . "\n";
            my $coref_type = "text";
            my @antes = $entity->get_coref_text_nodes;
            if (!@antes) {
                $coref_type = "gram";
                @antes = $entity->get_coref_gram_nodes;
            }
            foreach my $ante (@antes) {
                if (!defined $ante->wild->{in_coref_category}) {
                    $entity->remove_coref_nodes($ante);
                    if (defined $last_ante) {
                        if ($coref_type eq "text") {
                            $entity->add_coref_text_nodes($last_ante);
                        }
                        else {
                            $entity->add_coref_gram_nodes($last_ante);
                        }
                    }
                }
            }
            
            if (!defined $entity->wild->{in_coref_category}) {
                $entity->remove_coref_nodes(@antes);
            }
            else {
                $last_ante = $entity;
            }
        }
        #$chain_idx++;
    }
}

sub _is_in_category {
    my ($tnode, $category) = @_;

    if ($category eq "text") {
        my @antes = $tnode->get_coref_text_nodes;
        return (@antes > 0);
    }
    elsif ($category eq "gram") {
        my @antes = $tnode->get_coref_gram_nodes;
        return (@antes > 0);
    }
    elsif ($category =~ /^centrpron/) {
        return Treex::Tool::Coreference::NodeFilter::PersPron::is_3rd_pers($tnode, {expressed => 1});
    }
    elsif ($category =~ /^zero/) {
        # TODO
    }
    elsif ($category =~ /^relpron/) {
        return Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($tnode);
    }
}

1;

=head1 NAME

Treex::Block::Coref::PrepareSpecializedEval

=head1 DESCRIPTION

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
