package Treex::Block::A2T::SK::SetFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %aux2functor = (
    "než"     => "CPR",
    "ako"      => "CPR",
    "podľa"   => "REG",
    "napriek"  => "CNCS",
    "navzdory" => "CNCS",
    "potom"    => "TWHEN",
);

my %formeme2functor = (
    "n:2"            => "RSTR",
    "n:3"            => "ADDR",
    "n:4"            => "PAT",
    "n:7"            => "MEANS",
    "n:pre+4"        => "BEN",
    "n:s+7"          => "ACMP",
    "adj:poss"       => "APP",
    "v:keď+fin"     => "COND",
    "v:keby+fin"     => "COND",
    "v:či+fin"      => "COND",
    "n:z+2"          => "DIR1",
    "n:cez+2"        => "DIR2",
    "n:do+2"         => "DIR3",
    "n:na+4"         => "DIR3",
    "n:v+4"          => "DIR3",
    "n:pod+4"        => "DIR3",
    "n:nad+4"        => "DIR3",
    "n:v+6"          => "LOC",
    "n:na+6"         => "LOC",
    "n:pod+7"        => "LOC",
    "n:nad+7"        => "LOC",
    "n:za+7"         => "LOC",
    "n:pred+7"       => "LOC",
    "v:pretože+fin" => "CAUS",
    "v:lebo+fin"     => "CAUS",
    "n:kvôli+fin"   => "CAUS",
    "v:dokial+fin"   => "TTILL",
    "v:až_kým+fin" => "TTILL",
    "v:kým+fin"     => "TTILL",
    "n:po+6"         => "TWHEN",
);

my %mlemma2functor = (
    "nie"        => "RHEM",
    "ne"         => "RHEM",
    "iba"        => "RHEM",
    "len"        => "RHEM",
    "práve"     => "EXT",
    "presne"     => "EXT",
    "dokonca"    => "RHEM",
    "skoro"      => "EXT",
    "takmer"     => "EXT",
    "aj"         => "RHEM",
    "tiež"      => "RHEM",
    "obaja"      => "RSTR",
    "oba"        => "RSTR",
    "rýchlo"    => "EXT",
    "rýchle"    => "EXT",
    "veľa"      => "EXT",
    "veľmi"     => "EXT",
    "viac"     => "EXT",
    "menej"     => "EXT",
    "mnoho"      => "EXT",
    "najmä"     => "EXT",
    "hlavne"     => "EXT",
    "hlavne"     => "EXT",
    "prevažne"  => "EXT",
    "zväčša"  => "EXT",
    "zväčša"  => "EXT",
    "úplne"     => "EXT",
    "naprosto"   => "EXT",
    "absolútne" => "EXT",
    "aktuálne"  => "TWHEN",
    "skoro"      => "TWHEN",
    "čoskoro"   => "TWHEN",
    "zanedlho"   => "TWHEN",
    "zakrátko"  => "TWHEN",
    "hneď"      => "TWHEN",
);

my %afun2functor = (
    "Apos" => "APPS",
);

my %temporal_noun;
foreach (
    qw(
    pondelok utorok streda štvrtok piatok sobota nedeľa
    január február marec apríl máj jún júl august september október november december
    jar leto jeseň zima
    rok mesiac týždeň deň hodina minúta
    dnes včera zajtra
    ráno večer poludnie obed popoludnie poobedie odpoludnie dopoludnie
    doba éra čas chvíľa
    kedy teraz
    )
    )
{
    $temporal_noun{$_} = 1;
}

sub assign_functors {
    my ($t_root) = @_;

    NODE: foreach my $node ( grep { not defined $_->functor } $t_root->get_descendants ) {

        #        my $lex_a_node  = $document->get_node_by_id( $node->get_attr('a/lex.rf') );
        my $lex_a_node = $node->get_lex_anode;

        if ( not defined $lex_a_node ) {
            $node->set_functor('???');
            next NODE;
        }

        my ($t_parent)    = $node->get_eparents( { or_topological => 1 } );
        my $a_parent    = $lex_a_node->get_parent;
        my $afun        = $lex_a_node->afun;
        my $mlemma      = lc $lex_a_node->lemma;                            #Monday -> monday
        my @aux_a_nodes = $node->get_aux_anodes();
        my ($first_aux_mlemma) = map { $_->lemma } grep { $_->is_conjunction() or $_->is_preposition() } @aux_a_nodes;
        $first_aux_mlemma = '' if !defined $first_aux_mlemma;

        my $functor;

        if ( $node->get_parent() == $t_root ) {
            $functor = 'PRED'
        }
        elsif ( defined $temporal_noun{$mlemma} and ( not @aux_a_nodes or $first_aux_mlemma =~ /^(v|na|pred)$/ ) ) {
            $functor = "TWHEN";
        }
        elsif ( defined $temporal_noun{$mlemma} and $first_aux_mlemma eq "od" ) {
            $functor = "TSIN";
        }
        elsif ( defined $temporal_noun{$mlemma} and $first_aux_mlemma eq "do" ) {
            $functor = "TTILL";
        }
        elsif ( $functor = $mlemma2functor{ $node->t_lemma } ) {
        }
        elsif ( defined $afun and $functor = $afun2functor{$afun} ) {
        }
        elsif ( ($functor) = grep {$_} map { $aux2functor{ $_->lemma } } @aux_a_nodes ) {
        }
        elsif ( $node->formeme eq 'n:1' and $t_parent and $t_parent->formeme // '' =~ /^v/ ) {

            if ( $node->get_parent->is_passive ) {
                $functor = "PAT";
            }
            else {
                $functor = "ACT";
            }
        }
        elsif ( $node->formeme eq 'n:7' and $t_parent and $t_parent->formeme // '' =~ /^v/ ) {
            if ( $node->get_parent->is_passive ) {
                $functor = "ACT";
            }
            else {
                $functor = "MEANS";
            }
        }
        elsif ( $functor = $formeme2functor{ $node->formeme } ) {
        }
        else {
            $functor = '???';
        }
        $node->set_functor($functor);
    }
}

sub process_ttree {
    my ( $self, $t_root ) = @_;
    assign_functors($t_root);
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::SK::SetFunctors

=head1 DESCRIPTION

A very basic block that sets functors in Slovak using several simple rules.
The rules are adapted from A2T::EN::SetFunctors.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
