package Treex::Block::T2A::ES::MoveRhematizers;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $rhematizer ) = @_;

    my @articles = ("la", "el", "las", "los");

    my $lemma = $rhematizer->lemma;
    if($lemma =~ /^tod[oa]s?$/i){

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

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::ES::MoveRhematizers - shift rhematizers before articles and prepositions

=head1 DESCRIPTION

The article should go before the whoule noun phrase, except for some rhematizers (todos, todas).

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
