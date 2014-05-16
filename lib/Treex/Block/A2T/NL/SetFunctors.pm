package Treex::Block::A2T::NL::SetFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %formeme2functor = (
    "n:obj"         => "PAT",
    "n:obj1"        => "ADDR",
    "n:obj2"        => "PAT",
    "n:voor+X"      => "BEN",
    "n:met+X"       => "ACMP",
    "n:poss"        => "APP",
    "n:van+X"       => "APP",
    "adj:attr"      => "RSTR",
    "v:attr"        => "RSTR",
    "v:als+fin"     => "COND",
    "v:of+fin"      => "COND",
    "n:door+X"      => "MEANS",
    "n:uit+X"       => "DIR1",
    "n:naar+X"      => "DIR3",
    "n:aan+X"       => "LOC",
    "n:in+X"        => "LOC",
    "n:op+X"        => "LOC",
    "n:onder+X"     => "LOC",
    "n:binnen+X"    => "LOC",
    "n:boven+X"     => "LOC",
    "n:achter+X"    => "LOC",
    "n:binnen+X"    => "LOC",
    "v:omdat+fin"   => "CAUS",
    "v:om+fin"      => "CAUS",
    "v:vanwege+fin" => "CAUS",
    "v:tot+fin"     => "TTILL",
    "v:totdat+fin"  => "TTILL",
    "v:nadat+fin"   => "TWHEN",
    "v:voordat+fin" => "TWHEN",
    "v:dat+fin"     => "EFF",
    "adv"           => "MANN",
    "v:rc"          => "RSTR",
    "adj:compl"     => "PAT",
    "n:attr"        => "RSTR",
);

my %tag2functor = ();

my %aux2functor = (
    "dan"       => "CPR",
    "als"       => "CPR",
    "aangezien" => "REG",
    "gezien"    => "REG",
    "sinds"     => "TSIN",
    "volgens"   => "REG",
    "ondanks"   => "CNCS",
    "trots"     => "CNCS",
    "toen"      => "TWHEN",
    "zodra"     => "TWHEN",
);

my %mlemma2functor = (
    "waneer"        => "TWHEN",
    "nu"            => "TWHEN",
    "momenteel"     => "TWHEN",
    "binnenkort"    => "TWHEN",
    "weldra"        => "TWHEN",
    "vroeg"         => "TWHEN",
    "laat"          => "TWHEN",
    "straks"        => "TWHEN",
    "thans"         => "TWHEN",
    "niet"          => "RHEM",
    "maar"          => "RHEM",
    "pas"           => "RHEM",
    "net"           => "RHEM",
    "juist"         => "RHEM",
    "zojuist"       => "RHEM",
    "zonet"         => "RHEM",
    "toch"          => "RHEM",
    "slechts"       => "RHEM",
    "even"          => "RHEM",
    "zelfs"         => "RHEM",
    "bijna"         => "EXT",
    "ook"           => "RHEM",
    "nog"           => "RHEM",
    "beide"         => "RSTR",
    "allebei"       => "RSTR",
    "beiden"        => "RSTR",
    "snel"          => "EXT",
    "vlot"          => "EXT",
    "vlug"          => "EXT",
    "langzaam"      => "EXT",
    "traag"         => "EXT",
    "veel"          => "EXT",
    "zeer"          => "EXT",
    "heel"          => "EXT",
    "uiterst"       => "EXT",
    "voornamelijk"  => "EXT",
    "vooral"        => "EXT",
    "hoofdzakelijk" => "EXT",
    "erg"           => "EXT",
    "behoorlijk"    => "EXT",
);

my %afun2functor = (
    "Apos" => "APPS",
);

my %temporal_noun;
foreach (
    qw(
    zondag maandag dinsdag woensdag donderdag vrijdag zaterdag
    januari februari maart april mei juni juli august september oktober november december
    lente voorjaar zomer herfst najaar winter
    jaar maand week dag uur minuut
    vandaag morgen vanmorgen gisteren
    avond middag nacht
    tijd termijn epoch epoche tijdperk era tijdvak tijdruimte
    )
    )
{
    $temporal_noun{$_} = 1;
}

has 'prep_when'  => ( 'isa' => 'Str', 'is' => 'ro', default => '(op|aan|in|binnen)' );
has 'prep_since' => ( 'isa' => 'Str', 'is' => 'ro', default => '(sinds|van|vanaf)' );
has 'prep_till'  => ( 'isa' => 'Str', 'is' => 'ro', default => '(tot|voor)' );

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( defined( $tnode->functor ) ) {
        return;
    }

    my $lex_anode = $tnode->get_lex_anode;

    if ( not defined $lex_anode ) {
        $tnode->set_functor('???');
        return;
    }
    my $afun           = $lex_anode->afun;
    my $mlemma         = lc $lex_anode->lemma;
    my @aux_a_nodes    = $tnode->get_aux_anodes();
    my $first_aux_prep = $self->get_first_aux_prep(@aux_a_nodes);
    my $functor;

    if ( $tnode->get_parent()->is_root() ) {
        $functor = 'PRED'
    }
    elsif ( defined $temporal_noun{$mlemma} and ( not @aux_a_nodes or $first_aux_prep =~ $self->prep_when ) ) {
        $functor = "TWHEN";
    }
    elsif ( defined $temporal_noun{$mlemma} and $first_aux_prep =~ $self->prep_since ) {
        $functor = "TSIN";
    }
    elsif ( defined $temporal_noun{$mlemma} and $first_aux_prep eq $self->prep_till ) {
        $functor = "TTILL";
    }
    elsif ( $functor = $mlemma2functor{ $tnode->t_lemma } ) {
    }
    elsif ( $functor = $tag2functor{ $lex_anode->tag } ) {
    }
    elsif ( defined $afun and $functor = $afun2functor{$afun} ) {
    }
    elsif ( ($functor) = grep {$_} map { $aux2functor{ $_->lemma } } @aux_a_nodes ) {
    }
    elsif ( $functor = $self->try_rules($tnode) ) {
    }
    elsif ( $functor = $formeme2functor{ $tnode->formeme } ) {
    }
    else {
        $functor = '???';
    }

    $tnode->set_functor($functor);
}

sub get_first_aux_prep {
    my ( $self, @aux_a_nodes ) = @_;
    return ( first { $_->is_preposition() or $_->is_conjunction } @aux_a_nodes ) // '';
}

sub try_rules {
    my ( $self, $tnode ) = @_;
    my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );

    if ( $tnode->formeme eq 'n:subj' and $tparent and $tparent->formeme // '' =~ /^v/ ) {
        if ( ( $tnode->get_parent->gram_diathesis // '' ) eq 'pas' ) {
            return 'PAT';
        }
        return 'ACT';
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::NL::SetFunctors

=head1 DESCRIPTION

A very basic block that sets functors in Dutch using several simple rules.

TODO: This could be re-made into a generic block since it's basically the same
for English and Slovak.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
