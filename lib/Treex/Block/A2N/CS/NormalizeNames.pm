package Treex::Block::A2N::CS::NormalizeNames;
use Moose;
use Treex::Core::Common;
use LanguageModel::MorphoLM;
use Treex::Tool::Lexicon::Generation::CS;
extends 'Treex::Core::Block';

my ( $morphoLM, $generator );
sub process_start {
    my $self = shift;
    $morphoLM  = LanguageModel::MorphoLM->new();
    $generator = Treex::Tool::Lexicon::Generation::CS->new();
    $self->SUPER::process_start();
    return;
}

sub process_nnode {
    my ($self, $nnode) = @_;
    my @anodes = $nnode->get_anodes();
    my %is_in_entity = map {($_,1)} @anodes;
    my %new_form;

    # Most entities should form a dependency treelet, so there should be just one root,
    # but we should handle also entities which form unconnected dependency structures.
    # Let's initialize the @queue with roots of such treelets.
    my @queue = grep {!$is_in_entity{$_->get_parent()}} @anodes;
    while(@queue){
        my $node = shift @queue;
        if ($node->is_coap_root){
            push @queue, grep {$is_in_entity{$_}} $node->get_coap_members();
            # TODO handle also shared modifiers
            next;
        }
        my $tag = $node->tag;
        next if $tag !~ /^[NAC]...[^1X]/;
        substr $tag, 4, 1, '1';
        $new_form{$node} = $self->generate_wordform($node, $tag);
        push @queue, grep {$is_in_entity{$_} && $self->is_congruent($_)} $node->get_children();
    }

    $nnode->set_normalized_name(
        join '',
        map {($new_form{$_}||$_->form) . ($_->no_space_after ? '' : ' ')}
        sort {$a->ord <=> $b->ord} @anodes
    );
    return;
}


sub generate_wordform {
    my ($self, $node, $tag) = @_;
    my $form_info = $morphoLM->best_form_of_lemma($node->lemma, $tag) || $generator->best_form_of_lemma($node->lemma, $tag);
    my $form = defined $form_info ? $form_info->get_form() : $node->form;
    if ($node->form eq uc $node->form){
        $form = uc $form;
    } elsif ($node->form =~ /^\p{IsUpper}/){
        $form = ucfirst $form;
    }
    return $form;
}

sub is_congruent{
    my ($self, $node) = @_;
    return substr($node->tag, 4, 1) eq substr($node->get_parent->tag, 4, 1);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2N::CS::NormalizeNames - fill attribute "normalized_name" for each named entity

=head1 DESCRIPTION

This block needs parsed a-layer.
Normalized name is the official name of the named entity (as found in dictionaries, encyclopedias etc.).
For example, "Ústím nad Labem" has normalized name "Ústí nad Labem" (the head word in nominative, non-congruent attribute "nad Labem" remains unchanged).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
inspired by a bachelor thesis of Petr Kubát

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
