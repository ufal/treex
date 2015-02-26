package Treex::Block::T2A::PT::MoveRhematizers;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

#Andreia:
#1) Ordem de palavras (em PT::Moverhematizers):
#    sempre que aparece os todos -> passar para todos os
#
#os : adj art def
#todos : adj prn mas plu

sub process_anode {
    my ( $self, $rhematizer ) = @_;

    my @pronouns = ("todos","todas");
    my @articles = ("os","as");

    my $lemma = $rhematizer->lemma;
    if($lemma =~ /^tod[oa]s$/i){

        my $article = $rhematizer->get_left_neighbor();
        my $article_lemma = undef;

        if(defined $article){
            $article_lemma = $article->lemma;
        }

        if(defined $article_lemma){
            if("@articles" =~ /$article_lemma/){
                my $first_ord = $rhematizer->get_attr("ord");
                $rhematizer->shift_before_node($article);
            }
        }
        
    }

    return if !$rhematizer->is_adverb;

    my $noun = $rhematizer->get_parent;
    return if !$noun->is_noun;
    my $article = $noun->get_children({preceding_only=>1, first_only=>1});
    my $preposition = $noun->get_parent();
    my $start_of_scope;
    if ($article && $article->iset->adjtype eq 'art'){
        $start_of_scope = $article;
    }
    if ($preposition && $preposition->is_adposition && (!$article || $preposition->precedes($article))){
        $start_of_scope = $preposition 
    }
    if ($start_of_scope){
        $rhematizer->shift_before_node($start_of_scope);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::MoveRhematizers - shift rhematizers before articles and prepositions

=head1 DESCRIPTION

The article should go before the whoule noun phrase, except for some rhematizers (apenas, mesmo).

For example, we want to change:

 "A criança obedece a_ a apenas mãe"
 "A encomenda está em_ o mesmo armazém .

to

 "A criança obedece apenas a_ a mãe"
 "A encomenda está mesmo em_ o armazém .

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
