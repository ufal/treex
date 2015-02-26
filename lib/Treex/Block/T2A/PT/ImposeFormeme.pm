package Treex::Block::T2A::PT::ImposeFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_tnode {
    my ( $self, $tnode ) = @_;

    #Formema tem prioridade sobre lemma
    #Procura próximo lemma correspondente ao POS do formema caso sejam diferentes
    if ($tnode->t_lemma =~ m/(acesso)/){

        my $variants_lemma_rf = $tnode->get_attr('translation_model/t_lemma_variants');
        foreach my $variant (@$variants_lemma_rf) {
            
            if($tnode->formeme =~ /^n:.*/ && $variant->{pos} eq 'noun'){
                if($variant->{t_lemma} ne $tnode->t_lemma){
                    log_warn "Muda t_lemma de " . $tnode->t_lemma . " para " . $variant->{t_lemma} ;
                    $tnode->set_attr('t_lemma', $variant->{t_lemma}  );

                    my $a_node = $tnode->get_lex_anode() or return;
                    $a_node->set_attr('lemma', $variant->{t_lemma}  );
                    
                }

                last;

            }

            if($tnode->formeme =~ /^v:.*/ && $variant->{pos} eq 'verb'){
                if($variant->{t_lemma} ne $tnode->t_lemma){
                    log_warn "Muda t_lemma de " . $tnode->t_lemma . " para " . $variant->{t_lemma} ;
                    $tnode->set_attr('t_lemma', $variant->{t_lemma}  );

                    my $a_node = $tnode->get_lex_anode() or return;
                    $a_node->set_attr('lemma', $variant->{t_lemma}  );
                }

                last;
            }

        }

    }


    #Força preposição 'de' quando se tem um nó 'ter' com pelo menos um nó filho verbo
    if ($tnode->t_lemma =~ m/(ter|clique|clicar|carregar)/){

        #Verifica se tem nó filho e sendo este verbo
        foreach my $node ( $tnode->get_children({ following_only=>1 }) ) {

            if ($node->formeme =~ /^v:.*/) { 

                #Contem nó filho como verbo
                #Impõe formema com preposição de 
                #TODO Manter fin ou inf ou outras propriedades?
                $node->set_attr('formeme', 'v:de+X' ) if $tnode->t_lemma eq 'ter';

            }

            if($tnode->t_lemma =~ m/(clique|clicar|carregar)/){
                $node->set_attr('formeme', 'n:em+X' );
            }

            last;
        }
    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::ImposeFormeme

=head1 DESCRIPTION

Imposes formeme over know bad formations (Ugly hack)

=head1 AUTHORS

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.




