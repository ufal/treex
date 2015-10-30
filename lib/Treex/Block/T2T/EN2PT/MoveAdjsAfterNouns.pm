package Treex::Block::T2T::EN2PT::MoveAdjsAfterNouns;
use Moose;
use LX::Data::PT;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# A lista de adjectivos pré-nominais abaixo foi parcialmente extraída do
#  ficheiro Excel SSLEX-AJ-V04.xls filtrando a coluna I (Postnominal Position)
#  pelo valor "no" e a coluna N (Prenominal Position) pelo valor "prenominal".

# Excluí algumas entradas da lista que me parecem mais pós-nominais que
#  pré-nominais:

my %prenominal_adjs = (
    'custódio' => 1,
    'demasiado' => 1,
    'dito' => 1,
    'ditoso' => 1,
    'douto' => 1,
    'ex-futuro' => 1,
    'famigerado' => 1,
   #'fino' => 1, # pode ser pós-nominal; exemplo: "pessoa fina"
   #'forte' => 1, # pode ser pós-nominal; exemplos: "viga forte", "pessoa forte"
    'futuro' => 1,
    'grande' => 1,
    'maior' => 1,
    'mero' => 1,
    'milhentos' => 1,
    'presumível' => 1,
    'pronto' => 1,
    'reverendo' => 1,
    'suposto' => 1,
    'último' => 1,
);

my %ord = (
    'primeiro' => 1,
    'segundo' => 1,
    'terceiro' => 1,
    'quarto' => 1,
    'quinto' => 1,
    'sexto' => 1,
    'sétimo' => 1,
    'oitavo' => 1,
    'nono' => 1,
    'décimo' => 1,
    'vigésimo' => 1,
    'trigésimo' => 1,
    'quadragésimo' => 1,
    'quinquagésimo' => 1,
    'hexagésimo' => 1,
    'septuagésimo' => 1,
    'octagésimo' => 1,
    'nonagésimo' => 1,
    'centésimo' => 1,
    'milésimo' => 1,
);

sub process_ttree {
    my ( $self, $troot ) = @_;
    foreach my $tnode ( $troot->get_descendants ) {

        my $parent = $tnode->get_parent;

        # When a node is part of a menu chain (ex. fo to Tools > Word Count) 
        # don't move adjectives after nouns
        if (any {($_->functor || "") =~ /^RSTR$/} $tnode->get_siblings) {
            return;
        }

        if (( $tnode->formeme || "" ) =~ /^(?:adj:|n:attr)/
            and ! exists($prenominal_adjs{lc($tnode->t_lemma)})
            and ! exists($ord{lc($tnode->t_lemma)})
            and ( ( $parent->formeme || "" ) =~ /^n:/ )
            and $tnode->precedes($tnode->get_parent)
            and not $tnode->get_children
            and not $tnode->is_member
            and not $tnode->is_parenthesis
            and not (($tnode->gram_sempos // '' ) =~ /pron/)
            and not ((lc $tnode->t_lemma) ~~ @LX::Data::PT::exceptionsMoveAdjsAfterNouns)
            ) {
                while (($parent->get_parent->formeme || "" ) =~ /^n:/
                       and $tnode->precedes($parent->get_parent)) {
                    $parent = $parent->get_parent;
                }

                my $before = $tnode->t_lemma."(".($tnode->formeme // "").") ".$parent->t_lemma."(".($parent->formeme // "").")";

                # TODO: is this really needed n:attr => adj:attr?
                $tnode->set_formeme("adj:attr") if $tnode->formeme =~ /^n:attr/;
                $tnode->shift_after_node($parent);

                my $after = $parent->t_lemma."(".($parent->formeme // "").") ".$tnode->t_lemma."(".($tnode->formeme // "").")";
                my $addr = $tnode->get_address();
                print STDERR "T2T::EN2PT::MoveAdjsAfterNouns: $addr\n";
                print STDERR "T2T::EN2PT::MoveAdjsAfterNouns: $before ==>  $after\n";
        }
    }

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2PT::MoveAdjsAfterNouns

=head1 DESCRIPTION

Adjectives (and other adjectivals) that preceed their governing nouns
are moved after them. Examples:
    social policy => política social
    European Commission => Comissão Europeia

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
